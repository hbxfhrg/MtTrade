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
#include "Database/MySQLOrderLogger.mqh"
#include <Trade\PositionInfo.mqh>  // 添加这一行以确保PositionSelect等函数可用
#include <Strings\String.mqh>      // 包含StringReplace函数

//--- 输入参数（简化版本，专注于显示控制）
input bool   InpShowLabels = true;        // 显示极值点标签
input color  InpLabelColor = clrWhite;     // 1H子线段标签颜色
input color  InpLabel4HColor = clrOrange;  // 4H主线段标签颜色
input bool   InpShowInfoPanel = true;     // 显示信息面板
input color  InpInfoPanelColor = clrWhite; // 信息面板文字颜色
input color  InpInfoPanelBgColor = clrNavy; // 信息面板背景颜色
input bool   InpShowPenetratedPoints = false; // 显示已失效的价格点

//--- 数据库连接参数
input string InpDBHost = "localhost";        // 数据库主机
input int    InpDBPort = 3306;              // 数据库端口
input string InpDBName = "pymt5";           // 数据库名称
input string InpDBUser = "root";             // 数据库用户名
input string InpDBPassword = "!Aa123456";    // 数据库密码

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
CDatabaseManager* db = NULL;
CMySQLOrderLogger* dblog = NULL;

//--- 策略启动时间
datetime strategyStartTime = 0;
datetime strategyEndTime = 0; // 策略结束时间

//+------------------------------------------------------------------+
//| 生成带时间戳的文件名                                             |
//+------------------------------------------------------------------+
string GenerateTimestampFilename()
  {
   // 如果策略结束时间未设置，使用当前时间作为结束时间
   if(strategyEndTime == 0)
      strategyEndTime = TimeCurrent();
      
   string startDate = TimeToString(strategyStartTime, TIME_DATE);
   string endDate = TimeToString(strategyEndTime, TIME_DATE);
   
   // 移除日期中的分隔符
   StringReplace(startDate, ".", "");
   StringReplace(endDate, ".", "");
   
   string filename = "xauusdm_CL001_" + startDate + "_" + endDate + ".csv";
   return filename;
  }

//+------------------------------------------------------------------+
//| 自定义指标初始化函数                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- 记录策略启动时间
   strategyStartTime = TimeCurrent();
   
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
   
   // 初始化数据库管理器（按需连接模式）
   db = new CDatabaseManager(InpDBHost, InpDBUser, InpDBPassword, InpDBName, InpDBPort);
   if(db != NULL)
   {
      // 检查是否在策略测试模式下
      if(MQLInfoInteger(MQL_TESTER))
      {
         // 在测试模式下，使用带时间戳的文件名
         string testFilename = GenerateTimestampFilename();
         dblog = new CMySQLOrderLogger(db, testFilename);
         Print("策略测试模式，使用文件名: ", testFilename);
      }
      else
      {
         // 在生产模式下，使用默认文件名
         dblog = new CMySQLOrderLogger(db);
         Print("生产模式，使用默认文件名: trade_orders.csv");
      }
      
      if(dblog != NULL)
      {
         Print("MySQL订单日志记录器初始化成功（按需连接模式）");
         // 确保订单日志表存在
         if(!dblog.CreateOrderLogsTable())
         {
            Print("创建订单日志表失败: ", db.GetLastError());
         }
         else
         {
            Print("订单日志表已准备就绪");
         }
      }
      else
      {
         Print("MySQL订单日志记录器初始化失败");
      }
   }
   else
   {
      Print("数据库核心管理器初始化失败");
   }   



   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| 自定义指标释放函数                                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
// 记录策略结束时间
   strategyEndTime = TimeCurrent();
   
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
   
   // 清理数据库管理器
   if(dblog != NULL)
   {
      delete dblog;
      dblog = NULL;
   }
   
   if(db != NULL)
   {
      delete db;
      db = NULL;
   }
   
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
   {
      // 执行交易分析
      InitializeTradeAnalyzer(points4H);
      strategy.Execute(g_tradeAnalyzer.m_tradeBasePoint);      

      // 更新图形显示
      ProcessTradeAnalyzerLabelDrawing(points4H);
      ProcessTradeAnalysisAndInfoPanel();
      
      // 同步交易历史
      if(dblog != NULL)
      {
         dblog.SyncTradeHistory();
      }
      
      needRecalculateTradeAnalyzer = false;
   }
  }

//+------------------------------------------------------------------+
//| 检查是否需要重新计算交易分析器                                   |
//+------------------------------------------------------------------+
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
               CZigzagSegment* rightSegArray[];
               // 将整数索引转换为对应的ENUM_TIMEFRAMES枚举值
               ENUM_TIMEFRAMES currentTimeframe;
               switch(timeframeIndices[i])
               {
                  case 0: currentTimeframe = PERIOD_M5; break;
                  case 1: currentTimeframe = PERIOD_M15; break;
                  case 2: currentTimeframe = PERIOD_M30; break;
                  case 3: currentTimeframe = PERIOD_H1; break;
                  default: continue; // 跳过无效索引
               }
               
               if(g_tradeAnalyzer.m_tradeBasePoint.GetTimeframeSegments(currentTimeframe, leftSegArray, rightSegArray) && ArraySize(leftSegArray) > 0)
               {
                  double leftStartPrice = leftSegArray[0].m_start_point.value;
                  double leftEndPrice = leftSegArray[0].m_end_point.value;
                  string leftDirection = (leftEndPrice > leftStartPrice) ? "↑" : "↓";
                  Print(timeframeNames[i], "周期左侧线段[0]: ", leftStartPrice, " -> ", leftEndPrice, " ", leftDirection);
               }
                Print("-------------");              // 右侧线段：输出最多5个线段
               if(ArraySize(rightSegArray) > 0)
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
      // 只处理特定类型的交易事件，避免重复记录
      // TRADE_TRANSACTION_DEAL_ADD: 添加交易
      // TRADE_TRANSACTION_ORDER_ADD: 添加订单
      // TRADE_TRANSACTION_POSITION: 更改持仓
   
   }
//+------------------------------------------------------------------+