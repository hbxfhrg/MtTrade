//+------------------------------------------------------------------+
//|                                                    MyZigzag.mq5 |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   2
#property indicator_type1   DRAW_COLOR_ZIGZAG  // 当前周期(用于图形绘制)
#property indicator_color1  clrDodgerBlue,clrRed
#property indicator_width1  2
#property indicator_type2   DRAW_COLOR_ZIGZAG  // 4小时周期(大周期)
#property indicator_color2  clrGold,clrPurple
#property indicator_width2  2

//--- 包含文件
#include "ZigzagCalculator.mqh"
#include "Graphics/InfoPanelManager.mqh"
#include "Graphics/LabelManager.mqh"
#include "Graphics/LineManager.mqh"
#include "Graphics/ShapeManager.mqh"
#include "CommonUtils.mqh"
#include "TradeAnalyzer.mqh"
#include "ConfigManager.mqh"
#include "GlobalInstances.mqh"

//--- 输入参数
input int    InpDepth = 12;            // 深度
input int    InpDeviation = 5;         // 偏差
input int    InpBackstep = 3;          // 回溯步数
input bool   InpShowLabels = true;     // 显示峰谷值文本标签
input color  InpLabelColor = clrWhite; // 标签文本颜色
input bool   InpShow5M = true;         // 计算5分钟周期ZigZag(小周期)
input bool   InpShow4H = true;         // 显示4小时周期ZigZag(大周期)
input color  InpLabel4HColor = clrOrange; // 4小时周期标签颜色
input int    InpCacheTimeout = 300;    // 缓存超时时间(秒)
input int    InpMaxBarsH1 = 200;       // 1小时周期最大计算K线数
input bool   InpShowInfoPanel = true;  // 显示信息面板
input color  InpInfoPanelColor = clrWhite; // 信息面板文字颜色
input color  InpInfoPanelBgColor = clrNavy; // 信息面板背景颜色
input bool   InpShowPenetratedPoints = false; // 显示已失效(被穿越)的价格点

//--- 声明ZigZag计算器指针
CZigzagCalculator *calculator = NULL;      // 当前周期计算器(用于图形绘制)
CZigzagCalculator *calculator4H = NULL;    // 4H周期计算器(大周期，用于策略缓存)

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
   
   // 加载或保存配置
   int depth = InpDepth;
   int deviation = InpDeviation;
   int backstep = InpBackstep;
   bool showLabels = InpShowLabels;
   color labelColor = InpLabelColor;
   bool show5M = InpShow5M;
   bool show4H = InpShow4H;
   color label4HColor = InpLabel4HColor;
   int cacheTimeout = InpCacheTimeout;
   int maxBarsH1 = InpMaxBarsH1;
   bool showInfoPanel = InpShowInfoPanel;
   color infoPanelColor = InpInfoPanelColor;
   color infoPanelBgColor = InpInfoPanelBgColor;
   bool showPenetratedPoints = InpShowPenetratedPoints;
   
   // 检查是否有保存的配置
   if(CConfigManager::HasSavedConfig())
     {
      // 加载保存的配置
      CConfigManager::LoadConfig(
         depth, deviation, backstep,
         showLabels, labelColor,
         show5M, show4H, label4HColor,
         cacheTimeout, maxBarsH1,
         showInfoPanel, infoPanelColor, infoPanelBgColor,
         showPenetratedPoints
      );
      
      // 配置加载成功
     }
   else
     {
      // 保存当前配置
      if(CConfigManager::SaveAllConfig(
         depth, deviation, backstep,
         showLabels, labelColor,
         show5M, show4H, label4HColor,
         cacheTimeout, maxBarsH1,
         showInfoPanel, infoPanelColor, infoPanelBgColor,
         showPenetratedPoints
      ))
        {
         // 已保存当前配置
        }
      else
        {
         // 保存配置失败
        }
     }

//--- 初始化ZigZag计算器
   calculator = new CZigzagCalculator(depth, deviation, backstep, 3, PERIOD_CURRENT); // 当前周期(用于图形绘制)
   calculator4H = new CZigzagCalculator(depth, deviation, backstep, 3, PERIOD_H4);    // 4H周期(大周期，用于策略缓存)
   
