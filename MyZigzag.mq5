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
         // 打印调试信息，查看获取到的4H极值点数量
         Print(StringFormat("获取到4H极值点数量：%d个", ArraySize(points4H)));
         for(int i = 0; i < ArraySize(points4H); i++)
           {
            Print(StringFormat("4H极值点%d: 时间=%s, 价格=%.5f, 类型=%s", 
                             i,
                             TimeToString(points4H[i].Time(), TIME_DATE|TIME_MINUTES),
                             points4H[i].Value(),
                             points4H[i].IsPeak() ? "峰值" : "谷值"));
           }
         
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
   DrawExtremumPointLabels(points4H, "4H", true);
   
   // 绘制1H子线段，传递4H标签点用于重叠检测
   Draw1HSubSegments(points4H);
   
   // 绘制5分钟子线段
   Draw5MSubSegments(points4H);
  }

//+------------------------------------------------------------------+
//| 绘制极值点标签                                                   |
//+------------------------------------------------------------------+
void DrawExtremumPointLabels(CZigzagExtremumPoint &points[], string source, bool isMain)
  {
   for(int i = 0; i < ArraySize(points); i++)
     {
      string labelName = StringFormat("ZigzagLabel_%s_%d", source, i);
      string labelText = StringFormat("%s: %s", source, DoubleToString(points[i].Value(), _Digits));
      
      // 确定使用的时间，对于4H极点使用1小时周期的时间
      datetime labelTime = points[i].Time();
      if(source == "4H")
      {
         // 对于4小时极点，使用预计算的1小时K线时间
         datetime h1Time = points[i].GetH1Time();
         if(h1Time > 0)
         {
            labelTime = h1Time;
         }
      }
      
      // 创建工具提示
      string tooltipText = StringFormat("来源: %s\n时间: %s\n价格: %s\n类型: %s", 
                                      source,
                                      TimeToString(points[i].Time(), TIME_DATE|TIME_MINUTES),
                                      DoubleToString(points[i].Value(), _Digits),
                                      points[i].IsPeak() ? "峰值" : "谷值");
      
      // 创建标签
      CLabelManager::CreateTextLabel(
         labelName,
         labelText,
         labelTime,  // 使用修正后的时间
         points[i].Value(),
         points[i].IsPeak(),
         isMain,  // 4H为主要（大周期），1H为次要
         NULL,    // 使用默认颜色
         NULL,    // 使用默认字体
         0,       // 使用默认字体大小
         0,       // X轴偏移量
         true,    // 启用居中显示
         tooltipText
      );
     }
  }

