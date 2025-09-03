//+------------------------------------------------------------------+
//|                                                    MyZigzag.mq5 |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property indicator_chart_window
// 移除绘图缓冲区，专注于标签和分析显示

//--- 包含文件
#include "ZigzagCalculator.mqh"
#include "Graphics/InfoPanelManager.mqh"
#include "Graphics/LabelManager.mqh"
#include "Graphics/LineManager.mqh"
#include "Graphics/ShapeManager.mqh"
#include "Graphics/ExtremumPointDrawer.mqh"
#include "Graphics/SegmentDrawer.mqh"
#include "CommonUtils.mqh"
#include "TradeAnalyzer.mqh"
#include "ConfigManager.mqh"
#include "GlobalInstances.mqh"
#include "ZigzagSegmentManager.mqh"

//--- 输入参数（简化版本，专注于显示控制）
input bool   InpShowLabels = true;        // 显示极值点标签
input color  InpLabelColor = clrWhite;     // 1H子线段标签颜色
input color  InpLabel4HColor = clrOrange;  // 4H主线段标签颜色
input bool   InpShowInfoPanel = true;     // 显示信息面板
input color  InpInfoPanelColor = clrWhite; // 信息面板文字颜色
input color  InpInfoPanelBgColor = clrNavy; // 信息面板背景颜色
input bool   InpShowPenetratedPoints = false; // 显示已失效的价格点

//--- 声明交易分析器（核心数据源）
// 移除独立的ZigZag计算器，完全依赖TradeAnalyzer

//--- 信息面板对象名称
string infoPanel = "ZigzagInfoPanel";
CZigzagExtremumPoint points4H[];
CZigzagSegment* h1Segments[];
//--- 缓存变量
datetime          lastCalculationTime = 0;  // 上次计算的时间
int               lastCalculatedBars = 0;   // 上次计算的K线数量
bool              cacheInitialized = false; // 缓存是否已初始化

//--- 4H周期缓存变量
datetime          last4HCalculationTime = 0;  // 上次4H计算的时间
bool              cache4HInitialized = false; // 4H缓存是否已初始化

//--- 新增：控制交易分析器计算频率的变量
static datetime   lastTradeAnalyzerCalcTime = 0;  // 上次交易分析器计算时间
static bool       needRecalculateTradeAnalyzer = true;  // 是否需要重新计算交易分析器
static int        lastMinute = -1;  // 上次检查的分钟数

//+------------------------------------------------------------------+
//| 自定义指标初始化函数                                             |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- 初始化配置管理器
   CConfigManager::Init(Symbol());
   
   // 加载配置（简化版本，只保留必要参数）
   bool showLabels = InpShowLabels;
   color labelColor = InpLabelColor;
   color label4HColor = InpLabel4HColor;
   bool showInfoPanel = InpShowInfoPanel;
   color infoPanelColor = InpInfoPanelColor;
   color infoPanelBgColor = InpInfoPanelBgColor;
   bool showPenetratedPoints = InpShowPenetratedPoints;

//--- 初始化标签管理器
   g_LabelColor = labelColor;
   g_Label4HColor = label4HColor;
   CLabelManager::Init(labelColor, label4HColor);
   
//--- 初始化线条管理器
   CLineManager::Init();
   
//--- 初始化图形管理器
   CShapeManager::Init();
   
//--- 设置是否显示已失效的价格点
   g_ShowPenetratedPoints = showPenetratedPoints;
   
//--- 初始化信息面板管理器
   g_InfoPanelTextColor = infoPanelColor;
   g_InfoPanelBgColor = infoPanelBgColor;
   CInfoPanelManager::Init(infoPanel, infoPanelColor, infoPanelBgColor);
   
//--- 初始化交易分析器（核心数据源）
   g_tradeAnalyzer.Init();
    // 初始化交易分析器并获取4H数据（仅在需要时）
   
  InitializeTradeAnalyzer(points4H);
//--- 设置精度和标签
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   string short_name = "MyZigzag-TradeAnalyzer";
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   
//--- 关闭图表网格和交易水平线
   ChartSetInteger(0, CHART_SHOW_GRID, 0);   
   ChartSetInteger(0, CHART_SHOW_TRADE_LEVELS, false);
   ChartSetInteger(0, CHART_SHOW_OBJECT_DESCR, true);
  }

//+------------------------------------------------------------------+
//| 自定义指标释放函数                                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // 清理标签和图形对象
   CLabelManager::DeleteAllLabels("ZigzagLabel_");
   CLabelManager::DeleteAllLabels("ZigzagLabel4H_");
   
   // 清理线段对象
   CLineManager::DeleteAllLines("ZigzagLine_");
   CLineManager::DeleteAllLines("ZigzagLine4H_");
   
   // 删除图表对象
   ObjectsDeleteAll(0, "ZigzagLabel_");
   ObjectsDeleteAll(0, "ZigzagLabel4H_");
   ObjectsDeleteAll(0, "ZigzagLine_");
   ObjectsDeleteAll(0, "ZigzagLine4H_");
   ObjectsDeleteAll(0, "SR_Line_");
   ObjectsDeleteAll(0, "SR_Rect_");
   ObjectsDeleteAll(0, "SR_Label_");
   ObjectDelete(0, infoPanel);
  }

