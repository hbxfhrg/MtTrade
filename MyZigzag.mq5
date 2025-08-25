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
#property indicator_type1   DRAW_COLOR_ZIGZAG  // 当前周期(中周期)
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
CZigzagCalculator *calculator = NULL;      // 当前周期计算器(默认对应中周期)
CZigzagCalculator *calculator5M = NULL;    // 5M周期计算器(小周期)
CZigzagCalculator *calculator4H = NULL;    // 4H周期计算器(大周期)

//--- 信息面板对象名称
string infoPanel = "ZigzagInfoPanel";

//--- 缓存变量
datetime          lastCalculationTime = 0;  // 上次计算的时间
int               lastCalculatedBars = 0;   // 上次计算的K线数量
bool              cacheInitialized = false; // 缓存是否已初始化

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
      
      Print("已从配置文件加载设置");
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
         Print("已将当前设置保存到配置文件");
        }
      else
        {
         Print("保存配置文件失败");
        }
     }

//--- 初始化ZigZag计算器
   calculator = new CZigzagCalculator(depth, deviation, backstep, 3, PERIOD_CURRENT); // 当前周期(默认对应中周期)
   calculator5M = new CZigzagCalculator(depth, deviation, backstep, 3, PERIOD_M5);    // 5M周期(小周期)
   calculator4H = new CZigzagCalculator(depth, deviation, backstep, 3, PERIOD_H4);    // 4H周期(大周期)
   
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
   CTradeAnalyzer::Init();
   
