//+------------------------------------------------------------------+
//|                                                    MyZigzag.mq5 |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

//--- 包含文件
#include "ZigzagCalculator.mqh"

//--- 指标设置
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   1
#property indicator_type1   DRAW_COLOR_ZIGZAG
#property indicator_color1  clrDodgerBlue,clrRed

//--- 输入参数
input int InpDepth    =12;  // 深度
input int InpDeviation=5;   // 偏差
input int InpBackstep =3;   // 回溯步数

//--- 声明ZigZag计算器指针
CZigzagCalculator *calculator = NULL;

//--- 不需要全局声明指标缓冲区，直接使用计算器对象的公开缓冲区

//+------------------------------------------------------------------+
//| 自定义指标初始化函数                                             |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- 初始化ZigZag计算器
   calculator = new CZigzagCalculator(InpDepth, InpDeviation, InpBackstep);
   
//--- 指标缓冲区 mapping
   SetIndexBuffer(0, calculator.ZigzagPeakBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, calculator.ZigzagBottomBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, calculator.ColorBuffer, INDICATOR_COLOR_INDEX);
   
//--- 设置精度
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
//--- DataWindow和指标子窗口标签的名称
   string short_name = StringFormat("MyZigzag(%d,%d,%d)", InpDepth, InpDeviation, InpBackstep);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, short_name);
//--- 设置空值
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
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
     }
   
   // 计算ZigZag
   if(calculator != NULL)
     {
      calculator.Calculate(high, low, rates_total, prev_calculated);
      
      // 计算结果已直接存储在计算器对象的公开缓冲区中，无需额外复制
     }
   
   // 返回计算的柱数
   return(rates_total);
  }
//+------------------------------------------------------------------+