//+------------------------------------------------------------------+
//| Custom indicator calculation function                             |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(rates_total < 100)
      return(0);
      
   // 初始化时清除旧标签
   if(prev_calculated == 0)
     {
      CLabelManager::DeleteAllLabels("ZigzagLabel_");
      CLabelManager::DeleteAllLabels("ZigzagLabel4H_");
      CLineManager::DeleteAllLines("ZigzagLine_");
      CLineManager::DeleteAllLines("ZigzagLine4H_");
     }
   
   // 检查是否需要重新计算交易分析器（1分钟K线收线时）
   CheckTradeAnalyzerRecalculation();
   
  
   if(needRecalculateTradeAnalyzer)
     {
    
      needRecalculateTradeAnalyzer = false;  // 重置标志
     }
   
   // 处理标签绘制功能（基于交易分析器数据）
   ProcessTradeAnalyzerLabelDrawing(points4H);
   
   // 处理交易分析和信息面板功能
   ProcessTradeAnalysisAndInfoPanel();
   
   // 返回计算的柱数
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| 检查是否需要重新计算交易分析器                                   |
//+------------------------------------------------------------------+
void CheckTradeAnalyzerRecalculation()
  {
   // 获取当前时间
   datetime currentTime = TimeCurrent();
   
   // 获取当前分钟数（使用正确的方法）
   MqlDateTime timeStruct;
   TimeToStruct(currentTime, timeStruct);
   int currentMinute = timeStruct.min;
   
   // 检查是否到了新的分钟（即1分钟K线收线时）
   if(currentMinute != lastMinute)
     {
      // 检查是否距离上次计算至少1分钟
      if(currentTime - lastTradeAnalyzerCalcTime >= 60)
        {
         needRecalculateTradeAnalyzer = true;
         lastTradeAnalyzerCalcTime = currentTime;
        }
      // 更新上次检查的分钟数
      lastMinute = currentMinute;
     }
  }

