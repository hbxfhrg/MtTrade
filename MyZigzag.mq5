//+------------------------------------------------------------------+
//|                                                  ZigzagColor.mq5 |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
//--- 包含文件
#include "ZigzagCalculator.mqh"

//--- 指标设置
#property indicator_chart_window
#property indicator_buffers 8  // 增加到8个缓冲区，包括3个对比缓冲区
#property indicator_plots   1
#property indicator_type1   DRAW_COLOR_ZIGZAG
#property indicator_color1  clrDodgerBlue,clrRed
//--- 输入参数
input int InpDepth    =12;  // 深度
input int InpDeviation=5;   // 偏差
input int InpBackstep =3;   // 回溯步数
//--- 指标缓冲区
double ZigzagPeakBuffer[];
double ZigzagBottomBuffer[];
double HighMapBuffer[];
double LowMapBuffer[];
double ColorBuffer[];

//--- 对比测试用缓冲区
double ComparePeakBuffer[];
double CompareBottomBuffer[];
double CompareColorBuffer[];

int ExtRecalc=3; // 重新计算的深度

enum EnSearchMode
  {
   Extremum=0, // 搜索第一个极值点
   Peak=1,     // 搜索下一个ZigZag峰值
   Bottom=-1   // 搜索下一个ZigZag谷值
  };
