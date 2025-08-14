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

//--- 指标设置
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   2
#property indicator_type1   DRAW_COLOR_ZIGZAG  // 当前周期
#property indicator_color1  clrDodgerBlue,clrRed
#property indicator_type2   DRAW_COLOR_ZIGZAG  // 4小时周期
#property indicator_color2  clrLime,clrMagenta

//--- 输入参数
input int InpDepth    =12;  // 深度
input int InpDeviation=5;   // 偏差
input int InpBackstep =3;   // 回溯步数
input bool InpShowLabels=true; // 显示峰谷值文本标签
input color InpLabelColor=clrWhite; // 标签文本颜色
input bool InpShow4H=true;  // 显示4小时周期ZigZag
input color InpLabel4HColor=clrYellow; // 4小时周期标签颜色

//--- 声明ZigZag计算器指针
CZigzagCalculator *calculator = NULL;      // 当前周期计算器
CZigzagCalculator *calculator4H = NULL;    // 4H周期计算器

//+------------------------------------------------------------------+
//| 自定义指标初始化函数                                             |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- 初始化ZigZag计算器
   calculator = new CZigzagCalculator(InpDepth, InpDeviation, InpBackstep, 3, PERIOD_CURRENT); // 当前周期
   calculator4H = new CZigzagCalculator(InpDepth, InpDeviation, InpBackstep, 3, PERIOD_H4);    // 4H周期
   
//--- 初始化标签管理器 - 传入两种不同的颜色
   CLabelManager::Init(InpLabelColor, InpLabel4HColor);
   
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
//--- 关闭图表网格
   ChartSetInteger(0, CHART_SHOW_GRID, 0);   
//--- 关闭图表交易水平线显示
   ChartSetInteger(0, CHART_SHOW_TRADE_LEVELS, false);
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
   
   // 释放4H周期计算器对象
   if(calculator4H != NULL)
     {
      delete calculator4H;
      calculator4H = NULL;
     }
     
   // 删除所有文本标签
   CLabelManager::DeleteAllLabels("ZigzagLabel_");
   CLabelManager::DeleteAllLabels("ZigzagLabel4H_"); // 添加删除4H周期标签
   
 
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
   
   // 计算当前周期ZigZag
   if(calculator != NULL)
     {
      calculator.Calculate(high, low, rates_total, prev_calculated);
      
      // 计算4H周期ZigZag
      if(calculator4H != NULL && InpShow4H)
        {
         // 使用CalculateForSymbol方法直接计算4H周期数据
         calculator4H.CalculateForSymbol(Symbol(), PERIOD_H4, 100);
         
         // 获取4H周期极值点
         CZigzagExtremumPoint points4H[];
         if(calculator4H.GetExtremumPoints(points4H))
           {
            // 打印4H周期峰谷值
            int maxPoints = MathMin(10, ArraySize(points4H));
            string h4Log = "4H周期峰谷值(最近" + IntegerToString(maxPoints) + "个):\n";
            
            for(int j = 0; j < maxPoints; j++)
              {
               h4Log += StringFormat("%s: 值=%s 时间=%s\n",
                  points4H[j].IsPeak() ? "峰" : "谷",
                  DoubleToString(points4H[j].Value(), _Digits),
                  TimeToString(points4H[j].Time()));
              }
            
            Print(h4Log);
            
            // 添加4小时周期的标签
            if(InpShowLabels)
              {
               for(int i = 0; i < ArraySize(points4H); i++)
                 {
                  string labelName = "ZigzagLabel4H_" + IntegerToString(i);
                  string labelText = StringFormat("4H: %s\n序号: %d",              
                     DoubleToString(points4H[i].Value(), _Digits),
                     points4H[i].BarIndex());
                  
                  // 使用4小时周期专用的标签颜色和标识
                  CLabelManager::CreateTextLabel(
                     labelName,
                     labelText,
                     points4H[i].Time(),
                     points4H[i].Value(),
                     points4H[i].IsPeak(),
                     true  // 标记为4H周期
                  );
                 }
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
            // 打印当前周期峰谷值
            int maxPoints = MathMin(10, ArraySize(points));
            string currentLog = "当前周期(" + EnumToString(Period()) + ")峰谷值:\n";
            
            for(int j = 0; j < maxPoints; j++)
              {
               currentLog += StringFormat("%s: 值=%s 时间=%s\n",
                  points[j].IsPeak() ? "峰" : "谷",
                  DoubleToString(points[j].Value(), _Digits),
                  TimeToString(points[j].Time()));
              }
            
            Print(currentLog);
            
            // 添加当前周期的标签
            for(int i = 0; i < ArraySize(points); i++)
              {
               string labelName = "ZigzagLabel_" + IntegerToString(i);
               string labelText = StringFormat("%s: %s\n序号: %d",
                  EnumToString(Period()),              
                  DoubleToString(points[i].Value(), _Digits),
                  points[i].BarIndex());
               
               CLabelManager::CreateTextLabel(
                  labelName,
                  labelText,
                  points[i].Time(),
                  points[i].Value(),
                  points[i].IsPeak(),
                  false  // 标记为当前周期
               );
              }
           }
        }
     }
   
   // 返回计算的柱数
   return(rates_total);
  }

//+------------------------------------------------------------------+