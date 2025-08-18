//+------------------------------------------------------------------+
//|                                                    MyZigzag.mq5 |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

//--- 包含文件
#include "ZigzagCalculator.mqh"
#include "GraphicsUtils.mqh"
#include "CommonUtils.mqh"

//--- 指标设置
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   2
#property indicator_type1   DRAW_COLOR_ZIGZAG  // 当前周期(中周期)
#property indicator_color1  clrDodgerBlue,clrRed
#property indicator_width1  2
#property indicator_type2   DRAW_COLOR_ZIGZAG  // 4小时周期(大周期)
#property indicator_color2  clrGold,clrPurple
#property indicator_width2  2

//--- 输入参数
input int InpDepth    =12;  // 深度
input int InpDeviation=5;   // 偏差
input int InpBackstep =3;   // 回溯步数
input bool InpShowLabels=true; // 显示峰谷值文本标签
input color InpLabelColor=clrWhite; // 标签文本颜色
input bool InpShow5M=true;  // 计算5分钟周期ZigZag(小周期)
input bool InpShow4H=true;  // 显示4小时周期ZigZag(大周期)
input color InpLabel4HColor=clrOrange; // 4小时周期标签颜色
input int InpCacheTimeout=300; // 缓存超时时间(秒)
input int InpMaxBarsH1=200;   // 1小时周期最大计算K线数

//--- 声明ZigZag计算器指针
CZigzagCalculator *calculator = NULL;      // 当前周期计算器(默认对应中周期)
CZigzagCalculator *calculator5M = NULL;    // 5M周期计算器(小周期)
CZigzagCalculator *calculator4H = NULL;    // 4H周期计算器(大周期)

//--- 缓存变量
datetime          lastCalculationTime = 0;  // 上次计算的时间
int               lastCalculatedBars = 0;   // 上次计算的K线数量
bool              cacheInitialized = false; // 缓存是否已初始化

//+------------------------------------------------------------------+
//| 自定义指标初始化函数                                             |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- 初始化ZigZag计算器
   calculator = new CZigzagCalculator(InpDepth, InpDeviation, InpBackstep, 3, PERIOD_CURRENT); // 当前周期(默认对应中周期)
   calculator5M = new CZigzagCalculator(InpDepth, InpDeviation, InpBackstep, 3, PERIOD_M5);    // 5M周期(小周期)
   calculator4H = new CZigzagCalculator(InpDepth, InpDeviation, InpBackstep, 3, PERIOD_H4);    // 4H周期(大周期)
   
//--- 初始化标签管理器 - 传入不同的颜色
   CLabelManager::Init(InpLabelColor, InpLabel4HColor);
   
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
 
  }

//+------------------------------------------------------------------+
//| ZigZag计算                                                      |
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
                  
                  // 打印调试信息
                  Print("1小时周期ZigZag完全重新计算，总K线数: ", rates_total);
                 }
               else
                 {
                  // 正常计算所有K线
                  calculator.Calculate(high, low, rates_total, 0);
                  
                  // 打印调试信息
                  Print("1小时周期ZigZag完全重新计算，总K线数: ", rates_total);
                 }
              }
            else
              {
               // 增量计算，只计算新增的K线
               calculator.Calculate(high, low, rates_total, prev_calculated);
               
               // 打印调试信息
               Print("1小时周期ZigZag增量计算，总K线数: ", rates_total, ", 新增K线数: ", rates_total - prev_calculated);
              }
            
            // 更新缓存状态
            lastCalculationTime = currentTime;
            lastCalculatedBars = rates_total;
            cacheInitialized = true;
           }
         else
           {
            // 使用缓存结果，不需要重新计算
            Print("1小时周期ZigZag使用缓存结果，总K线数: ", rates_total);
           }
        }
      else
        {
         // 其他周期正常计算
         calculator.Calculate(high, low, rates_total, prev_calculated);
        }
      
      // 声明各周期极值点数组（提升作用域到整个函数）
      CZigzagExtremumPoint points5M[]; // 小周期(5M)
      CZigzagExtremumPoint points4H[]; // 大周期(4H)
      bool has5MPoints = false;
      bool has4HPoints = false;
      
      // 计算5M周期ZigZag(小周期)
      if(calculator5M != NULL && InpShow5M)
        {
         // 使用CalculateForSymbol方法直接计算5M周期数据，限制为300根K线
         int result = calculator5M.CalculateForSymbol(Symbol(), PERIOD_M5, 300);
         
         // 检查计算结果
         if(result < 0)
           {
            Print("无法计算5M周期ZigZag，错误代码: ", result);
           }
         else
           {
            // 获取5M周期极值点
            has5MPoints = calculator5M.GetExtremumPoints(points5M);
            if(!has5MPoints)
              {
               Print("无法获取5M周期极值点");
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
            Print("无法计算4H周期ZigZag，错误代码: ", result);
           }
         else
           {
            // 获取4H周期极值点
            has4HPoints = calculator4H.GetExtremumPoints(points4H);
            if(!has4HPoints)
              {
               Print("无法获取4H周期极值点");
              }
           }
        }
         
      // 如果需要显示文本标签
      if(InpShowLabels)
        {
         // 清除旧标签
         if(prev_calculated == 0)
           {
            CLabelManager::DeleteAllLabels("ZigzagLabel_");
            CLabelManager::DeleteAllLabels("ZigzagLabel4H_");
           }
            
         // 获取当前周期极值点数组
         CZigzagExtremumPoint points[];
         if(calculator.GetExtremumPoints(points))
           {          
            // 打印找到的极值点数量
            if(Period() == PERIOD_H1)
              {
               Print("1小时周期找到极值点数量: ", ArraySize(points));
              }
            
            // 添加当前周期的标签
            for(int i = 0; i < ArraySize(points); i++)
              {
               //检查这个值是否在大周期峰谷值列表中出现
               bool foundIn4H = false; // 大周期
               double tolerance = 0.0001; // 价格匹配的容差
               
               
               // 检查4H周期(大周期)
               if(calculator4H != NULL && InpShow4H && has4HPoints && ArraySize(points4H) > 0)
                 {
                  // 遍历4H周期的所有极值点
                  for(int j = 0; j < ArraySize(points4H); j++)
                    {
                     // 如果价格在容差范围内匹配，则认为是同一个价格点
                     if(MathAbs(points[i].Value() - points4H[j].Value()) < tolerance)
                       {
                        foundIn4H = true;
                        break;
                       }
                    }
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
   
   // 返回计算的柱数
   return(rates_total);
  }

//+------------------------------------------------------------------+