//+------------------------------------------------------------------+
//| 自定义指标初始化函数                                             |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- 指标缓冲区 mapping
   SetIndexBuffer(0,ZigzagPeakBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,ZigzagBottomBuffer,INDICATOR_DATA);
   SetIndexBuffer(2,ColorBuffer,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(3,HighMapBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(4,LowMapBuffer,INDICATOR_CALCULATIONS);
   
   // 对比测试用缓冲区
   SetIndexBuffer(5,ComparePeakBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(6,CompareBottomBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(7,CompareColorBuffer,INDICATOR_CALCULATIONS);
   
//--- 设置精度
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
//--- DataWindow和指标子窗口标签的名称
   string short_name=StringFormat("ZigZagColor(%d,%d,%d)",InpDepth,InpDeviation,InpBackstep);
   IndicatorSetString(INDICATOR_SHORTNAME,short_name);
   PlotIndexSetString(0,PLOT_LABEL,short_name);
//--- 设置空值
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0.0);
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
   if(rates_total<100)
      return(0);
      
   // 使用ZigzagCalculator类计算
   static CZigzagCalculator calculator(InpDepth, InpDeviation, InpBackstep);
   calculator.Calculate(high, low, rates_total, prev_calculated);
   
   // 获取计算结果
   double calc_peaks[], calc_bottoms[], calc_colors[];
   calculator.GetZigzagValues(rates_total, calc_peaks, calc_bottoms, calc_colors);
   
   // 复制到对比缓冲区
   ArrayCopy(ComparePeakBuffer, calc_peaks);
   ArrayCopy(CompareBottomBuffer, calc_bottoms);
   ArrayCopy(CompareColorBuffer, calc_colors);
   
//---
   int    i,start=0;
   int    extreme_counter=0,extreme_search=Extremum;
   int    shift,back=0,last_high_pos=0,last_low_pos=0;
   double val=0,res=0;
   double cur_low=0,cur_high=0,last_high=0,last_low=0;
//--- 初始化
   if(prev_calculated==0)
     {
      ArrayInitialize(ZigzagPeakBuffer,0.0);
      ArrayInitialize(ZigzagBottomBuffer,0.0);
      ArrayInitialize(HighMapBuffer,0.0);
      ArrayInitialize(LowMapBuffer,0.0);
      //--- start calculation from bar number InpDepth
      start=InpDepth-1;
     }
//--- ZigZag之前已经计算过
   if(prev_calculated>0)
     {
      i=rates_total-1;
      //--- 从最后一个未完成的柱开始搜索第三个极值点
      while(extreme_counter<ExtRecalc && i>rates_total -100)
        {
         res=(ZigzagPeakBuffer[i]+ZigzagBottomBuffer[i]);
         //---
         if(res!=0)
            extreme_counter++;
         i--;
        }
      i++;
      start=i;
      //--- 搜索哪种类型的极值点
      if(LowMapBuffer[i]!=0)
        {
         cur_low=LowMapBuffer[i];
         extreme_search=Peak;
        }
      else
        {
         cur_high=HighMapBuffer[i];
         extreme_search=Bottom;
        }
      //--- 清除指标值
      for(i=start+1; i<rates_total && !IsStopped(); i++)
        {
         ZigzagPeakBuffer[i]  =0.0;
         ZigzagBottomBuffer[i]=0.0;
         LowMapBuffer[i]      =0.0;
         HighMapBuffer[i]     =0.0;
        }
     }
//--- 搜索高点和低点极值
   for(shift=start; shift<rates_total && !IsStopped(); shift++)
     {
      //--- 低点
      val=Lowest(low,InpDepth,shift);
      if(val==last_low)
         val=0.0;
      else
        {
         last_low=val;
         if((low[shift]-val)>(InpDeviation*_Point))
            val=0.0;
         else
           {
            for(back=InpBackstep; back>=1; back--)
              {
               res=LowMapBuffer[shift-back];
               //---
               if((res!=0) && (res>val))
                  LowMapBuffer[shift-back]=0.0;
              }
           }
        }
      if(low[shift]==val)
         LowMapBuffer[shift]=val;
      else
         LowMapBuffer[shift]=0.0;
      //--- 高点
      val=Highest(high,InpDepth,shift);
      if(val==last_high)
         val=0.0;
      else
        {
         last_high=val;
         if((val-high[shift])>(InpDeviation*_Point))
            val=0.0;
         else
           {
            for(back=InpBackstep; back>=1; back--)
              {
               res=HighMapBuffer[shift-back];
               //---
               if((res!=0) && (res<val))
                  HighMapBuffer[shift-back]=0.0;
              }
           }
        }
      if(high[shift]==val)
         HighMapBuffer[shift]=val;
      else
         HighMapBuffer[shift]=0.0;
     }
//--- 设置最后的值
   if(extreme_search==0) // undefined values
     {
      last_low=0;
      last_high=0;
     }
   else
     {
      last_low=cur_low;
      last_high=cur_high;
     }
//--- 最终选择ZigZag极值点
   for(shift=start; shift<rates_total && !IsStopped(); shift++)
     {
      res=0.0;
      switch(extreme_search)
        {
         case Extremum:
            if(last_low==0 && last_high==0)
              {
               if(HighMapBuffer[shift]!=0)
                 {
                  last_high=high[shift];
                  last_high_pos=shift;
                  extreme_search=-1;
                  ZigzagPeakBuffer[shift]=last_high;
                  ColorBuffer[shift]=0;
                  res=1;
                 }
               if(LowMapBuffer[shift]!=0)
                 {
                  last_low=low[shift];
                  last_low_pos=shift;
                  extreme_search=1;
                  ZigzagBottomBuffer[shift]=last_low;
                  ColorBuffer[shift]=1;
                  res=1;
                 }
              }
            break;
         case Peak:
            if(LowMapBuffer[shift]!=0.0 && LowMapBuffer[shift]<last_low &&
               HighMapBuffer[shift]==0.0)
              {
               ZigzagBottomBuffer[last_low_pos]=0.0;
               last_low_pos=shift;
               last_low=LowMapBuffer[shift];
               ZigzagBottomBuffer[shift]=last_low;
               ColorBuffer[shift]=1;
               res=1;
              }
            if(HighMapBuffer[shift]!=0.0 && LowMapBuffer[shift]==0.0)
              {
               last_high=HighMapBuffer[shift];
               last_high_pos=shift;
               ZigzagPeakBuffer[shift]=last_high;
               ColorBuffer[shift]=0;
               extreme_search=Bottom;
               res=1;
              }
            break;
         case Bottom:
            if(HighMapBuffer[shift]!=0.0 &&
               HighMapBuffer[shift]>last_high &&
               LowMapBuffer[shift]==0.0)
              {
               ZigzagPeakBuffer[last_high_pos]=0.0;
               last_high_pos=shift;
               last_high=HighMapBuffer[shift];
               ZigzagPeakBuffer[shift]=last_high;
               ColorBuffer[shift]=0;
              }
            if(LowMapBuffer[shift]!=0.0 && HighMapBuffer[shift]==0.0)
              {
               last_low=LowMapBuffer[shift];
               last_low_pos=shift;
               ZigzagBottomBuffer[shift]=last_low;
               ColorBuffer[shift]=1;
               extreme_search=Peak;
              }
            break;
         default:
            return(rates_total);
        }
     }

   // 对比两种方法的计算结果
   int differences = 0;
   int peak_diff = 0, bottom_diff = 0, color_diff = 0;
   
   // 使用更精确的浮点数比较
   double epsilon = 1e-10; // 极小的误差容忍度
   
   for(int i = 0; i < rates_total; i++)
   {
      bool peak_different = MathAbs(ZigzagPeakBuffer[i] - ComparePeakBuffer[i]) > epsilon;
      bool bottom_different = MathAbs(ZigzagBottomBuffer[i] - CompareBottomBuffer[i]) > epsilon;
      bool color_different = MathAbs(ColorBuffer[i] - CompareColorBuffer[i]) > epsilon;
      
      if(peak_different || bottom_different || color_different)
      {
         differences++;
         
         // 统计各类型差异
         if(peak_different) peak_diff++;
         if(bottom_different) bottom_diff++;
         if(color_different) color_diff++;
         
         // 只打印前10个差异，并且只打印真正有差异的值
         if(differences <= 10)
         {
            string diff_type = "";
            if(peak_different) diff_type += "峰值 ";
            if(bottom_different) diff_type += "谷值 ";
            if(color_different) diff_type += "颜色 ";
            
            PrintFormat("差异在柱 %d [%s]: 原方法(%.10f, %.10f, %.1f) vs 类方法(%.10f, %.10f, %.1f)",
                        i,
                        diff_type,
                        ZigzagPeakBuffer[i], ZigzagBottomBuffer[i], ColorBuffer[i],
                        ComparePeakBuffer[i], CompareBottomBuffer[i], CompareColorBuffer[i]);
                        
            // 如果值看起来相同但被检测为不同，显示二进制表示
            if((peak_different && ZigzagPeakBuffer[i] == 0 && ComparePeakBuffer[i] == 0) ||
               (bottom_different && ZigzagBottomBuffer[i] == 0 && CompareBottomBuffer[i] == 0) ||
               (color_different && ColorBuffer[i] == 0 && CompareColorBuffer[i] == 0))
            {
               PrintFormat("警告：零值比较差异 - 可能是符号位或NaN问题");
               
               // 检查是否为负零或NaN
               if(peak_different && ZigzagPeakBuffer[i] == 0 && ComparePeakBuffer[i] == 0)
               {
                  bool is_neg1 = MathIsValidNumber(ZigzagPeakBuffer[i]) ? false : true;
                  bool is_neg2 = MathIsValidNumber(ComparePeakBuffer[i]) ? false : true;
                  PrintFormat("峰值检查: 原方法(%s) vs 类方法(%s)", 
                             is_neg1 ? "无效数" : "有效数", 
                             is_neg2 ? "无效数" : "有效数");
               }
            }
         }
      }
   }
   
   if(differences > 0)
   {
      PrintFormat("发现 %d 处差异 (峰值:%d, 谷值:%d, 颜色:%d)，请检查计算逻辑", 
                 differences, peak_diff, bottom_diff, color_diff);
                 
      // 检查数组大小是否一致
      PrintFormat("数组大小检查 - 原方法: %d, %d, %d vs 类方法: %d, %d, %d",
                 ArraySize(ZigzagPeakBuffer), ArraySize(ZigzagBottomBuffer), ArraySize(ColorBuffer),
                 ArraySize(ComparePeakBuffer), ArraySize(CompareBottomBuffer), ArraySize(CompareColorBuffer));
                 
      // 检查第一个非零值的位置
      int first_nonzero_orig = -1, first_nonzero_comp = -1;
      for(int i = 0; i < rates_total; i++)
      {
         if(first_nonzero_orig == -1 && (ZigzagPeakBuffer[i] != 0 || ZigzagBottomBuffer[i] != 0))
            first_nonzero_orig = i;
            
         if(first_nonzero_comp == -1 && (ComparePeakBuffer[i] != 0 || CompareBottomBuffer[i] != 0))
            first_nonzero_comp = i;
            
         if(first_nonzero_orig != -1 && first_nonzero_comp != -1)
            break;
      }
      
      PrintFormat("第一个非零值位置 - 原方法: %d, 类方法: %d", first_nonzero_orig, first_nonzero_comp);
   }
   else
   {
      Print("两种方法计算结果完全一致");
   }

//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
//| 获取范围内的最高值                                              |
//+------------------------------------------------------------------+
double Highest(const double&array[],int count,int start)
  {
   double res=array[start];
//---
   for(int i=start-1; i>start-count && i>=0; i--)
      if(res<array[i])
         res=array[i];
//---
   return(res);
  }
//+------------------------------------------------------------------+
//| 获取范围内的最低值                                              |
//+------------------------------------------------------------------+
double Lowest(const double&array[],int count,int start)
  {
   double res=array[start];
//---
   for(int i=start-1; i>start-count && i>=0; i--)
      if(res>array[i])
         res=array[i];
//---
   return(res);
  }
//+------------------------------------------------------------------+