//+------------------------------------------------------------------+
//| 绘制线段                                                         |
//+------------------------------------------------------------------+
void DrawSegmentLines(CZigzagExtremumPoint &points[], string source, bool isMain)
  {
   // 至少需要2个点才能绘制线段
   if(ArraySize(points) < 2)
      return;
      
   // 根据来源选择线段颜色
   color lineColor = isMain ? InpLabel4HColor : InpLabelColor;
   
   // 绘制连接线段
   for(int i = 0; i < ArraySize(points) - 1; i++)
     {
      string lineName = StringFormat("ZigzagLine_%s_%d", source, i);
      
      // 创建连接线
      CLineManager::CreateTrendLine(
         lineName,
         points[i].Time(),
         points[i].Value(),
         points[i+1].Time(),
         points[i+1].Value(),
         lineColor,
         1,  // 线宽
         STYLE_SOLID  // 线型
      );
     }
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
   
   // 获取4H主线段时间范围
   datetime mainStartTime = currentMainSegment.StartTime();
   datetime mainEndTime = currentMainSegment.EndTime();
   
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
      Print("警告: 无法从管理器获取1H线段数组");
      delete segmentManager;
      return;
     }
   
   int totalSegments = ArraySize(h1Segments);
   Print(StringFormat("获取到1H子线段总数：%d个", totalSegments));
   Print(StringFormat("4H主线段时间范围: %s 到 %s", 
                    TimeToString(mainStartTime, TIME_DATE|TIME_MINUTES),
                    TimeToString(mainEndTime, TIME_DATE|TIME_MINUTES)));
   
   if(totalSegments == 0)
     {
      Print("警告: 获取到的1H子线段数量为0");
      delete segmentManager;
      return;
     }
   
   // 首先按时间排序线段，确保按时间先后顺序排列
   ::SortSegmentsByTime(h1Segments, true, true);  // 升序排列，早的在前
   
   // 统计上涨和下跌线段数量
   int uptrendCount = 0;
   int downtrendCount = 0;
   
   // 输出所有线段的详细信息
   for(int i = 0; i < totalSegments; i++)
     {
      if(h1Segments[i] != NULL)
        {
         if(h1Segments[i].IsUptrend())
           {
            uptrendCount++;
           }
         else
           {
            downtrendCount++;
           }
         
         Print(StringFormat("原始线段%d: %s - %s, 价格: %.5f - %.5f, 趋势: %s", 
                          i,
                          TimeToString(h1Segments[i].StartTime(), TIME_DATE|TIME_MINUTES),
                          TimeToString(h1Segments[i].EndTime(), TIME_DATE|TIME_MINUTES),
                          h1Segments[i].StartPrice(),
                          h1Segments[i].EndPrice(),
                          h1Segments[i].IsUptrend() ? "上涨" : "下跌"));
        }
     }
   
   Print(StringFormat("原始线段统计 - 上涨: %d个, 下跌: %d个", uptrendCount, downtrendCount));
   
   // 去除可能的重复点和无效线段
   CZigzagSegment* validSegments[];
   int validCount = 0;
   int validUptrendCount = 0;
   int validDowntrendCount = 0;
   
   // 筛选有效的线段，去除重复和无效的线段
   for(int i = 0; i < totalSegments; i++)
     {
      if(h1Segments[i] != NULL)
        {
         bool isInvalid = false;
         
         // 检查线段是否在主线段时间范围内
         // 允许线段的结束时间稍微超出主线段范围，但开始时间必须在主线段范围内
         if(h1Segments[i].StartTime() < mainStartTime || h1Segments[i].StartTime() > mainEndTime)
           {
            Print(StringFormat("线段%d被过滤: 起始时间超出主线段时间范围 [%s - %s] 不在 [%s - %s]内", 
                             i,
                             TimeToString(h1Segments[i].StartTime(), TIME_DATE|TIME_MINUTES),
                             TimeToString(h1Segments[i].EndTime(), TIME_DATE|TIME_MINUTES),
                             TimeToString(mainStartTime, TIME_DATE|TIME_MINUTES),
                             TimeToString(mainEndTime, TIME_DATE|TIME_MINUTES)));
            isInvalid = true;
           }
         
         // 检查线段是否有效（起点时间不能等于终点时间）
         if(h1Segments[i].StartTime() == h1Segments[i].EndTime())
           {
            Print(StringFormat("线段%d被过滤: 起点时间等于终点时间", i));
            isInvalid = true;
           }
         
         // 不再进行重复检测，因为连续的线段可能有时间重叠，这是正常的
         
         if(!isInvalid)
           {
            // 将有效线段添加到数组
            ArrayResize(validSegments, validCount + 1);
            validSegments[validCount] = h1Segments[i];
            
            // 统计上涨和下跌线段
            if(h1Segments[i].IsUptrend())
              {
               validUptrendCount++;
              }
            else
              {
               validDowntrendCount++;
              }
            
            Print(StringFormat("线段%d通过筛选: %s - %s, 价格: %.5f - %.5f, 趋势: %s", 
                             validCount,
                             TimeToString(h1Segments[i].StartTime(), TIME_DATE|TIME_MINUTES),
                             TimeToString(h1Segments[i].EndTime(), TIME_DATE|TIME_MINUTES),
                             h1Segments[i].StartPrice(),
                             h1Segments[i].EndPrice(),
                             h1Segments[i].IsUptrend() ? "上涨" : "下跌"));
            
            validCount++;
           }
         // 注意：这里不再删除h1Segments[i]，因为这些指针会在函数结束时统一释放
        }
     }
   
   Print(StringFormat("有效线段数量：%d个 (上涨: %d个, 下跌: %d个)", validCount, validUptrendCount, validDowntrendCount));
   
   if(validCount == 0)
     {
      Print("警告: 没有有效的1H子线段可绘制");
      // 释放原始数组的所有元素
      for(int i = 0; i < totalSegments; i++)
        {
         if(h1Segments[i] != NULL)
           {
            delete h1Segments[i];
            h1Segments[i] = NULL;
           }
        }
      delete segmentManager;
      return;
     }
   
   // 绘制每条1H子线段
   int drawnCount = 0;
   int drawnUptrendCount = 0;
   int drawnDowntrendCount = 0;
   
   for(int i = 0; i < validCount; i++)
     {
      if(validSegments[i] != NULL)
        {
         string lineName = StringFormat("ZigzagLine_1H_%d", i);
         
         // 确定线段颜色：上涨用蓝色，下跌用红色
         color lineColor;
         if(validSegments[i].IsUptrend())
           {
            // 上涨线段 - 蓝色
            lineColor = clrBlue;
            drawnUptrendCount++;
           }
         else
           {
            // 下跌线段 - 红色
            lineColor = clrRed;
            drawnDowntrendCount++;
           }
         
         // 输出调试信息
         Print(StringFormat("准备绘制1H线段 %d: %s - %s, 价格: %.5f - %.5f, 趋势: %s", 
                          i,
                          TimeToString(validSegments[i].StartTime(), TIME_DATE|TIME_MINUTES),
                          TimeToString(validSegments[i].EndTime(), TIME_DATE|TIME_MINUTES),
                          validSegments[i].StartPrice(),
                          validSegments[i].EndPrice(),
                          validSegments[i].IsUptrend() ? "上涨" : "下跌"));
         
         // 创建连接线 - 绕过防闪烁机制，强制更新
         // 先删除可能存在的同名对象
         ObjectDelete(0, lineName);
         
         // 创建趋势线
         bool lineCreated = ObjectCreate(0, lineName, OBJ_TREND, 0, 
                                       validSegments[i].StartTime(), validSegments[i].StartPrice(),
                                       validSegments[i].EndTime(), validSegments[i].EndPrice());
         
         if(!lineCreated)
           {
            Print(StringFormat("警告: 线段%d创建失败", i));
           }
         else
           {
            // 设置线条属性 - 线宽改为2，使线条更粗一些
            ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);
            ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);  // 线宽改为2
            ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, lineName, OBJPROP_RAY_LEFT, false);
            ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, lineName, OBJPROP_BACK, false); // 确保线条在前景显示
            ObjectSetInteger(0, lineName, OBJPROP_ZORDER, 1); // 设置Z顺序
            
            drawnCount++;
            Print(StringFormat("线段%d创建成功", i));
           }
         
         // 只在线段起点和终点绘制标签
         string startLabelName = StringFormat("ZigzagLabel_1H_%d_Start", i);
         string endLabelName = StringFormat("ZigzagLabel_1H_%d_End", i);
         
         string startLabelText = StringFormat("1H: %s", DoubleToString(validSegments[i].StartPrice(), _Digits));
         string endLabelText = StringFormat("1H: %s", DoubleToString(validSegments[i].EndPrice(), _Digits));
         
         // 检查起点标签是否与4小时标签重叠
         bool startOverlapsWith4H = IsLabelOverlappingWith4HLabels(validSegments[i].StartTime(), points4H);
         datetime startTime = validSegments[i].StartTime();
         
         // 创建起点标签
         ObjectDelete(0, startLabelName);
         bool startLabelCreated = ObjectCreate(0, startLabelName, OBJ_TEXT, 0, 
                                              startTime, validSegments[i].StartPrice());
         
         if(startLabelCreated)
           {
            // 根据是否重叠设置不同的标签文本和颜色
            string actualStartLabelText = startLabelText;
            color actualStartLabelColor = clrWhite;  // 默认白色
            
            if(startOverlapsWith4H)
              {
               // 重叠时修改文本为4H标签格式
               actualStartLabelText = StringFormat("4H: %s", DoubleToString(validSegments[i].StartPrice(), _Digits));
               actualStartLabelColor = clrOrange;  // 重叠时使用橙色（4H标签颜色）
              }
            
            // 设置标签属性
            ObjectSetString(0, startLabelName, OBJPROP_TEXT, actualStartLabelText);
            ObjectSetString(0, startLabelName, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, startLabelName, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, startLabelName, OBJPROP_COLOR, actualStartLabelColor);
            ObjectSetInteger(0, startLabelName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, startLabelName, OBJPROP_SELECTABLE, false);
            ObjectSetDouble(0, startLabelName, OBJPROP_ANGLE, 0);
            
            // 设置标签位置和锚点
            if(validSegments[i].StartPoint().IsPeak())
               ObjectSetInteger(0, startLabelName, OBJPROP_ANCHOR, ANCHOR_LOWER);
            else
               ObjectSetInteger(0, startLabelName, OBJPROP_ANCHOR, ANCHOR_UPPER);
            
            // 设置X轴偏移量
            ObjectSetInteger(0, startLabelName, OBJPROP_XOFFSET, 0);
            
            Print(StringFormat("线段%d起点标签创建成功", i));
           }
         else
           {
            Print(StringFormat("警告: 线段%d起点标签创建失败", i));
           }
         
         // 检查终点标签是否与4小时标签重叠
         bool endOverlapsWith4H = IsLabelOverlappingWith4HLabels(validSegments[i].EndTime(), points4H);
         datetime endTime = validSegments[i].EndTime();
         
         // 创建终点标签
         ObjectDelete(0, endLabelName);
         bool endLabelCreated = ObjectCreate(0, endLabelName, OBJ_TEXT, 0, 
                                            endTime, validSegments[i].EndPrice());
         
         if(endLabelCreated)
           {
            // 根据是否重叠设置不同的标签文本和颜色
            string actualEndLabelText = endLabelText;
            color actualEndLabelColor = clrWhite;  // 默认白色
            
            if(endOverlapsWith4H)
              {
               // 重叠时修改文本为4H标签格式
               actualEndLabelText = StringFormat("4H: %s", DoubleToString(validSegments[i].EndPrice(), _Digits));
               actualEndLabelColor = clrOrange;  // 重叠时使用橙色（4H标签颜色）
              }
            
            // 设置标签属性
            ObjectSetString(0, endLabelName, OBJPROP_TEXT, actualEndLabelText);
            ObjectSetString(0, endLabelName, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, endLabelName, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, endLabelName, OBJPROP_COLOR, actualEndLabelColor);
            ObjectSetInteger(0, endLabelName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, endLabelName, OBJPROP_SELECTABLE, false);
            ObjectSetDouble(0, endLabelName, OBJPROP_ANGLE, 0);
            
            // 设置标签位置和锚点
            if(validSegments[i].EndPoint().IsPeak())
               ObjectSetInteger(0, endLabelName, OBJPROP_ANCHOR, ANCHOR_LOWER);
            else
               ObjectSetInteger(0, endLabelName, OBJPROP_ANCHOR, ANCHOR_UPPER);
            
            // 设置X轴偏移量
            ObjectSetInteger(0, endLabelName, OBJPROP_XOFFSET, 0);
            
            Print(StringFormat("线段%d终点标签创建成功", i));
           }
         else
           {
            Print(StringFormat("警告: 线段%d终点标签创建失败", i));
           }
        }
     }
   
   Print(StringFormat("成功绘制线段数量：%d个 (上涨: %d个, 下跌: %d个)", drawnCount, drawnUptrendCount, drawnDowntrendCount));
   
   // 释放内存
   for(int i = 0; i < validCount; i++)
     {
      if(validSegments[i] != NULL)
        {
         delete validSegments[i];
         validSegments[i] = NULL;
        }
     }
   
   // 释放原始数组的所有元素
   for(int i = 0; i < totalSegments; i++)
     {
      if(h1Segments[i] != NULL)
        {
         delete h1Segments[i];
         h1Segments[i] = NULL;
        }
     }
   
   // 释放线段管理器
   delete segmentManager;
  }