//--- 初始化标签管理器 - 传入不同的颜色
   g_LabelColor = labelColor;    // 当前周期(中周期)
   g_Label4HColor = label4HColor; // 大周期
   CLabelManager::Init(labelColor, label4HColor);
   
//--- 初始化线条管理器
   CLineManager::Init();
   
//--- 初始化图形管理器
   CShapeManager::Init();
   
//--- 设置是否显示已失效(被穿越)的价格点
   g_ShowPenetratedPoints = showPenetratedPoints;
   
//--- 初始化信息面板管理器
   g_InfoPanelTextColor = infoPanelColor;
   g_InfoPanelBgColor = infoPanelBgColor;
   CInfoPanelManager::Init(infoPanel, infoPanelColor, infoPanelBgColor);
   
//--- 初始化交易分析器
   g_tradeAnalyzer.Init();
   
//--- 指标缓冲区 mapping - 用于图形绘制
   SetIndexBuffer(0, calculator.ZigzagPeakBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, calculator.ZigzagBottomBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, calculator.ColorBuffer, INDICATOR_COLOR_INDEX);
   
   // 为4H周期(大周期)分配缓冲区用于显示
   if(calculator4H != NULL && InpShow4H)
     {
      SetIndexBuffer(3, calculator4H.ZigzagPeakBuffer, INDICATOR_DATA);
      SetIndexBuffer(4, calculator4H.ZigzagBottomBuffer, INDICATOR_DATA);
      SetIndexBuffer(5, calculator4H.ColorBuffer, INDICATOR_COLOR_INDEX);
     }
   
//--- 设置精度
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
//--- DataWindow和指标子窗口标签的名称
   string short_name = StringFormat("MyZigzag(%d,%d,%d)", InpDepth, InpDeviation, InpBackstep);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, short_name);
//--- 设置空值
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
//--- 关闭图表网格
   ChartSetInteger(0, CHART_SHOW_GRID, 0);   
//--- 关闭图表交易水平线显示
   ChartSetInteger(0, CHART_SHOW_TRADE_LEVELS, false);
//--- 打开从右边框转移图表的按钮
   ChartSetInteger(0, CHART_SHOW_OBJECT_DESCR, true);
   
   // 重置缓存状态
   cacheInitialized = false;
   lastCalculationTime = 0;
   lastCalculatedBars = 0;
   cache4HInitialized = false;
   last4HCalculationTime = 0;
  }

//+------------------------------------------------------------------+
//| 自定义指标释放函数                                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // 保存当前配置
   // 只有在程序正常卸载或参数更改时才保存配置
   if(reason == REASON_REMOVE || reason == REASON_PARAMETERS || reason == REASON_CHARTCLOSE)
     {
      // 获取当前使用的参数
      int depth = calculator != NULL ? calculator.GetDepth() : InpDepth;
      int deviation = calculator != NULL ? calculator.GetDeviation() : InpDeviation;
      int backstep = calculator != NULL ? calculator.GetBackstep() : InpBackstep;
      
      // 保存配置
      if(CConfigManager::SaveAllConfig(
         depth, deviation, backstep,
         InpShowLabels, g_LabelColor,
         InpShow5M, InpShow4H, g_Label4HColor,
         InpCacheTimeout, InpMaxBarsH1,
         InpShowInfoPanel, g_InfoPanelTextColor, g_InfoPanelBgColor,
         g_ShowPenetratedPoints
      ))
        {
         // 指标卸载时已保存配置
        }
      else
        {
         // 指标卸载时保存配置失败
        }
     }
   
   // 释放计算器对象
   if(calculator != NULL)
     {
      delete calculator;
      calculator = NULL;
     }
   
   // 释放4H周期计算器对象(大周期)
   if(calculator4H != NULL)
     {
      delete calculator4H;
      calculator4H = NULL;
     }
     
   // 删除所有文本标签
   CLabelManager::DeleteAllLabels("ZigzagLabel_");
   CLabelManager::DeleteAllLabels("ZigzagLabel4H_"); // 添加删除4H周期标签
   
   // 清理图表对象和自定义图形
   ObjectsDeleteAll(0, "ZigzagLabel_");
   ObjectsDeleteAll(0, "ZigzagLabel4H_");
   ObjectsDeleteAll(0, "SR_Line_"); // 删除支撑/压力线
   ObjectsDeleteAll(0, "SR_Rect_"); // 删除支撑/压力矩形
   ObjectsDeleteAll(0, "SR_Label_"); // 删除支撑/压力线标签
   ObjectDelete(0, infoPanel); // 删除信息面板
 
  }

