//+------------------------------------------------------------------+
//|                                                    MyZigzag.mq5 |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property strict
#property version   "1.00"

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
#include "Strategies/CL001.mqh"
#include "Database/DatabaseManager.mqh"

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
SZigzagExtremumPoint points4H[];
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
// 执行交易策略
CStrategyCL001 strategy;

//--- 数据库管理器
CDatabaseManager dbManager;

//+------------------------------------------------------------------+
//| 自定义指标初始化函数                                             |
//+------------------------------------------------------------------+
int OnInit()
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
   
   

   return(INIT_SUCCEEDED);
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
void OnTick()
  {
   // 检查是否需要重新计算
   CheckTradeAnalyzerRecalculation();

   if(needRecalculateTradeAnalyzer)
   {// 执行交易分析
      InitializeTradeAnalyzer(points4H);
      strategy.Execute(g_tradeAnalyzer.m_tradeBasePoint);      

   // 更新图形显示
   ProcessTradeAnalyzerLabelDrawing(points4H);
   ProcessTradeAnalysisAndInfoPanel();
      needRecalculateTradeAnalyzer = false;
   }

  
   

  }

//+------------------------------------------------------------------+
//| 检查是否需要重新计算交易分析器                                   |
//+--                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn----------------------------------------------------------------+
void CheckTradeAnalyzerRecalculation()
  {
// 获取当前时间
   datetime currentTime = TimeCurrent();
   MqlDateTime timeStruct;
   TimeToStruct(currentTime, timeStruct);

// 检查是否为0秒（1分钟K线收线时）
   if(timeStruct.sec == 0)
   {
      // 检查是否距离上次计算至少1分钟
      if(currentTime - lastTradeAnalyzerCalcTime >= 60)
      {
         needRecalculateTradeAnalyzer = true;
         lastTradeAnalyzerCalcTime = currentTime;
      }
   }
  }