//--- 指标缓冲区 mapping
   SetIndexBuffer(0, calculator.ZigzagPeakBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, calculator.ZigzagBottomBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, calculator.ColorBuffer, INDICATOR_COLOR_INDEX);
   
   // 为5M周期(小周期)分配缓冲区
   if(calculator5M != NULL && InpShow5M)
     {
      SetIndexBuffer(3, calculator5M.ZigzagPeakBuffer, INDICATOR_DATA);
      SetIndexBuffer(4, calculator5M.ZigzagBottomBuffer, INDICATOR_DATA);
      SetIndexBuffer(5, calculator5M.ColorBuffer, INDICATOR_COLOR_INDEX);
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
         Print("指标卸载时已保存配置");
        }
      else
        {
         Print("指标卸载时保存配置失败");
        }
     }
   
   // 释放计算器对象
   if(calculator != NULL)
     {
      delete calculator;
      calculator = NULL;
     }
   
   // 释放5M周期计算器对象(小周期)
   if(calculator5M != NULL)
     {
      delete calculator5M;
      calculator5M = NULL;
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
      
      // 重置缓存状态
      cacheInitialized = false;
     }
   
   // 声明各周期极值点数组（提升作用域到整个函数）
   CZigzagExtremumPoint points5M[]; // 小周期(5M)
   CZigzagExtremumPoint points4H[]; // 大周期(4H)
   CZigzagExtremumPoint points[]; // 当前周期
   bool has5MPoints = false;
   bool has4HPoints = false;
   bool hasCurrentPoints = false;
   
   // 计算当前周期ZigZag
   if(calculator != NULL)
     {
      // 如果是1小时周期，使用增量计算和缓存结果
      if(Period() == PERIOD_H1)
        {
         // 获取当前时间
         datetime currentTime = TimeCurrent();
         
         // 检查是否需要重新计算
         bool needRecalculate = false;
         
         // 如果缓存未初始化，或者上次计算时间距离现在超过缓存超时时间，或者K线数量变化，则需要重新计算
         if(!cacheInitialized || 
            currentTime - lastCalculationTime > InpCacheTimeout || 
            lastCalculatedBars != rates_total)
           {
            needRecalculate = true;
           }
         
         // 如果需要重新计算
         if(needRecalculate)
           {
            // 如果是首次计算或K线数量变化，则完全重新计算
            if(!cacheInitialized || lastCalculatedBars != rates_total)
              {
               // 计算要处理的K线数量
               int bars_to_process = rates_total;
               
               // 如果设置了最大K线数限制，则只处理最近的K线
               if(InpMaxBarsH1 > 0 && bars_to_process > InpMaxBarsH1)
                 {
                  // 创建临时数组
                  double temp_high[], temp_low[];
                  ArrayResize(temp_high, rates_total);
                  ArrayResize(temp_low, rates_total);
                  
                  // 复制所有K线数据
                  for(int i = 0; i < rates_total; i++)
                    {
                     temp_high[i] = high[i];
                     temp_low[i] = low[i];
                    }
                  
                  // 计算ZigZag
                  calculator.Calculate(temp_high, temp_low, rates_total, 0);
                  
                  // 完全重新计算
                 }
               else
                 {
                  // 正常计算所有K线
                  calculator.Calculate(high, low, rates_total, 0);
                  
               // 完全重新计算
                 }
              }
            else
              {
               // 增量计算，只计算新增的K线
               calculator.Calculate(high, low, rates_total, prev_calculated);
               
               // 增量计算
              }
            
            // 更新缓存状态
            lastCalculationTime = currentTime;
            lastCalculatedBars = rates_total;
            cacheInitialized = true;
           }
         else
           {
            // 使用缓存结果，不需要重新计算
           }
        }
      else
        {
         // 其他周期正常计算
         calculator.Calculate(high, low, rates_total, prev_calculated);
        }
      
      
      // 计算5M周期ZigZag(小周期)
      if(calculator5M != NULL && InpShow5M)
        {
         // 使用CalculateForSymbol方法直接计算5M周期数据，限制为300根K线
         int result = calculator5M.CalculateForSymbol(Symbol(), PERIOD_M5, 300);
         
         // 检查计算结果
         if(result < 0)
           {
            // 无法计算5M周期ZigZag
           }
         else
           {
            // 获取5M周期极值点
            has5MPoints = calculator5M.GetExtremumPoints(points5M);
            if(!has5MPoints)
              {
               // 无法获取5M周期极值点
              }
           }
        }
      
        
      // 计算4H周期ZigZag(大周期)
      if(calculator4H != NULL && InpShow4H)
        {
         // 使用CalculateForSymbol方法直接计算4H周期数据，限制为200根K线
         int result = calculator4H.CalculateForSymbol(Symbol(), PERIOD_H4, 200);
         
         // 检查计算结果
         if(result < 0)
           {
            // 无法计算4H周期ZigZag
           }
         else
           {
            // 获取4H周期极值点
            has4HPoints = calculator4H.GetExtremumPoints(points4H);
            if(!has4HPoints)
              {
               // 无法获取4H周期极值点
              }
            else
              {
               // 使用交易分析器分析大周期极点数据
               if(ArraySize(points4H) >= 2)
                 {
                  // 对极点数组进行排序，确保最近的点在前面
                  // 注意：MQL5中的ArraySort不能直接用于自定义类对象数组
                  // 我们需要手动排序，按时间从新到旧排序
                  if(ArraySize(points4H) > 1)
                    {
                     // 使用冒泡排序按时间排序
                     for(int i = 0; i < ArraySize(points4H) - 1; i++)
                       {
                        for(int j = 0; j < ArraySize(points4H) - i - 1; j++)
                          {
                           // 如果当前元素的时间早于下一个元素，则交换它们
                           if(points4H[j].Time() < points4H[j + 1].Time())
                             {
                              CZigzagExtremumPoint temp = points4H[j];
                              points4H[j] = points4H[j + 1];
                              points4H[j + 1] = temp;
                             }
                          }
                       }
                    }
                  
                  // 分析区间
                  if(CTradeAnalyzer::AnalyzeRange(points4H, 2))
                    {
                     // 获取当前价格
                     double currentPrice = CInfoPanelManager::GetCurrentPrice();
                     
                     // 分析结果
                     
                     // 交易信息面板将在下面统一创建
                    }
                 }
              }
           }
        }
         
      // 如果需要显示文本标签
      if(InpShowLabels)
        {
         // 静态变量用于跟踪上次更新时间和最后一个极点
         static datetime lastLabelUpdateTime = 0;
         static datetime lastExtremumTime = 0;
         
         // 获取当前时间
         datetime currentLabelTime = TimeCurrent();
         
         // 清除旧标签
         if(prev_calculated == 0)
           {
            CLabelManager::DeleteAllLabels("ZigzagLabel_");
            CLabelManager::DeleteAllLabels("ZigzagLabel4H_");
            lastLabelUpdateTime = 0; // 重置更新时间
            lastExtremumTime = 0;    // 重置最后极点时间
           }
            
         // 获取当前周期极值点数组
         if(calculator.GetExtremumPoints(points))
           {
            hasCurrentPoints = true;
            
            // 检查是否有新的极点出现
            bool hasNewExtremum = false;
            datetime newestExtremumTime = lastExtremumTime;
            
            // 获取最新的极点时间（假设极点数组已经按时间排序）
            // 在ZigzagCalculator.mqh中，GetExtremumPoints方法返回的极点数组是按K线序号排序的
            // 我们需要找出时间最新的极点
            if(ArraySize(points) > 0)
              {
               // 找出时间最新的极点
               datetime maxTime = points[0].Time();
               int maxTimeIndex = 0;
               
               for(int i = 1; i < ArraySize(points); i++)
                 {
                  if(points[i].Time() > maxTime)
                    {
                     maxTime = points[i].Time();
                     maxTimeIndex = i;
                    }
                 }
               
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
               // 打印找到的极值点数量
               if(Period() == PERIOD_H1)
                 {
                  // 1小时周期找到极值点
                 }
               
               // 更新最后极点时间
               lastExtremumTime = newestExtremumTime;
               lastLabelUpdateTime = currentLabelTime;
               
               // 添加当前周期的标签
               for(int i = 0; i < ArraySize(points); i++)
                 {
                  //检查这个值是否在大周期峰谷值列表中出现
                  bool foundIn4H = false; // 大周期
                  
                  // 检查4H周期(大周期)
                  if(calculator4H != NULL && InpShow4H && has4HPoints && ArraySize(points4H) > 0)
                    {
                     // 使用公共方法检查价格是否在4H周期极值点数组中出现
                     foundIn4H = IsPriceInArray(points[i].Value(), points4H);
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
   
   // 创建或更新信息面板（只在必要时重绘）
   if(InpShowInfoPanel && calculator4H != NULL && InpShow4H)
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
         // 检查是否有有效的极点数据和交易分析结果
         if(has4HPoints && ArraySize(points4H) >= 1)
           {
            // 使用信息面板管理器创建统一的信息面板
            // 这里同时显示交易区间和趋势方向信息，以及其他必要信息
            if(CTradeAnalyzer::IsValid())
              {
               // 创建包含交易分析结果的面板
               CInfoPanelManager::CreateTradeInfoPanel(infoPanel);
               
               // 获取1小时周期的线段，排除4小时周期区间内的线段
               CZigzagSegment* h1Segments[];
               // 使用更远的时间范围确保获取完整的线段数据
               datetime startTime = iTime(Symbol(), PERIOD_H1, 200); // 获取最远200根1小时K线的时间范围
               datetime endTime = TimeCurrent();
               
               // 使用新的方法获取小周期线段，排除大周期区间内的线段
               Print("=== 开始获取1小时线段（排除4小时区间内线段）===");
               Print("时间范围: ", TimeToString(startTime), " 到 ", TimeToString(endTime));
               Print("扩展后的时间范围: ", TimeToString(startTime - 3600), " 到 ", TimeToString(endTime + 3600));
               
               // 先获取极值点来调试
               CZigzagExtremumPoint debugPoints[];
               if(::GetExtremumPointsInTimeRange(PERIOD_H1, startTime, endTime, debugPoints, 0))
                 {
                  Print("=== 调试：获取到的极值点 ===");
                  for(int j = 0; j < ArraySize(debugPoints); j++)
                    {
                     string pointType = debugPoints[j].Type() == EXTREMUM_PEAK ? "高点" : "低点";
                     Print("极值点 ", j, ": ", pointType, " 价格: ", DoubleToString(debugPoints[j].Value(), _Digits), 
                           " 时间: ", TimeToString(debugPoints[j].Time()));
                    }
                 }
               
               // 使用新方法获取1小时线段，排除4小时周期区间内的线段
               if(::GetSmallTimeframeSegmentsExcludingRange(PERIOD_H1, PERIOD_H4, startTime, endTime, h1Segments, SEGMENT_TREND_ALL, 50))
                 {
                  Print("成功获取到 ", ArraySize(h1Segments), " 个1小时线段");
                  
                  // 输出所有线段的详细信息
                  for(int i = 0; i < ArraySize(h1Segments); i++)
                    {
                     if(h1Segments[i] != NULL)
                       {
                        string direction = h1Segments[i].IsUptrend() ? "上涨" : "下跌";
                        Print("线段 ", i, ": ", direction, 
                              " 起点: ", DoubleToString(h1Segments[i].StartPrice(), _Digits),
                              " 终点: ", DoubleToString(h1Segments[i].EndPrice(), _Digits),
                              " 起点时间: ", TimeToString(h1Segments[i].StartTime()),
                              " 终点时间: ", TimeToString(h1Segments[i].EndTime()));
                       }
                    }
                  
                  // 获取上涨和下跌线段
                  CZigzagSegment* uptrendSegments[];
                  CZigzagSegment* downtrendSegments[];
                  
                  // 筛选上涨和下跌线段
                  Print("=== 开始筛选线段 ===");
                  ::FilterSegmentsByTrend(h1Segments, uptrendSegments, SEGMENT_TREND_UP);
                  ::FilterSegmentsByTrend(h1Segments, downtrendSegments, SEGMENT_TREND_DOWN);
                  
                  Print("筛选结果: 上涨线段 ", ArraySize(uptrendSegments), " 个, 下跌线段 ", ArraySize(downtrendSegments), " 个");
                  
                  // 输出上涨线段详情
                  Print("=== 上涨线段详情 ===");
                  for(int i = 0; i < ArraySize(uptrendSegments); i++)
                    {
                     if(uptrendSegments[i] != NULL)
                       {
                        Print("上涨线段 ", i, ": ",
                              DoubleToString(uptrendSegments[i].StartPrice(), _Digits), " → ",
                              DoubleToString(uptrendSegments[i].EndPrice(), _Digits),
                              " 时间: ", TimeToString(uptrendSegments[i].StartTime()), " → ",
                              TimeToString(uptrendSegments[i].EndTime()));
                       }
                    }
                  
                  // 输出下跌线段详情
                  Print("=== 下跌线段详情 ===");
                  for(int i = 0; i < ArraySize(downtrendSegments); i++)
                    {
                     if(downtrendSegments[i] != NULL)
                       {
                        Print("下跌线段 ", i, ": ",
                              DoubleToString(downtrendSegments[i].StartPrice(), _Digits), " → ",
                              DoubleToString(downtrendSegments[i].EndPrice(), _Digits),
                              " 时间: ", TimeToString(downtrendSegments[i].StartTime()), " → ",
                              TimeToString(downtrendSegments[i].EndTime()));
                       }
                    }
                  
                  // 按时间排序线段（从早到晚）
                  // 使用自定义方法排序，而不是ArraySort
                  Print("=== 开始排序线段 ===");
                  SortSegmentsByTime(uptrendSegments);
                  SortSegmentsByTime(downtrendSegments);
                  
                  // 输出排序后的上涨线段
                  Print("=== 排序后的上涨线段 ===");
                  for(int i = 0; i < ArraySize(uptrendSegments); i++)
                    {
                     if(uptrendSegments[i] != NULL)
                       {
                        Print("排序后上涨线段 ", i, ": ",
                              DoubleToString(uptrendSegments[i].StartPrice(), _Digits), " → ",
                              DoubleToString(uptrendSegments[i].EndPrice(), _Digits),
                              " 时间: ", TimeToString(uptrendSegments[i].StartTime()), " → ",
                              TimeToString(uptrendSegments[i].EndTime()));
                       }
                    }
                  
                  // 输出排序后的下跌线段
                  Print("=== 排序后的下跌线段 ===");
                  for(int i = 0; i < ArraySize(downtrendSegments); i++)
                    {
                     if(downtrendSegments[i] != NULL)
                       {
                        Print("排序后下跌线段 ", i, ": ",
                              DoubleToString(downtrendSegments[i].StartPrice(), _Digits), " → ",
                              DoubleToString(downtrendSegments[i].EndPrice(), _Digits),
                              " 时间: ", TimeToString(downtrendSegments[i].StartTime()), " → ",
                              TimeToString(downtrendSegments[i].EndTime()));
                       }
                    }
                  
                  // 获取最近一个1小时级别线段时间范围内的5分钟线段
                  Print("=== 获取最近一个1小时线段的5分钟线段 ===");
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
                     
                     string segmentDirection = nearestSegment.IsUptrend() ? "上涨" : "下跌";
                     Print("使用离当前时间最近的1小时", segmentDirection, "线段结束后的时间范围: ", 
                           TimeToString(m5StartTime), " 到 ", TimeToString(m5EndTime));
                     Print("1小时线段价格: ", DoubleToString(nearestSegment.StartPrice(), _Digits), 
                           " → ", DoubleToString(nearestSegment.EndPrice(), _Digits));
                     Print("从1小时线段结束价格 ", DoubleToString(nearestSegment.EndPrice(), _Digits), " 之后开始获取5分钟线段");
                    }
                  else
                    {
                     // 如果没有1小时线段，使用默认时间范围
                     m5StartTime = iTime(Symbol(), PERIOD_H1, 1);
                     m5EndTime = TimeCurrent();
                     Print("未找到1小时线段，使用默认时间范围: ", TimeToString(m5StartTime), " 到 ", TimeToString(m5EndTime));
                    }
                  
                  // 直接获取指定时间范围内的5分钟线段
                  if(::GetSegmentsInTimeRange(PERIOD_M5, m5StartTime, m5EndTime, m5Segments, 20))
                    {
                     Print("成功获取到 ", ArraySize(m5Segments), " 个5分钟线段");
                     
                     // 输出所有5分钟线段的详细信息
                     for(int k = 0; k < ArraySize(m5Segments); k++)
                       {
                        if(m5Segments[k] != NULL)
                          {
                           string direction = m5Segments[k].IsUptrend() ? "上涨" : "下跌";
                           Print("5分钟线段 ", k, ": ", direction, 
                                 " 起点: ", DoubleToString(m5Segments[k].StartPrice(), _Digits),
                                 " 终点: ", DoubleToString(m5Segments[k].EndPrice(), _Digits),
                                 " 起点时间: ", TimeToString(m5Segments[k].StartTime()),
                                 " 终点时间: ", TimeToString(m5Segments[k].EndTime()));
                          }
                       }
                     
                     // 获取上涨和下跌的5分钟线段
                     CZigzagSegment* m5UptrendSegments[];
                     CZigzagSegment* m5DowntrendSegments[];
                     
                     // 筛选5分钟上涨和下跌线段
                     ::FilterSegmentsByTrend(m5Segments, m5UptrendSegments, SEGMENT_TREND_UP);
                     ::FilterSegmentsByTrend(m5Segments, m5DowntrendSegments, SEGMENT_TREND_DOWN);
                     
                     Print("5分钟线段筛选结果: 上涨线段 ", ArraySize(m5UptrendSegments), " 个, 下跌线段 ", ArraySize(m5DowntrendSegments), " 个");
                     
                     // 按时间排序5分钟线段（从晚到早）
                     SortSegmentsByTime(m5UptrendSegments);
                     SortSegmentsByTime(m5DowntrendSegments);
                     
                     // 输出排序后的5分钟上涨线段
                     Print("=== 排序后的5分钟上涨线段 ===");
                     for(int k = 0; k < ArraySize(m5UptrendSegments); k++)
                       {
                        if(m5UptrendSegments[k] != NULL)
                          {
                           Print("5分钟上涨线段 ", k, ": ",
                                 DoubleToString(m5UptrendSegments[k].StartPrice(), _Digits), " → ",
                                 DoubleToString(m5UptrendSegments[k].EndPrice(), _Digits),
                                 " 时间: ", TimeToString(m5UptrendSegments[k].StartTime()), " → ",
                                 TimeToString(m5UptrendSegments[k].EndTime()));
                          }
                       }
                     
                     // 输出排序后的5分钟下跌线段
                     Print("=== 排序后的5分钟下跌线段 ===");
                     for(int k = 0; k < ArraySize(m5DowntrendSegments); k++)
                       {
                        if(m5DowntrendSegments[k] != NULL)
                          {
                           Print("5分钟下跌线段 ", k, ": ",
                                 DoubleToString(m5DowntrendSegments[k].StartPrice(), _Digits), " → ",
                                 DoubleToString(m5DowntrendSegments[k].EndPrice(), _Digits),
                                 " 时间: ", TimeToString(m5DowntrendSegments[k].StartTime()), " → ",
                                 TimeToString(m5DowntrendSegments[k].EndTime()));
                          }
                       }
                     
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
                  else
                    {
                     Print("获取5分钟线段失败");
                    }
                  
                  // 在信息面板上添加线段信息
                  Print("=== 更新信息面板 ===");
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
                  Print("获取1小时线段失败");
                 }
               
               // 绘制支撑或压力线
               CShapeManager::DrawSupportResistanceLines();
              }
            else
              {
               // 使用信息面板管理器创建简单信息面板
               CInfoPanelManager::CreateSimpleInfoPanel(infoPanel, "暂无有效的交易区间数据", InpInfoPanelColor, InpInfoPanelBgColor);
              }
           }
         else
           {
            // 使用信息面板管理器创建简单信息面板
            CInfoPanelManager::CreateSimpleInfoPanel(infoPanel, "暂无足够的4小时周期极点数据", InpInfoPanelColor, InpInfoPanelBgColor);
           }
           
         // 更新上次更新时间和价格
         lastInfoPanelUpdateTime = currentTime;
         lastInfoPanelPrice = currentPrice;
        }
     }
   
   // 返回计算的柱数
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| 按时间排序线段数组（从晚到早，最近的在前面）                        |
//+------------------------------------------------------------------+
void SortSegmentsByTime(CZigzagSegment* &segments[])
{
   int size = ArraySize(segments);
   if(size <= 1)
      return;
      
   // 使用简单的冒泡排序，按时间从晚到早排序
   for(int i = 0; i < size - 1; i++)
   {
      for(int j = 0; j < size - i - 1; j++)
      {
         if(segments[j] != NULL && segments[j+1] != NULL)
         {
            // 按开始时间反向排序（最近的时间在前面）
            if(segments[j].StartTime() < segments[j+1].StartTime())
            {
               // 交换位置
               CZigzagSegment* temp = segments[j];
               segments[j] = segments[j+1];
               segments[j+1] = temp;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 检查价格是否在极值点数组中出现                                    |
//+------------------------------------------------------------------+
bool IsPriceInArray(double price, CZigzagExtremumPoint &points[])
{
   for(int i = 0; i < ArraySize(points); i++)
   {
      // 考虑价格精度，使用MathAbs和Point()进行比较
      if(MathAbs(points[i].Value() - price) < Point() * 2)
         return true;
   }
   return false;
}
//+------------------------------------------------------------------+