//+------------------------------------------------------------------+
//| 计算ZigZag数据                                                  |
//+------------------------------------------------------------------+
void CalculateZigZagData(const int rates_total, const int prev_calculated, 
                        const double &high[], const double &low[], 
                        CZigzagExtremumPoint &points4H[], bool &has4HPoints)
  {
   // 计算当前周期ZigZag
   calculator.Calculate(high, low, rates_total, prev_calculated);
   
   // 计算4H周期ZigZag - 只有在需要时才计算
   if(InpShow4H)
     {
      // 获取4H周期价格数据
      double h4_high[];
      double h4_low[];
      
      // 根据K线搜索策略，大周期最大搜索200根K线
      int maxBars4H = 200;
      
      // 从最新时间往前获取4H周期数据（索引0是最新的K线）
      int h4_copied_high = CopyHigh(Symbol(), PERIOD_H4, 0, maxBars4H, h4_high);
      int h4_copied_low = CopyLow(Symbol(), PERIOD_H4, 0, maxBars4H, h4_low);
      
      if(h4_copied_high > 0 && h4_copied_low > 0)
        {
         // 计算4H周期ZigZag
         calculator4H.Calculate(h4_high, h4_low, h4_copied_high, 0);
         
         // 获取4H周期极值点
         if(calculator4H.GetExtremumPoints(points4H))
           {
            has4HPoints = true;
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| 处理标签绘制功能                                                |
//+------------------------------------------------------------------+
void ProcessLabelDrawing(CZigzagExtremumPoint &points4H[], bool has4HPoints)
  {
   // 如果需要显示文本标签
   if(InpShowLabels)
     {
      // 静态变量用于跟踪上次更新时间和最后一个极点
      static datetime lastLabelUpdateTime = 0;
      static datetime lastExtremumTime = 0;
      
      // 获取当前时间
      datetime currentLabelTime = TimeCurrent();
      
      // 清除旧标签
      if(calculator != NULL)
        {
         // 获取当前周期极值点数组
         CZigzagExtremumPoint points[];
         if(calculator.GetExtremumPoints(points))
           {
            // 检查是否有新的极点出现
            bool hasNewExtremum = false;
            datetime newestExtremumTime = lastExtremumTime;
            
            // GetExtremumPoints现在返回按时间排序的极值点（最新的在前面）
            if(ArraySize(points) > 0)
              {
               // 第一个点就是最新的极值点
               datetime maxTime = points[0].Time();
               
               // 检查是否有新的极点
               if(maxTime > lastExtremumTime)
                 {
                  newestExtremumTime = maxTime;
                  hasNewExtremum = true;
                 }
              }
            
            // 只有在以下情况下才更新标签：
            // 1. 首次绘制（lastLabelUpdateTime为0）
            // 2. 有新的极点出现
            // 3. 距离上次更新已经超过30秒
            if(lastLabelUpdateTime == 0 || hasNewExtremum || currentLabelTime - lastLabelUpdateTime > 30)
              {
               // 更新最后极点时间
               lastExtremumTime = newestExtremumTime;
               lastLabelUpdateTime = currentLabelTime;
               
               // 添加当前周期的标签
               for(int i = 0; i < ArraySize(points); i++)
                 {
                  //检查这个值是否在大周期峰谷值列表中出现
                  bool foundIn4H = false; // 大周期
                  
                  // 检查4H周期(大周期) - 使用已计算的数据
                  if(InpShow4H && has4HPoints && ArraySize(points4H) > 0)
                    {
                     // 使用公共方法检查价格是否在4H周期极值点数组中出现
                     foundIn4H = ::IsPriceInArray(points[i].Value(), points4H);
                    }
                  
                  string labelName = "ZigzagLabel_" + IntegerToString(i);
                  string labelText;
                  
                  // 根据价格出现在哪个周期中设置标签文本
                  if(foundIn4H) // 大周期
                    {
                     labelText = StringFormat("H4: %s", 
                        DoubleToString(points[i].Value(), _Digits));
                     labelText += "\n序号: " + IntegerToString(points[i].BarIndex());
                    }
                  else // 中周期(当前周期)
                    {
                     // 获取当前周期的简写形式
                     string periodShort = TimeframeToString(Period());
                     
                     labelText = StringFormat("%s: %s",
                        periodShort,              
                        DoubleToString(points[i].Value(), _Digits));
                     labelText += "\n序号: " + IntegerToString(points[i].BarIndex());
                    }
   
                  // 创建价格标签
                  string priceLabel = "";
                  
                  // 获取当前周期的简写形式
                  string periodShort = TimeframeToString(Period());
                  
                  if(foundIn4H) // 大周期
                     priceLabel = StringFormat("H4: %s", DoubleToString(points[i].Value(), _Digits));
                  else // 中周期(当前周期)
                     priceLabel = StringFormat("%s: %s", periodShort, DoubleToString(points[i].Value(), _Digits));
                  
                  // 使用点的时间直接计算K线序号（当前K线为0）
                  int fromCurrentIndex = iBarShift(Symbol(), Period(), points[i].Time());
                  
                  // 创建工具提示内容，显示K线序号和时间以及周期信息
                  string periodInfo = "";
                  if(foundIn4H) periodInfo += "H4(大周期) ";
                  if(periodInfo == "") periodInfo = "当前周期(中周期)";
                  
                  string tooltipText = StringFormat("K线序号: %d\n时间: %s\n价格: %s\n类型: %s\n周期: %s", 
                                                  fromCurrentIndex,
                                                  TimeToString(points[i].Time(), TIME_DATE|TIME_MINUTES|TIME_SECONDS),
                                                  DoubleToString(points[i].Value(), _Digits),
                                                  points[i].IsPeak() ? "峰值" : "谷值",
                                                  periodInfo);
                  
                  // 只创建价格标签，不再创建序号标签，但添加工具提示
                  CLabelManager::CreateTextLabel(
                     labelName,
                     priceLabel,
                     points[i].Time(),
                     points[i].Value(),
                     points[i].IsPeak(),
                     foundIn4H,
                     NULL,    // 使用默认颜色
                     NULL,    // 使用默认字体
                     0,       // 使用默认字体大小
                     0,       // X轴偏移量为0（居中显示时不需要偏移）
                     true,    // 启用居中显示
                     tooltipText  // 添加工具提示
                  );
                 }
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| 处理交易分析和信息面板功能                                       |
//+------------------------------------------------------------------+
void ProcessTradeAnalysisAndInfoPanel(CZigzagExtremumPoint &points4H[], bool has4HPoints)
  {
   // 创建或更新信息面板（只在必要时重绘）
   if(InpShowInfoPanel && InpShow4H)
     {
      // 静态变量用于跟踪上次更新时间和价格
      static datetime lastInfoPanelUpdateTime = 0;
      static double lastInfoPanelPrice = 0;
      
      // 获取当前时间和价格
      datetime currentTime = TimeCurrent();
      double currentPrice = CInfoPanelManager::GetCurrentPrice();
      
      // 只有当时间超过10秒或价格变化超过一定范围时才更新面板
      if(lastInfoPanelUpdateTime == 0 || 
         currentTime - lastInfoPanelUpdateTime > 10 || 
         MathAbs(currentPrice - lastInfoPanelPrice) > Point() * 10)
        {
         // 直接使用TradeAnalyzer中已存在的支撑点和压力点数据，无需转换
         bool hasValidTradeData = false;
         
         // 首先检查是否有4H周期数据可用于分析
         if(has4HPoints && ArraySize(points4H) >= 1)
           {
            // 使用4H周期极值点数据进行交易分析
            if(g_tradeAnalyzer.AnalyzeRange(points4H, 2) && g_tradeAnalyzer.IsValid())
              {
               hasValidTradeData = true;
               
               // 添加交易类m_mainTradingSegments的初始化，因为是初始化直接取缓存H4的极点数据以生成主线段数据
               // 确保有足够的4H周期极值点来创建线段
               if(ArraySize(points4H) >= 2)
                 {
                  // 直接使用初始化方法来设置主交易线段数组
                  g_tradeAnalyzer.InitializeMainSegmentsFromPoints(points4H);
                 }
              }
           }
         else if(g_tradeAnalyzer.IsValid())
           {
            // 如果没有4H周期数据，但TradeAnalyzer已有有效的分析结果
            // 直接使用已有的分析数据
            CDynamicPricePoint* supportPointsObj = g_tradeAnalyzer.GetSupportPointsObject();
            CDynamicPricePoint* resistancePointsObj = g_tradeAnalyzer.GetResistancePointsObject();
            
            if(supportPointsObj != NULL && resistancePointsObj != NULL)
              {
               double supportPrice = supportPointsObj.GetPrice(PERIOD_H4);
               double resistancePrice = resistancePointsObj.GetPrice(PERIOD_H4);
               
               // 检查是否有有效的支撑和压力数据
               if(supportPrice > 0.0 && resistancePrice > 0.0)
                 {
                  hasValidTradeData = true;
                 }
              }
           }
         
         if(hasValidTradeData)
           {
            // 使用信息面板管理器创建统一的信息面板
            // 这里同时显示交易区间和趋势方向信息，以及其他必要信息
            // 创建包含交易分析结果的面板
            CInfoPanelManager::CreateTradeInfoPanel(infoPanel);
               
               // 动态获取1小时周期的线段数据
               CZigzagSegment* h1Segments[];
               
               // 使用交易分析器的当前主段对象获取H1周期的线段
               CZigzagSegment* currentMainSegment = g_tradeAnalyzer.GetCurrentSegment();
               
               if(currentMainSegment != NULL && currentMainSegment.GetSmallerTimeframeSegments(h1Segments, PERIOD_H1, 50))
                 {
                  // 动态获取到了线段数据
                  // 获取上涨和下跌线段
                  CZigzagSegment* uptrendSegments[];
                  CZigzagSegment* downtrendSegments[];
                  
                  // 筛选上涨和下跌线段
                  ::FilterSegmentsByTrend(h1Segments, uptrendSegments, SEGMENT_TREND_UP);
                  ::FilterSegmentsByTrend(h1Segments, downtrendSegments, SEGMENT_TREND_DOWN);
                  
                  // 按时间排序线段（从晚到早，使用开始时间）
                  ::SortSegmentsByTime(uptrendSegments, false, false);
                  ::SortSegmentsByTime(downtrendSegments, false, false);
                  
                  CZigzagSegment* m5Segments[];
                  
                  // 找到离当前时间最近的1小时线段
                  datetime m5StartTime = 0;
                  datetime m5EndTime = 0;
                  datetime currentTime = TimeCurrent();
                  CZigzagSegment* nearestSegment = NULL;
                  datetime minTimeDiff = LONG_MAX;
                  
                  // 遍历所有1小时线段，找到离当前时间最近的那个
                  for(int segIdx = 0; segIdx < ArraySize(h1Segments); segIdx++)
                    {
                     if(h1Segments[segIdx] != NULL)
                       {
                        // 计算线段结束时间与当前时间的差值
                        datetime segEndTime = h1Segments[segIdx].EndTime();
                        datetime timeDiff = MathAbs(currentTime - segEndTime);
                        
                        if(timeDiff < minTimeDiff)
                          {
                           minTimeDiff = timeDiff;
                           nearestSegment = h1Segments[segIdx];
                          }
                       }
                    }
                  
                  if(nearestSegment != NULL)
                    {
                     // 从1小时线段结束时间开始，获取之后的5分钟线段
                     m5StartTime = nearestSegment.EndTime();
                     m5EndTime = TimeCurrent();
                    }
                  else
                    {
                     // 如果没有1小时线段，使用默认时间范围
                     m5StartTime = iTime(Symbol(), PERIOD_H1, 1);
                     m5EndTime = TimeCurrent();
                    }
                  
                  // 动态获取指定时间范围内的5分钟线段
                  if(::GetSegmentsInTimeRange(PERIOD_M5, m5StartTime, m5EndTime, m5Segments, 30))
                    {
                     
                     // 获取上涨和下跌的5分钟线段
                     CZigzagSegment* m5UptrendSegments[];
                     CZigzagSegment* m5DowntrendSegments[];
                     
                     // 筛选5分钟上涨和下跌线段
                     ::FilterSegmentsByTrend(m5Segments, m5UptrendSegments, SEGMENT_TREND_UP);
                     ::FilterSegmentsByTrend(m5Segments, m5DowntrendSegments, SEGMENT_TREND_DOWN);
                     
                     // 按时间排序5分钟线段（从晚到早，使用开始时间）
                     SortSegmentsByTime(m5UptrendSegments, false, false);
                     SortSegmentsByTime(m5DowntrendSegments, false, false);
                     
                     // 释放5分钟线段内存
                     for(int k = 0; k < ArraySize(m5Segments); k++)
                       {
                        if(m5Segments[k] != NULL)
                          {
                           delete m5Segments[k];
                           m5Segments[k] = NULL;
                          }
                       }
                    }
                  
                  // 在信息面板上添加线段信息
                  CInfoPanelManager::AddSegmentInfo(infoPanel, uptrendSegments, downtrendSegments, InpInfoPanelColor);
                  
                  // 释放内存
                  for(int i = 0; i < ArraySize(h1Segments); i++)
                    {
                     if(h1Segments[i] != NULL)
                       {
                        delete h1Segments[i];
                        h1Segments[i] = NULL;
                       }
                    }
                 }
               else
                 {
                  // 获取H1线段失败，使用简单信息面板
                 }
               
               // 绘制支撑或压力线
               CShapeManager::DrawSupportResistanceLines();
           }
         else
           {
            // 使用信息面板管理器创建简单信息面板
            CInfoPanelManager::CreateSimpleInfoPanel(infoPanel, "暂无有效的交易区间数据", InpInfoPanelColor, InpInfoPanelBgColor);
           }
           
         // 更新上次更新时间和价格
         lastInfoPanelUpdateTime = currentTime;
         lastInfoPanelPrice = currentPrice;
        }
     }
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
      
   // 初始化缓冲区
   if(prev_calculated == 0)
     {
      ArrayInitialize(calculator.ZigzagPeakBuffer, 0.0);
      ArrayInitialize(calculator.ZigzagBottomBuffer, 0.0);
      ArrayInitialize(calculator.ColorBuffer, 0.0);
      
      // 清除旧标签
      CLabelManager::DeleteAllLabels("ZigzagLabel_");
      CLabelManager::DeleteAllLabels("ZigzagLabel4H_");
     }
   
   // 声明各周期极值点数组（提升作用域到整个函数）
   CZigzagExtremumPoint points4H[]; // 大周期(4H)
   bool has4HPoints = false;
   
   // 计算当前周期ZigZag和4H周期ZigZag
   CalculateZigZagData(rates_total, prev_calculated, high, low, points4H, has4HPoints);
   
   // 处理标签绘制功能
   ProcessLabelDrawing(points4H, has4HPoints);
   
   // 处理交易分析和信息面板功能
   ProcessTradeAnalysisAndInfoPanel(points4H, has4HPoints);
   
   // 返回计算的柱数
   return(rates_total);
  }

