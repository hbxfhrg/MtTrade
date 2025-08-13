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
input bool InpShowLabels=true; // 显示峰谷值文本标签
input color InpLabelColor=clrWhite; // 标签文本颜色

//--- 声明ZigZag计算器指针
CZigzagCalculator *calculator = NULL;

//--- 不需要全局声明指标缓冲区，直接使用计算器对象的公开缓冲区

//+------------------------------------------------------------------+
//| 创建文本标签                                                     |
//+------------------------------------------------------------------+
void CreateTextLabel(string name, string text, datetime time, double price, bool isPeak)
  {
   // 删除可能存在的同名对象
   ObjectDelete(0, name);
   
   // 创建文本标签
   ObjectCreate(0, name, OBJ_TEXT, 0, time, price);
   
   // 设置标签属性
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_COLOR, InpLabelColor);
   
   // 设置标签位置（峰值点在上方，谷值点在下方）
   if(isPeak)
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
   else
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_TOP);
  }

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
     
   // 删除所有文本标签
   ObjectsDeleteAll(0, "ZigzagLabel_");
   
   // 注意：通常不建议在指标卸载时修改图表设置，因为用户可能已经手动更改了设置
   // 如果需要恢复网格和交易水平线显示设置，可以取消下面代码的注释
   // ChartSetInteger(0, CHART_SHOW_GRID, true);
   // ChartSetInteger(0, CHART_SHOW_TRADE_LEVELS, true);
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
      
      // 如果需要显示文本标签
      if(InpShowLabels)
        {
         // 清除旧标签
         if(prev_calculated == 0)
            ObjectsDeleteAll(0, "ZigzagLabel_");
            
         // 添加新标签
         for(int i = prev_calculated; i < rates_total; i++)
           {
            // 检查是否是峰值点
            if(calculator.ZigzagPeakBuffer[i] != 0)
              {
               string labelName = "ZigzagLabel_Peak_" + IntegerToString(i);
               CreateTextLabel(labelName, DoubleToString(calculator.ZigzagPeakBuffer[i], _Digits), time[i], calculator.ZigzagPeakBuffer[i], true);
              }
              
            // 检查是否是谷值点
            if(calculator.ZigzagBottomBuffer[i] != 0)
              {
               string labelName = "ZigzagLabel_Bottom_" + IntegerToString(i);
               CreateTextLabel(labelName, DoubleToString(calculator.ZigzagBottomBuffer[i], _Digits), time[i], calculator.ZigzagBottomBuffer[i], false);
              }
           }
        }
     }
   
   // 返回计算的柱数
   return(rates_total);
  }

//+------------------------------------------------------------------+