//+------------------------------------------------------------------+
//| 初始化交易分析器                                                 |
//+------------------------------------------------------------------+
void InitializeTradeAnalyzer(CZigzagExtremumPoint &inputPoints4H[])
  {
   // 获取4H周期价格数据
   double h4_high[];
   double h4_low[];
   
   // 根据K线搜索策略，大周期最大搜索200根K线
   int maxBars4H = 200;
   
   // 从最新时间往前获取4H周期数据
   int h4_copied_high = CopyHigh(Symbol(), PERIOD_H4, 0, maxBars4H, h4_high);
   int h4_copied_low = CopyLow(Symbol(), PERIOD_H4, 0, maxBars4H, h4_low);
   
   if(h4_copied_high > 0 && h4_copied_low > 0)
     {
      // 创建临时4H计算器获取极值点
      CZigzagCalculator tempCalc4H(12, 5, 3, maxBars4H, PERIOD_H4);
      tempCalc4H.Calculate(h4_high, h4_low, h4_copied_high, 0);
      
      // 获取4H周期极值点
      if(tempCalc4H.GetExtremumPoints(inputPoints4H) && ArraySize(inputPoints4H) >= 2)
        {                 
         // 初始化交易分析器
         if(g_tradeAnalyzer.AnalyzeRange(inputPoints4H, 2) && g_tradeAnalyzer.IsValid())
           {
            // 使用4H周期极值点初始化主交易线段数组
            g_tradeAnalyzer.InitializeMainSegmentsFromPoints(inputPoints4H);
            CZigzagSegment* h1leftsegments[];
            CZigzagSegment* h1rightsegments[];
            g_tradeAnalyzer.m_tradeBasePoint.GetTimeframeSegments(PERIOD_H1, h1leftsegments, h1rightsegments);
            
            CZigzagSegment* m5leftsegments[];
            CZigzagSegment* m5rightsegments[];
            g_tradeAnalyzer.m_tradeBasePoint.GetTimeframeSegments(PERIOD_M5, m5leftsegments, m5rightsegments);
           
            // 调试日志输出
            Print("H1左线段数量: ", ArraySize(h1leftsegments));
            for(int i=0; i<ArraySize(h1leftsegments); i++) {
               if(h1leftsegments[i] != NULL) {
                  PrintFormat("H1左线段%d: 起点时间=%s 起点价格=%.5f 终点时间=%s 终点价格=%.5f",
                     i, TimeToString(h1leftsegments[i].StartTime()), h1leftsegments[i].StartPrice(),
                     TimeToString(h1leftsegments[i].EndTime()), h1leftsegments[i].EndPrice());
               }
            }
            
            Print("H1右线段数量: ", ArraySize(h1rightsegments));
            for(int i=0; i<ArraySize(h1rightsegments); i++) {
               if(h1rightsegments[i] != NULL) {
                  PrintFormat("H1右线段%d: 起点时间=%s 起点价格=%.5f 终点时间=%s 终点价格=%.5f",
                     i, TimeToString(h1rightsegments[i].StartTime()), h1rightsegments[i].StartPrice(),
                     TimeToString(h1rightsegments[i].EndTime()), h1rightsegments[i].EndPrice());
               }
            }
            
Print("M5左线段数量: ", ArraySize(m5leftsegments));
for(int i=0; i<ArraySize(m5leftsegments); i++) {
   if(m5leftsegments[i] != NULL) {
      PrintFormat("M5左线段%d: 起点时间=%s 起点价格=%.5f 终点时间=%s 终点价格=%.5f",
         i, TimeToString(m5leftsegments[i].StartTime()), m5leftsegments[i].StartPrice(),
         TimeToString(m5leftsegments[i].EndTime()), m5leftsegments[i].EndPrice());
   }
}

Print("M5右线段数量: ", ArraySize(m5rightsegments));
for(int i=0; i<ArraySize(m5rightsegments); i++) {
   if(m5rightsegments[i] != NULL) {
      PrintFormat("M5右线段%d: 起点时间=%s 起点价格=%.5f 终点时间=%s 终点价格=%.5f",
         i, TimeToString(m5rightsegments[i].StartTime()), m5rightsegments[i].StartPrice(),
         TimeToString(m5rightsegments[i].EndTime()), m5rightsegments[i].EndPrice());
   }
}






              // 获取当前主线段
   CZigzagSegment* currentMainSegment = g_tradeAnalyzer.GetCurrentSegment();
   if(currentMainSegment == NULL)
     {
      Print("警告: 无法获取当前主线段");
      return;
     }
     
   // 获取1H子线段管理器（仅限当前主交易区间内）
   CZigzagSegmentManager* segmentManager = currentMainSegment.GetSmallerTimeframeSegments(PERIOD_H1);
   if(segmentManager == NULL)
     {
      Print("警告: 无法获取1H子线段管理器");
      return;
     }   

   if(!segmentManager.GetSegments(h1Segments))
     {
      Print("警告: 无法从1小时线段管理器获取线段数组");
      delete segmentManager;
      return;
     }
   

           }
        }
      else
        {
         Print("警告: 无法获取4H极值点或极值点数量不足");
        }
     }
   else
     {
      Print("警告: 无法获取4H周期价格数据");
     }
  }

//+------------------------------------------------------------------+
//| 处理基于交易分析器的标签绘制功能                                   |
//+------------------------------------------------------------------+
void ProcessTradeAnalyzerLabelDrawing(CZigzagExtremumPoint &inputPoints4H[])
  {
   if(!InpShowLabels || !g_tradeAnalyzer.IsValid())
      return;
      
   // 静态变量用于跟踪上次更新时间
   static datetime lastLabelUpdateTime = 0;
   datetime currentLabelTime = TimeCurrent();
   
   // 控制更新频率
   if(lastLabelUpdateTime != 0 && currentLabelTime - lastLabelUpdateTime < 30)
      return;
      
   lastLabelUpdateTime = currentLabelTime;
   
   // 清除旧标签
   CLabelManager::DeleteAllLabels("ZigzagLabel_");
   CLabelManager::DeleteAllLabels("ZigzagLabel4H_");
   
   // 清除旧线段
   CLineManager::DeleteAllLines("ZigzagLine_");
   CLineManager::DeleteAllLines("ZigzagLine4H_");
   
   // 绘制4H极值点标签
   CExtremumPointDrawer::DrawExtremumPointLabels(inputPoints4H, "4H", true);
   
   // 绘制1H子线段，传递4H标签点用于重叠检测
   Draw1HSubSegments();
   
   
  }

//+------------------------------------------------------------------+
//| 绘制1小时子线段                                                  |
//+------------------------------------------------------------------+
void Draw1HSubSegments()
  {
 
   
   int validCount = ArraySize(h1Segments);
   
  
   // 使用SegmentDrawer绘制1H子线段
   CSegmentDrawer::Draw1HSubSegments(h1Segments, validCount, points4H);
   
 
  }

//+------------------------------------------------------------------+
//| 处理交易分析和信息面板功能                                       |
//+------------------------------------------------------------------+
void ProcessTradeAnalysisAndInfoPanel()
  {
   if(!InpShowInfoPanel || !g_tradeAnalyzer.IsValid())
      return;
   
   // 绘制支撑或压力线
   CShapeManager::DrawSupportResistanceLines();
   
   
  }