//+------------------------------------------------------------------+
//| 初始化交易分析器                                                 |
//+------------------------------------------------------------------+
void InitializeTradeAnalyzer(SZigzagExtremumPoint &inputFourHourPoints[])
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
      if(tempCalc4H.GetExtremumPoints(inputFourHourPoints) && ArraySize(inputFourHourPoints) >= 2)
        {
         // 初始化交易分析器
         if(g_tradeAnalyzer.AnalyzeRange(inputFourHourPoints, 2) && g_tradeAnalyzer.IsValid())
           {
            // 使用4H周期极值点初始化主交易线段数组
            g_tradeAnalyzer.InitializeMainSegmentsFromPoints(inputFourHourPoints);
            g_tradeAnalyzer.m_tradeBasePoint.CacheAllSegments();    
            
            // 输出交易基准点的价格
            Print(StringFormat("[交易基准点] 价格: %s", DoubleToString(g_tradeAnalyzer.m_tradeBasePoint.GetBasePrice(), _Digits)));
            
            // 执行CL001策略
            strategy.Execute(g_tradeAnalyzer.m_tradeBasePoint);
            
            //打印周期信息
            Print("=== 线段信息输出（左侧每周期第一个，右侧最多5个） ===");
            string timeframeNames[] = {"M5", "M15", "M30", "H1"};
            int timeframeIndices[] = {0, 1, 2, 3};
            
            for(int i = 0; i < 4; i++)
            {
               Print("-**************"); 
               // 左侧线段：只输出每周期第一个线段
               CZigzagSegment* leftSegArray[];
               if(g_tradeAnalyzer.m_tradeBasePoint.m_leftSegmentsStore.GetArray(timeframeIndices[i], leftSegArray) && ArraySize(leftSegArray) > 0)
               {
                  double leftStartPrice = leftSegArray[0].m_start_point.value;
                  double leftEndPrice = leftSegArray[0].m_end_point.value;
                  string leftDirection = (leftEndPrice > leftStartPrice) ? "↑" : "↓";
                  Print(timeframeNames[i], "周期左侧线段[0]: ", leftStartPrice, " -> ", leftEndPrice, " ", leftDirection);
               }
                Print("-------------");              // 右侧线段：输出最多5个线段
               CZigzagSegment* rightSegArray[];
               if(g_tradeAnalyzer.m_tradeBasePoint.m_rightSegmentsStore.GetArray(timeframeIndices[i], rightSegArray) && ArraySize(rightSegArray) > 0)
               {
                  int count = MathMin(ArraySize(rightSegArray), 5);
                  for(int j = 0; j < count; j++)
                  {
                     double rightStartPrice = rightSegArray[j].m_start_point.value;
                     double rightEndPrice = rightSegArray[j].m_end_point.value;
                     string rightDirection = (rightEndPrice > rightStartPrice) ? "↑" : "↓";
                     Print(timeframeNames[i], "周期右侧线段[", j, "]: ", rightStartPrice, " -> ", rightEndPrice, " ", rightDirection);
                  }
               }
            }
            Print("====================================================");
            
            
            
            // 获取当前主线段
            CZigzagSegment* currentMainSegment = g_tradeAnalyzer.GetCurrentSegment();
            if(currentMainSegment != NULL)
            {
               // 获取1H子线段管理器（仅限当前主交易区间内）
               CZigzagSegmentManager* segmentManager = currentMainSegment.GetSmallerTimeframeSegments(PERIOD_H1);
               if(segmentManager != NULL)
               {
                  segmentManager.GetSegments(h1Segments);
                  delete segmentManager; // 释放内存
               }
               else
               {
                  Print("警告: 无法获取H1子线段管理器");
                  ArrayResize(h1Segments, 0);
               }
            }
            else
            {
               Print("警告: 当前主线段为NULL");
               ArrayResize(h1Segments, 0);
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
void ProcessTradeAnalyzerLabelDrawing(SZigzagExtremumPoint &inputFourHourPoints[])
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


// 绘制4H极值点标签
   CExtremumPointDrawer::DrawExtremumPointLabels(inputFourHourPoints, "4H", true);

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
//| 清理线段数组，释放动态创建的对象                                  |
//+------------------------------------------------------------------+
void CleanupSegmentArrays(CZigzagSegment* &segments[])
  {
   for(int i = 0; i < ArraySize(segments); i++)
     {
      if(segments[i] != NULL && CheckPointer(segments[i]))
        {
         delete segments[i];
         segments[i] = NULL;
        }
     }
   ArrayResize(segments, 0);
  }

//+------------------------------------------------------------------+
//| 处理交易分析和信息面板功能                                       |
//+------------------------------------------------------------------+
void ProcessTradeAnalysisAndInfoPanel()
  {
   if(!InpShowInfoPanel || !g_tradeAnalyzer.IsValid())
      return;

// 绘制支撑或压力线
//CShapeManager::DrawSupportResistanceLines();


  }

  // 交易事务处理函数
   void OnTradeTransaction(const MqlTradeTransaction &trans,
                          const MqlTradeRequest &request,
                          const MqlTradeResult &result)
   {
      // 处理所有交易事件类型
      string eventType = "";
      string logEntry = "";
      ulong dealTicket = 0;
      ENUM_DEAL_ENTRY entryType = 0;
      string symbol = "";
      double volume = 0.0;
      double price = 0.0;
      
      switch(trans.type)
      {
         case TRADE_TRANSACTION_DEAL_ADD: // 订单成交
            eventType = "订单成交";
            dealTicket = trans.deal;
            if(HistoryDealSelect(dealTicket))
            {
               entryType = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
               symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
               volume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
               price = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
               logEntry = StringFormat("[交易日志] %s #%d 品种:%s 方向:%s 手数:%.2f 价格:%.5f",
                     eventType, dealTicket, symbol, EnumToString(entryType), volume, price);
            }
            break;
            
         case TRADE_TRANSACTION_ORDER_ADD: // 挂单
            eventType = "挂单";
            logEntry = StringFormat("[交易日志] %s #%d 品种:%s 类型:%s 手数:%.2f 价格:%.5f",
                  eventType, trans.order, request.symbol, EnumToString(request.type), request.volume, request.price);
            break;
            
         case TRADE_TRANSACTION_ORDER_DELETE: // 取消订单
            eventType = "取消订单";
            logEntry = StringFormat("[交易日志] %s #%d", eventType, trans.order);
            break;
            
         case TRADE_TRANSACTION_ORDER_UPDATE: // 修改订单
            eventType = "修改订单";
            logEntry = StringFormat("[交易日志] %s #%d 新价格:%.5f", 
                  eventType, trans.order, request.price);
            break;
            
         default:
            return; // 不处理其他类型事件
      }
      
      // 记录日志
      if(logEntry != "")
      {
         Print(logEntry);
         
         // 保存到MySQL数据库
         if(dbManager.LogTradeToMySQL((int)TimeCurrent(), symbol, eventType, volume, price, 0, 0, logEntry))
         {
            Print("交易记录成功保存到MySQL数据库!");
         }
         else
         {
            Print("交易记录保存到数据库失败: ", dbManager.GetLastError());
         }
      }
   }
   