//+------------------------------------------------------------------+
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

//--- 缓存变量
datetime          lastCalculationTime = 0;  // 上次计算的时间
int               lastCalculatedBars = 0;   // 上次计算的K线数量
bool              cacheInitialized = false; // 缓存是否已初始化

//--- 4H周期缓存变量
datetime          last4HCalculationTime = 0;  // 上次4H计算的时间
bool              cache4HInitialized = false; // 4H缓存是否已初始化

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
   
   // 初始化交易分析器并获取4H数据
   CZigzagExtremumPoint points4H[];
   InitializeTradeAnalyzer(points4H);
   
   // 处理标签绘制功能（基于交易分析器数据）
   ProcessTradeAnalyzerLabelDrawing(points4H);
   
   // 处理交易分析和信息面板功能
   ProcessTradeAnalysisAndInfoPanel();
   
   // 返回计算的柱数
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| 初始化交易分析器                                                 |
//+------------------------------------------------------------------+
void InitializeTradeAnalyzer(CZigzagExtremumPoint &points4H[])
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
      if(tempCalc4H.GetExtremumPoints(points4H) && ArraySize(points4H) >= 2)
        {                 
         // 初始化交易分析器
         if(g_tradeAnalyzer.AnalyzeRange(points4H, 2) && g_tradeAnalyzer.IsValid())
           {
            // 使用4H周期极值点初始化主交易线段数组
            g_tradeAnalyzer.InitializeMainSegmentsFromPoints(points4H);
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
void ProcessTradeAnalyzerLabelDrawing(CZigzagExtremumPoint &points4H[])
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
   
   // 打印调试信息，查看传递给绘制函数的4H极值点数量
   Print(StringFormat("准备绘制4H极值点标签，数量：%d个", ArraySize(points4H)));
   
   // 绘制4H极值点标签
   CExtremumPointDrawer::DrawExtremumPointLabels(points4H, "4H", true);
   
   // 绘制1H子线段，传递4H标签点用于重叠检测
   Draw1HSubSegments(points4H);
   
   // 注释掉原来的5分钟线段绘制调用，现在通过1小时主线段获取5分钟线段
   // Draw5MSubSegments(points4H);
  }

//+------------------------------------------------------------------+
//| 绘制1小时子线段                                                  |
//+------------------------------------------------------------------+
void Draw1HSubSegments(CZigzagExtremumPoint &points4H[])
  {
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
   // 从管理器中获取线段数组
   CZigzagSegment* h1Segments[];
   if(!segmentManager.GetSegments(h1Segments))
     {
      Print("警告: 无法从1小时线段管理器获取线段数组");
      delete segmentManager;
      return;
     }   
   
   
   // 首先按时间排序线段，确保按时间先后顺序排列
   ::SortSegmentsByTime(h1Segments, true, true);  // 升序排列，早的在前 
   
   
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
      
   // 静态变量用于跟踪上次更新时间和价格
   static datetime lastInfoPanelUpdateTime = 0;
   static double lastInfoPanelPrice = 0;
   
   // 获取当前时间和价格
   datetime currentTime = TimeCurrent();
   double currentPrice = CInfoPanelManager::GetCurrentPrice();
   
   // 控制更新频率
   if(lastInfoPanelUpdateTime != 0 && 
      currentTime - lastInfoPanelUpdateTime <= 10 && 
      MathAbs(currentPrice - lastInfoPanelPrice) <= Point() * 10)
      return;
      
   // 创建交易信息面板
   CInfoPanelManager::CreateTradeInfoPanel(infoPanel);
   
   // 获取当前主交易区间的1H子线段用于面板显示
   CZigzagSegment* currentMainSegment = g_tradeAnalyzer.GetCurrentSegment();
   if(currentMainSegment != NULL)
     {
      // 获取1H子线段管理器
      //这里因为强势行情1小时没有形成回撤的时候，H4小时点出现，后续没有1小时的回撤，导致5分钟也没法计算，所以这里直接取了所有
      CZigzagSegmentManager* segmentManager = currentMainSegment.GetSmallerTimeframeSegments(PERIOD_H1);
      if(segmentManager != NULL)
        {
         // 从管理器中获取线段数组
         CZigzagSegment* h1Segments[];

         if(!segmentManager.GetSegments(h1Segments))
           {
            Print("警告: 无法从1小时线段管理器获取线段数组");
            delete segmentManager;
            return;
           }
         
         int totalSegments = ArraySize(h1Segments);
         
         // 筛选上涨和下跌线段
         CZigzagSegment* uptrendSegments[];
         CZigzagSegment* downtrendSegments[];
         ::FilterSegmentsByTrend(h1Segments, uptrendSegments, SEGMENT_TREND_UP);
         ::FilterSegmentsByTrend(h1Segments, downtrendSegments, SEGMENT_TREND_DOWN);
         
         // 按时间排序
         //::SortSegmentsByTime(uptrendSegments, false, false);
         //::SortSegmentsByTime(downtrendSegments, false, false);
         
         //在这里添加5分钟线段的获取
         //从segmentManager.GetMainSegment()取得1小时级别主线段，重复上面从4小时获取1小时的过程即可，移掉你从4小时取5分钟的处理
         // 获取1小时主线段
         CZigzagSegment* mainH1Segment = segmentManager.GetMainSegment();
         if(mainH1Segment != NULL)
           {
            // 从1小时主线段获取5分钟线段管理器
            //这里赋值的参数是false，只关注最后一根小时线，用true的话，可能1小时还没形成，主要是强势行情，1小时顶点没那么快形成
            CZigzagSegmentManager* m5SegmentManager = mainH1Segment.GetSmallerTimeframeSegments(PERIOD_M5,false);
            if(m5SegmentManager != NULL)
              {
               // 从5分钟线段管理器中获取线段数组
               CZigzagSegment* m5Segments[];
               if(!m5SegmentManager.GetSegments(m5Segments))
                 {
                  Print("警告: 无法从5分钟线段管理器获取线段数组");
                  delete m5SegmentManager;                  
                 }
               
               int m5TotalSegments = ArraySize(m5Segments);
               Print(StringFormat("获取到5分钟线段数量：%d个", m5TotalSegments));
               
               // 筛选5分钟线段的上涨和下跌线段
               CZigzagSegment* m5UptrendSegments[];
               CZigzagSegment* m5DowntrendSegments[];
                         
               ::FilterSegmentsByTrend(m5Segments, m5UptrendSegments, SEGMENT_TREND_UP);
               ::FilterSegmentsByTrend(m5Segments, m5DowntrendSegments, SEGMENT_TREND_DOWN);
               
               // 按时间排序
              // ::SortSegmentsByTime(m5UptrendSegments, false, false);
              // ::SortSegmentsByTime(m5DowntrendSegments, false, false);
               
               // 在信息面板上添加5分钟线段信息
               CInfoPanelManager::AddSegmentInfo(infoPanel, m5UptrendSegments, m5DowntrendSegments, InpInfoPanelColor, "5分钟");
                        
              }
           }

         // 在信息面板上添加线段信息
         CInfoPanelManager::AddSegmentInfo(infoPanel, uptrendSegments, downtrendSegments, InpInfoPanelColor);
         
         
        }
     }
   
   // 绘制支撑或压力线
   CShapeManager::DrawSupportResistanceLines();
   
   // 更新时间和价格
   lastInfoPanelUpdateTime = currentTime;
   lastInfoPanelPrice = currentPrice;
  }