//+------------------------------------------------------------------+
//|                                   ZigzagExtremumPointIndicator.mq5 |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   1
#property indicator_type1   DRAW_COLOR_ZIGZAG
#property indicator_color1  clrDeepSkyBlue, clrCrimson
#property indicator_width1  2

// 引入ZigzagCalculator类
#include "ZigzagCalculator.mqh"

// 输入参数
input int InpDepth     = 12;  // 深度
input int InpDeviation = 5;   // 偏差
input int InpBackstep  = 3;   // 回溯步数

// 指标缓冲区
double ZigzagBuffer[];
double HighBuffer[];
double LowBuffer[];
double ColorBuffer[];

// 全局变量
CZigzagCalculator *zigzag = NULL;

//+------------------------------------------------------------------+
//| 自定义指标初始化函数                                               |
//+------------------------------------------------------------------+
int OnInit()
{
   // 设置缓冲区
   SetIndexBuffer(0, ZigzagBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, HighBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, LowBuffer, INDICATOR_CALCULATIONS);
   
   // 设置绘图属性
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_ZIGZAG);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 2);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, clrDeepSkyBlue);  // 峰值颜色
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, clrCrimson);      // 谷值颜色
   
   // 设置指标名称
   IndicatorSetString(INDICATOR_SHORTNAME, "ZigZag Extremum Points");
   
   // 创建ZigzagCalculator实例
   zigzag = new CZigzagCalculator(InpDepth, InpDeviation, InpBackstep);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| 自定义指标迭代函数                                                |
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
   // 检查数据点数量
   if(rates_total < 100)
      return(0);
      
   // 计算ZigZag值
   if(!zigzag.Calculate(high, low, rates_total, prev_calculated))
      return(0);
      
   // 获取ZigZag值
   double peaks[];
   double bottoms[];
   double colors[];
   
   if(!zigzag.GetZigzagValues(rates_total, peaks, bottoms, colors))
      return(0);
      
   // 填充指标缓冲区
   for(int i = 0; i < rates_total; i++)
   {
      ZigzagBuffer[i] = 0.0;
      ColorBuffer[i] = -1;
      
      if(peaks[i] != 0)
      {
         ZigzagBuffer[i] = peaks[i];
         ColorBuffer[i] = 0;  // 峰值颜色索引
      }
      else if(bottoms[i] != 0)
      {
         ZigzagBuffer[i] = bottoms[i];
         ColorBuffer[i] = 1;  // 谷值颜色索引
      }
   }
   
   // 在图表上标记极值点
   if(prev_calculated == 0)
   {
      // 获取极值点对象
      CZigzagExtremumPoint points[];
      
      if(zigzag.GetRecentExtremumPoints(points, 10))
      {
         // 删除之前的标记
         ObjectsDeleteAll(0, "ExtremumPoint_", -1, -1);
         
         // 显示极值点信息
         for(int i = 0; i < ArraySize(points); i++)
         {
            // 创建标签
            string label_name = StringFormat("ExtremumPoint_%d", i);
            
            // 使用买卖箭头对象
            ENUM_OBJECT obj_type = points[i].IsPeak() ? OBJ_ARROW_SELL : OBJ_ARROW_BUY;
            ObjectCreate(0, label_name, obj_type, 0, points[i].Time(), points[i].Value());
            
            // 设置颜色
            color bright_color = points[i].IsPeak() ? clrDeepSkyBlue : clrCrimson;
            ObjectSetInteger(0, label_name, OBJPROP_COLOR, bright_color);
            ObjectSetInteger(0, label_name, OBJPROP_WIDTH, 3);
            ObjectSetInteger(0, label_name, OBJPROP_ANCHOR, ANCHOR_CENTER);
            
            // 设置提示文本
            string tooltip = StringFormat("K线序号: %d\n时间: %s\n类型: %s\n价格: %s", 
                                        points[i].BarIndex(), 
                                        TimeToString(points[i].Time(), TIME_DATE|TIME_MINUTES),
                                        points[i].TypeAsString(),
                                        DoubleToString(points[i].Value(), _Digits));
            ObjectSetString(0, label_name, OBJPROP_TOOLTIP, tooltip);
         }
         
         // 强制刷新图表
         ChartRedraw();
      }
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| 自定义指标去初始化函数                                             |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // 删除所有标记
   ObjectsDeleteAll(0, "ExtremumPoint_", -1, -1);
   
   // 释放ZigzagCalculator实例
   if(zigzag != NULL)
   {
      delete zigzag;
      zigzag = NULL;
   }
}
//+------------------------------------------------------------------+