//+------------------------------------------------------------------+
//| 绘制5分钟子线段                                                  |
//+------------------------------------------------------------------+
void Draw5MSubSegments(CZigzagExtremumPoint &points4H[])
  {
   // 获取当前主线段
   CZigzagSegment* currentMainSegment = g_tradeAnalyzer.GetCurrentSegment();
   if(currentMainSegment == NULL)
     {
      Print("警告: 无法获取当前主线段");
      return;
     }
   
   // 获取4H主线段时间范围
   datetime mainStartTime = currentMainSegment.StartTime();
   datetime mainEndTime = currentMainSegment.EndTime();
   
   // 获取5分钟子线段管理器（仅限当前主交易区间内）
   CZigzagSegmentManager* segmentManager = currentMainSegment.GetSmallerTimeframeSegments(PERIOD_M5);
   if(segmentManager == NULL)
     {
      Print("警告: 无法获取5分钟线段管理器");
      return;
     }
   
   // 从管理器中获取线段数组
   CZigzagSegment* m5Segments[];
   if(!segmentManager.GetSegments(m5Segments))
     {
      Print("警告: 无法从管理器获取5分钟线段数组");
      delete segmentManager;
      return;
     }
   
   int totalSegments = ArraySize(m5Segments);
   Print(StringFormat("获取到5分钟子线段总数：%d个", totalSegments));
   Print(StringFormat("4H主线段时间范围: %s 到 %s", 
                    TimeToString(mainStartTime, TIME_DATE|TIME_MINUTES),
                    TimeToString(mainEndTime, TIME_DATE|TIME_MINUTES)));
   
   if(totalSegments == 0)
     {
      Print("警告: 获取到的5分钟子线段数量为0");
      delete segmentManager;
      return;
     }
   
   // 首先按时间排序线段，确保按时间先后顺序排列
   ::SortSegmentsByTime(m5Segments, true, true);  // 升序排列，早的在前
   
   // 统计上涨和下跌线段数量
   int uptrendCount = 0;
   int downtrendCount = 0;
   
   // 输出所有线段的详细信息
   for(int i = 0; i < totalSegments; i++)
     {
      if(m5Segments[i] != NULL)
        {
         if(m5Segments[i].IsUptrend())
           {
            uptrendCount++;
           }
         else
           {
            downtrendCount++;
           }
         
         Print(StringFormat("5分钟原始线段%d: %s - %s, 价格: %.5f - %.5f, 趋势: %s", 
                          i,
                          TimeToString(m5Segments[i].StartTime(), TIME_DATE|TIME_MINUTES),
                          TimeToString(m5Segments[i].EndTime(), TIME_DATE|TIME_MINUTES),
                          m5Segments[i].StartPrice(),
                          m5Segments[i].EndPrice(),
                          m5Segments[i].IsUptrend() ? "上涨" : "下跌"));
        }
     }
   
   Print(StringFormat("5分钟原始线段统计 - 上涨: %d个, 下跌: %d个", uptrendCount, downtrendCount));
   
   // 去除可能的重复点和无效线段
   CZigzagSegment* validSegments[];
   int validCount = 0;
   int validUptrendCount = 0;
   int validDowntrendCount = 0;
   
   // 筛选有效的线段，去除重复和无效的线段
   for(int i = 0; i < totalSegments; i++)
     {
      if(m5Segments[i] != NULL)
        {
         bool isInvalid = false;
         
         // 检查线段是否在主线段时间范围内
         // 允许线段的结束时间稍微超出主线段范围，但开始时间必须在主线段范围内
         if(m5Segments[i].StartTime() < mainStartTime || m5Segments[i].StartTime() > mainEndTime)
           {
            Print(StringFormat("5分钟线段%d被过滤: 起始时间超出主线段时间范围 [%s - %s] 不在 [%s - %s]内", 
                             i,
                             TimeToString(m5Segments[i].StartTime(), TIME_DATE|TIME_MINUTES),
                             TimeToString(m5Segments[i].EndTime(), TIME_DATE|TIME_MINUTES),
                             TimeToString(mainStartTime, TIME_DATE|TIME_MINUTES),
                             TimeToString(mainEndTime, TIME_DATE|TIME_MINUTES)));
            isInvalid = true;
           }
         
         // 检查线段是否有效（起点时间不能等于终点时间）
         if(m5Segments[i].StartTime() == m5Segments[i].EndTime())
           {
            Print(StringFormat("5分钟线段%d被过滤: 起点时间等于终点时间", i));
            isInvalid = true;
           }
         
         // 不再进行重复检测，因为连续的线段可能有时间重叠，这是正常的
         
         if(!isInvalid)
           {
            // 将有效线段添加到数组
            ArrayResize(validSegments, validCount + 1);
            validSegments[validCount] = m5Segments[i];
            
            // 统计上涨和下跌线段
            if(m5Segments[i].IsUptrend())
              {
               validUptrendCount++;
              }
            else
              {
               validDowntrendCount++;
              }
            
            Print(StringFormat("5分钟线段%d通过筛选: %s - %s, 价格: %.5f - %.5f, 趋势: %s", 
                             validCount,
                             TimeToString(m5Segments[i].StartTime(), TIME_DATE|TIME_MINUTES),
                             TimeToString(m5Segments[i].EndTime(), TIME_DATE|TIME_MINUTES),
                             m5Segments[i].StartPrice(),
                             m5Segments[i].EndPrice(),
                             m5Segments[i].IsUptrend() ? "上涨" : "下跌"));
            
            validCount++;
           }
         // 注意：这里不再删除m5Segments[i]，因为这些指针会在函数结束时统一释放
        }
     }
   
   Print(StringFormat("5分钟有效线段数量：%d个 (上涨: %d个, 下跌: %d个)", validCount, validUptrendCount, validDowntrendCount));
   
   // 释放内存
   for(int i = 0; i < validCount; i++)
     {
      if(validSegments[i] != NULL)
        {
         delete validSegments[i];
         validSegments[i] = NULL;
        }
     }
   
   // 释放原始数组的所有元素
   for(int i = 0; i < totalSegments; i++)
     {
      if(m5Segments[i] != NULL)
        {
         delete m5Segments[i];
         m5Segments[i] = NULL;
        }
     }
   
   // 释放线段管理器
   delete segmentManager;
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
      CZigzagSegmentManager* segmentManager = currentMainSegment.GetSmallerTimeframeSegments(PERIOD_H1);
      if(segmentManager != NULL)
        {
         // 从管理器中获取线段数组
         CZigzagSegment* h1Segments[];
         if(segmentManager.GetSegments(h1Segments))
           {
            int totalSegments = ArraySize(h1Segments);
            
            // 筛选上涨和下跌线段
            CZigzagSegment* uptrendSegments[];
            CZigzagSegment* downtrendSegments[];
            
            ::FilterSegmentsByTrend(h1Segments, uptrendSegments, SEGMENT_TREND_UP);
            ::FilterSegmentsByTrend(h1Segments, downtrendSegments, SEGMENT_TREND_DOWN);
            
            // 按时间排序
            ::SortSegmentsByTime(uptrendSegments, false, false);
            ::SortSegmentsByTime(downtrendSegments, false, false);
            
            // 在信息面板上添加线段信息
            CInfoPanelManager::AddSegmentInfo(infoPanel, uptrendSegments, downtrendSegments, InpInfoPanelColor);
            
            // 释放筛选后的线段数组
            for(int i = 0; i < ArraySize(uptrendSegments); i++)
              {
               if(uptrendSegments[i] != NULL)
                 {
                  delete uptrendSegments[i];
                  uptrendSegments[i] = NULL;
                 }
              }
              
            for(int i = 0; i < ArraySize(downtrendSegments); i++)
              {
               if(downtrendSegments[i] != NULL)
                 {
                  delete downtrendSegments[i];
                  downtrendSegments[i] = NULL;
                 }
              }
            
            // 释放从管理器获取的线段数组
            for(int i = 0; i < totalSegments; i++)
              {
               if(h1Segments[i] != NULL)
                 {
                  delete h1Segments[i];
                  h1Segments[i] = NULL;
                 }
              }
           }
         // 释放线段管理器
         delete segmentManager;
        }
     }
   
   // 绘制支撑或压力线
   CShapeManager::DrawSupportResistanceLines();
   
   // 更新时间和价格
   lastInfoPanelUpdateTime = currentTime;
   lastInfoPanelPrice = currentPrice;
  }

//+------------------------------------------------------------------+
//| 检查标签时间是否与4小时标签重叠                                  |
//+------------------------------------------------------------------+
bool IsLabelOverlappingWith4HLabels(datetime labelTime, CZigzagExtremumPoint &points4H[])
  {
   // 检查给定的时间是否与任何4小时标签时间重叠（时间差在1小时内）
   for(int i = 0; i < ArraySize(points4H); i++)
     {
      // 获取4小时标签的时间（使用1小时周期时间）
      datetime h1Time = points4H[i].GetH1Time();
      if(h1Time > 0)
        {
         // 如果时间差在1小时内，认为是重叠的
         if(MathAbs(labelTime - h1Time) < 3600)  // 3600秒 = 1小时
           {
            return true;
           }
        }
     }
   return false;
  }
