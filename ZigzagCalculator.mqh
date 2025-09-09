//+------------------------------------------------------------------+
//|                                               ZigzagCalculator.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

// 错误代码定义
#define ERR_UNKNOWN_SYMBOL 4006
#define ERR_SERIES_NOT_AVAILABLE 4016

//+------------------------------------------------------------------+
//| 数组顺序约定:                                                      |
//| 所有数组(rates, high, low, time等)都按照从最近到最远的顺序排列      |
//| 序号0对应最新的数据，序号越大表示数据越旧                           |
//+------------------------------------------------------------------+

// 引入极值点类定义
#include "ZigzagExtremumPoint.mqh"

//+------------------------------------------------------------------+
//| ZigzagCalculator类用于计算ZigZag指标的极值                        |
//+------------------------------------------------------------------+
class CZigzagCalculator
  {
private:
   // 参数
   int               m_depth;       // 深度参数
   int               m_deviation;   // 偏差参数
   int               m_backstep;    // 回溯步数参数
   ENUM_TIMEFRAMES   timeframe;   // 时间周期
   
   
public:
   // 公开缓冲区
   double            ZigzagPeakBuffer[];     // 峰值缓冲区
   double            ZigzagBottomBuffer[];   // 谷值缓冲区
   double            ColorBuffer[];          // 颜色缓冲区
   double            HighMapBuffer[];        // 高点映射缓冲区
   double            LowMapBuffer[];         // 低点映射缓冲区
   
public:
   // 获取单个缓冲区元素
   double            GetZigzagPeakValue(int index)     { return ZigzagPeakBuffer[index]; }
   double            GetZigzagBottomValue(int index)   { return ZigzagBottomBuffer[index]; }
   double            GetColorValue(int index)          { return ColorBuffer[index]; }
   
   
   // 设置缓冲区元素
   void              SetZigzagPeakValue(int index, double value)     { ZigzagPeakBuffer[index] = value; }
   void              SetZigzagBottomValue(int index, double value)   { ZigzagBottomBuffer[index] = value; }
   void              SetColorValue(int index, double value)          { ColorBuffer[index] = value; }
   
   // 获取缓冲区大小
   int               GetBufferSize() { return ArraySize(ZigzagPeakBuffer); }
   
   // 内部状态
   int               m_recalcDepth;          // 重新计算的深度
   
   // 搜索模式枚举
   enum EnSearchMode
     {
      Extremum=0, // 搜索第一个极值
      Peak=1,     // 搜索下一个ZigZag峰值
      Bottom=-1   // 搜索下一个ZigZag谷值
     };
   
   // 辅助函数
   double            Highest(const double &array[], int count, int start);
   double            Lowest(const double &array[], int count, int start);
   
public:
                     CZigzagCalculator(int depth, int deviation, int backstep, int recalcDepth=3, ENUM_TIMEFRAMES timeframe=PERIOD_CURRENT);
                    ~CZigzagCalculator();
   
   // 计算ZigZag值
   bool              Calculate(const double &high[], const double &low[], int rates_total, int prev_calculated);
   
   // 获取计算结果
   bool              GetZigzagValues(int bars_count, double &peaks[], double &bottoms[], double &colors[]);
   
   // 从指定时间周期获取ZigZag值
   bool              GetZigzagValuesForTimeframe(string symbol, ENUM_TIMEFRAMES timeframe, int bars_count, double &peaks[], double &bottoms[], double &colors[]);
   
   // 直接为指定品种和时间周期计算ZigZag值
   bool              CalculateForSymbol(const string symbol, ENUM_TIMEFRAMES timeframe, int bars_count);
   
   // 为当前图表计算ZigZag值
   bool              CalculateForCurrentChart(int bars_count);
   
   // 获取极值点对象数组
   bool              GetExtremumPoints(SZigzagExtremumPoint &points[], int max_count = 0);
   
   // 获取最近的N个极值点
   bool              GetRecentExtremumPoints(SZigzagExtremumPoint &points[], int count);
   
   // 获取/设置参数
   void              SetParameters(int depth, int deviation, int backstep, ENUM_TIMEFRAMES timeframe=PERIOD_CURRENT);
   int               GetDepth() const { return m_depth; }
   int               GetDeviation() const { return m_deviation; }

  };



//+------------------------------------------------------------------+
//| 构造函数                                                          |
//+------------------------------------------------------------------+
CZigzagCalculator::CZigzagCalculator(int depth, int deviation, int backstep, int recalcDepth, ENUM_TIMEFRAMES tf)
  {
   m_depth = depth;
   m_deviation = deviation;
   m_backstep = backstep;
   timeframe = tf;
   m_recalcDepth = recalcDepth; // 设置重新计算深度
  }

//+------------------------------------------------------------------+
//| 析构函数                                                          |
//+------------------------------------------------------------------+
CZigzagCalculator::~CZigzagCalculator()
  {
   // 清理资源
  }

//+------------------------------------------------------------------+
//| 设置参数                                                          |
//+------------------------------------------------------------------+
void CZigzagCalculator::SetParameters(int depth, int deviation, int backstep, ENUM_TIMEFRAMES tf_param)
  {
   m_depth = depth;
   m_deviation = deviation;
   m_backstep = backstep;
   timeframe = tf_param;
  }

//+------------------------------------------------------------------+
//| 获取最高值                                                        |
//+------------------------------------------------------------------+
double CZigzagCalculator::Highest(const double &array[], int count, int start)
  {
   double res = array[start];
   
   for(int i = start - 1; i > start - count && i >= 0; i--)
      if(res < array[i])
         res = array[i];
         
   return res;
  }

//+------------------------------------------------------------------+
//| 获取最低值                                                        |
//+------------------------------------------------------------------+
double CZigzagCalculator::Lowest(const double &array[], int count, int start)
  {
   double res = array[start];
   
   for(int i = start - 1; i > start - count && i >= 0; i--)
      if(res > array[i])
         res = array[i];
         
   return res;
  }

//+------------------------------------------------------------------+
//| 计算ZigZag值                                                      |
//+------------------------------------------------------------------+
bool CZigzagCalculator::Calculate(const double &high[], const double &low[], int rates_total, int prev_calculated)
  {
   if(rates_total < 100)
      return false;
      
   // 调整缓冲区大小
   ArrayResize(ZigzagPeakBuffer, rates_total);
   ArrayResize(ZigzagBottomBuffer, rates_total);
   ArrayResize(HighMapBuffer, rates_total);
   ArrayResize(LowMapBuffer, rates_total);
   ArrayResize(ColorBuffer, rates_total);
   
   int    i, start = 0;
   int    extreme_counter = 0, extreme_search = Extremum;
   int    shift, back = 0, last_high_pos = 0, last_low_pos = 0;
   double val = 0, res = 0;
   double cur_low = 0, cur_high = 0, last_high = 0, last_low = 0;
   
   // 初始化
   if(prev_calculated == 0)
     {
      ArrayInitialize(ZigzagPeakBuffer, 0.0);
      ArrayInitialize(ZigzagBottomBuffer, 0.0);
      ArrayInitialize(HighMapBuffer, 0.0);
      ArrayInitialize(LowMapBuffer, 0.0);
      ArrayInitialize(ColorBuffer, 0.0);
      
      // 从深度参数开始计算
      start = m_depth - 1;
     }
   
   // ZigZag已经计算过
   if(prev_calculated > 0)
     {
      i = rates_total - 1;
      
      // 从最后一个未完成的柱子开始搜索第三个极值
      while(extreme_counter < m_recalcDepth && i > rates_total - 100)
        {
         res = (ZigzagPeakBuffer[i] + ZigzagBottomBuffer[i]);
         
         if(res != 0)
            extreme_counter++;
            
         i--;
        }
        
      i++;
      start = i;
      
      // 确定我们要搜索的极值类型
      if(LowMapBuffer[i] != 0)
        {
         cur_low = LowMapBuffer[i];
         extreme_search = Peak;
        }
      else
        {
         cur_high = HighMapBuffer[i];
         extreme_search = Bottom;
        }
        
      // 清除指标值
      for(i = start + 1; i < rates_total && !IsStopped(); i++)
        {
         ZigzagPeakBuffer[i] = 0.0;
         ZigzagBottomBuffer[i] = 0.0;
         LowMapBuffer[i] = 0.0;
         HighMapBuffer[i] = 0.0;
        }
     }
     
   // 搜索高低极值
   for(shift = start; shift < rates_total && !IsStopped(); shift++)
     {
      // 低点
      val = Lowest(low, m_depth, shift);
      if(val == last_low)
         val = 0.0;
      else
        {
         last_low = val;
         if((low[shift] - val) > (m_deviation * _Point))
            val = 0.0;
         else
           {
            for(back = m_backstep; back >= 1; back--)
              {
               res = LowMapBuffer[shift - back];
               
               if((res != 0) && (res > val))
                  LowMapBuffer[shift - back] = 0.0;
              }
           }
        }
        
      if(low[shift] == val)
         LowMapBuffer[shift] = val;
      else
         LowMapBuffer[shift] = 0.0;
         
      // 高点
      val = Highest(high, m_depth, shift);
      if(val == last_high)
         val = 0.0;
      else
        {
         last_high = val;
         if((val - high[shift]) > (m_deviation * _Point))
            val = 0.0;
         else
           {
            for(back = m_backstep; back >= 1; back--)
              {
               res = HighMapBuffer[shift - back];
               
               if((res != 0) && (res < val))
                  HighMapBuffer[shift - back] = 0.0;
              }
           }
        }
        
      if(high[shift] == val)
         HighMapBuffer[shift] = val;
      else
         HighMapBuffer[shift] = 0.0;
     }
     
   // 设置最后的值
   if(extreme_search == 0) // 未定义的值
     {
      last_low = 0;
      last_high = 0;
     }
   else
     {
      last_low = cur_low;
      last_high = cur_high;
     }
     
   // ZigZag的极值点的最终选择
   for(shift = start; shift < rates_total && !IsStopped(); shift++)
     {
      res = 0.0;
      switch(extreme_search)
        {
         case Extremum:
            if(last_low == 0 && last_high == 0)
              {
               if(HighMapBuffer[shift] != 0)
                 {
                  last_high = high[shift];
                  last_high_pos = shift;
                  extreme_search = Bottom;
                  ZigzagPeakBuffer[shift] = last_high;
                  ColorBuffer[shift] = 0;
                  res = 1;
                 }
                 
               if(LowMapBuffer[shift] != 0)
                 {
                  last_low = low[shift];
                  last_low_pos = shift;
                  extreme_search = Peak;
                  ZigzagBottomBuffer[shift] = last_low;
                  ColorBuffer[shift] = 1;
                  res = 1;
                 }
              }
            break;
            
         case Peak:
            if(LowMapBuffer[shift] != 0.0 && LowMapBuffer[shift] < last_low &&
               HighMapBuffer[shift] == 0.0)
              {
               ZigzagBottomBuffer[last_low_pos] = 0.0;
               last_low_pos = shift;
               last_low = LowMapBuffer[shift];
               ZigzagBottomBuffer[shift] = last_low;
               ColorBuffer[shift] = 1;
               res = 1;
              }
              
            if(HighMapBuffer[shift] != 0.0 && LowMapBuffer[shift] == 0.0)
              {
               last_high = HighMapBuffer[shift];
               last_high_pos = shift;
               ZigzagPeakBuffer[shift] = last_high;
               ColorBuffer[shift] = 0;
               extreme_search = Bottom;
               res = 1;
              }
            break;
            
         case Bottom:
            if(HighMapBuffer[shift] != 0.0 &&
               HighMapBuffer[shift] > last_high &&
               LowMapBuffer[shift] == 0.0)
              {
               ZigzagPeakBuffer[last_high_pos] = 0.0;
               last_high_pos = shift;
               last_high = HighMapBuffer[shift];
               ZigzagPeakBuffer[shift] = last_high;
               ColorBuffer[shift] = 0;
              }
              
            if(LowMapBuffer[shift] != 0.0 && HighMapBuffer[shift] == 0.0)
              {
               last_low = LowMapBuffer[shift];
               last_low_pos = shift;
               ZigzagBottomBuffer[shift] = last_low;
               ColorBuffer[shift] = 1;
               extreme_search = Peak;
              }
            break;
            
         default:
            return false;
        }
     }

   return true;
  }



//+------------------------------------------------------------------+
//| 从指定时间周期获取ZigZag值                                         |
//+------------------------------------------------------------------+
bool CZigzagCalculator::GetZigzagValuesForTimeframe(string symbol, ENUM_TIMEFRAMES atimeframe, int bars_count, double &peaks[], double &bottoms[], double &colors[])
  {
   // 检查参数
   if(bars_count <= 0)
      return false;
      
   // 计算复制数量
   // CopyRates参数说明：start_pos=0表示最新K线，count表示要获取的K线数量
   int copy_count = bars_count + m_depth;
   int start_pos = 0;  // 从最新K线开始获取
      
   // 获取历史数据
   MqlRates rates[];
   if(CopyRates(symbol, atimeframe, start_pos, copy_count, rates) <= 0)
     {
      return false;
     }
     
   // 提取高点和低点数据
   double high[];
   double low[];
   ArrayResize(high, ArraySize(rates));
   ArrayResize(low, ArraySize(rates));
   
   for(int i = 0; i < ArraySize(rates); i++)
     {
      high[i] = rates[i].high;
      low[i] = rates[i].low;
     }
     
   // 计算ZigZag值
   if(!Calculate(high, low, ArraySize(high), 0))
     {
      Print("计算ZigZag值失败");
      return false;
     }
     
   // 获取计算结果
   return GetZigzagValues(bars_count, peaks, bottoms, colors);
  }

//+------------------------------------------------------------------+
//| 为指定品种和时间周期直接计算ZigZag值                              |
//+------------------------------------------------------------------+
bool CZigzagCalculator::CalculateForSymbol(const string symbol, ENUM_TIMEFRAMES atimeframe, int bars_count)
  {
   // 检查参数
   if(bars_count <= 0)
      return false;
   
   // 计算复制数量
   // CopyRates参数说明：start_pos=0表示最新K线，count表示要获取的K线数量
   int copy_count = bars_count + m_depth;
   int start_pos = 0;  // 从最新K线开始获取
   
   // 获取历史数据
   MqlRates rates[];
   if(CopyRates(symbol, atimeframe, start_pos, copy_count, rates) <= 0)
     {
      return false;
     }
   
   int copied = ArraySize(rates);
   
   // 提取高点和低点数据
   double high[], low[];
   ArrayResize(high, copied);
   ArrayResize(low, copied);
   
   for(int i = 0; i < copied; i++)
     {
      high[i] = rates[i].high;
      low[i] = rates[i].low;
     }
   
   // 计算ZigZag值
   return Calculate(high, low, copied, 0);
  }

//+------------------------------------------------------------------+
//| 为当前图表计算ZigZag值                                           |
//+------------------------------------------------------------------+
bool CZigzagCalculator::CalculateForCurrentChart(int bars_count)
  {
   // 获取当前图表的符号和时间周期
   string symbol = Symbol();
   ENUM_TIMEFRAMES current_tf = (timeframe == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : timeframe;
   
   // 调用CalculateForSymbol方法
   return CalculateForSymbol(symbol, current_tf, bars_count);
  }

//+------------------------------------------------------------------+
//| 获取极值点对象数组                                                |
//+------------------------------------------------------------------+
bool CZigzagCalculator::GetExtremumPoints(SZigzagExtremumPoint &points[], int max_count/* = 0*/)
  {
   // 检查缓冲区是否已初始化
   int size = ArraySize(ZigzagPeakBuffer);
   int bottom_size = ArraySize(ZigzagBottomBuffer);
   if(size == 0 || bottom_size == 0)
      return false;
      
   // 确保两个缓冲区大小一致
   if(size != bottom_size)
     {
      Print("错误：ZigZag缓冲区大小不一致: Peak=", size, ", Bottom=", bottom_size);
      size = MathMin(size, bottom_size); // 使用较小的尺寸
     }
   
   // 获取时间数组 - 确保与计算的ZigZag数据顺序一致
   datetime time_array[];
   int copied;
   
   // 根据时间周期获取相应的时间数据，使用与CalculateForSymbol相同的参数
   string symbol;
   ENUM_TIMEFRAMES current_tf = timeframe;
   
   if(current_tf == PERIOD_CURRENT)
     {
      // 当前周期，直接使用当前图表的时间
      symbol = Symbol();
      current_tf = (ENUM_TIMEFRAMES)Period();
     }
   else
     {
      // 指定周期，使用指定周期的时间
      symbol = Symbol();
      // current_tf保持不变
     }
   
   // 使用与CalculateForSymbol相同的参数
   int copy_count = size + m_depth;
   int start_pos = 0;  // 从最新K线开始获取
   
   copied = CopyTime(symbol, current_tf, start_pos, copy_count, time_array);
   
   if(copied <= 0)
     {
      return false;
     }
   
   // 确保时间数组大小不超过缓冲区大小
   int valid_size = MathMin(size, copied);
   
   // 计算时间数组偏移量
   // ZigZag缓冲区是基于最新的size个K线计算的
   // 而时间数组可能包含更多的时间点
   // 所以需要计算偏移量，确保ZigZag缓冲区索引0对应正确的时间
   int time_offset = copied - size;  // 时间数组中多出的元素数量
   if(time_offset < 0) time_offset = 0;
   
   // 临时数组存储所有极值点
   SZigzagExtremumPoint temp_points[];
   int temp_count = 0;
   
   // 收集所有极值点 - 使用valid_size防止越界
   for(int i = 0; i < valid_size; i++)
     {
      // 额外检查：确保i不会超出任何数组的边界
      if(i >= ArraySize(ZigzagPeakBuffer) || i >= ArraySize(ZigzagBottomBuffer) || i >= ArraySize(time_array))
         break;
         
      // 使用偏移量来计算正确的时间索引
      // ZigZag缓冲区索引i对应time_array[time_offset + i]
      int time_index = time_offset + i;
      
      // 确保时间索引在有效范围内
      if(time_index < 0 || time_index >= ArraySize(time_array))
         continue;
         
      if(ZigzagPeakBuffer[i] != 0)
        {
         ArrayResize(temp_points, temp_count + 1);
         InitZigzagExtremumPoint(temp_points[temp_count],
            timeframe,
            time_array[time_index], // 使用调整后的时间索引
            i,
            ZigzagPeakBuffer[i],
            EXTREMUM_PEAK
         );
         
         temp_count++;
        }
      else if(ZigzagBottomBuffer[i] != 0)
        {
         ArrayResize(temp_points, temp_count + 1);
         InitZigzagExtremumPoint(temp_points[temp_count],
            timeframe,
            time_array[time_index], // 使用调整后的时间索引
            i,
            ZigzagBottomBuffer[i],
            EXTREMUM_BOTTOM
         );
         
         temp_count++;
        }
     }
   
   // 过滤无效点（相邻的相同类型的极值点）
   SZigzagExtremumPoint filtered_points[];
   int filtered_count = 0;
   
   for(int i = 0; i < temp_count; i++)
     {
      // 第一个点直接添加
      if(i == 0)
        {
         ArrayResize(filtered_points, filtered_count + 1);
         ArrayResize(filtered_points, filtered_count + 1);
         InitZigzagExtremumPoint(filtered_points[filtered_count], temp_points[i].timeframe, temp_points[i].time, temp_points[i].bar_index, temp_points[i].value, temp_points[i].type);
         filtered_count++;
         continue;
        }
        
      // 检查当前点与前一个点的类型是否相同
      if(temp_points[i].type != temp_points[i-1].type)
        {
         ArrayResize(filtered_points, filtered_count + 1);
         filtered_points[filtered_count] = temp_points[i];
         filtered_count++;
        }
     }
   
   // 如果指定了最大数量，则限制返回的点数
   if(max_count > 0 && max_count < filtered_count)
      filtered_count = max_count;
      
   // 调整输出数组大小
   ArrayResize(points, filtered_count);
   
   // 按时间排序（从最新到最旧）
   for(int i = 0; i < filtered_count - 1; i++)
     {
      for(int j = i + 1; j < filtered_count; j++)
        {
         if(filtered_points[i].time < filtered_points[j].time)
           {
            SZigzagExtremumPoint temp;
            InitZigzagExtremumPoint(temp, filtered_points[i].timeframe, filtered_points[i].time, filtered_points[i].bar_index, filtered_points[i].value, filtered_points[i].type);
            InitZigzagExtremumPoint(filtered_points[i], filtered_points[j].timeframe, filtered_points[j].time, filtered_points[j].bar_index, filtered_points[j].value, filtered_points[j].type);
            InitZigzagExtremumPoint(filtered_points[j], temp.timeframe, temp.time, temp.bar_index, temp.value, temp.type);
           }
        }
     }
   
   // 复制排序后的结果
   for(int i = 0; i < filtered_count; i++)
     {
      InitZigzagExtremumPoint(points[i], filtered_points[i].timeframe, filtered_points[i].time, filtered_points[i].bar_index, filtered_points[i].value, filtered_points[i].type);
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| 获取最近的N个极值点                                               |
//+------------------------------------------------------------------+
bool CZigzagCalculator::GetRecentExtremumPoints(SZigzagExtremumPoint &points[], int count)
  {
   if(count <= 0)
      return false;
      
   // 获取所有极值点（已经按时间排序，最新的在前面）
   SZigzagExtremumPoint all_points[];
   if(!GetExtremumPoints(all_points))
      return false;
      
   // 确定要返回的点数
   int total_points = ArraySize(all_points);
   int return_count = MathMin(count, total_points);
   
   // 调整输出数组大小
   ArrayResize(points, return_count);
   
   // 复制最近的N个点（由于GetExtremumPoints已经排序，直接取前N个即可）
   for(int i = 0; i < return_count; i++)
     {
      InitZigzagExtremumPoint(points[i], all_points[i].timeframe, all_points[i].time, all_points[i].bar_index, all_points[i].value, all_points[i].type);
     }
   
   return true;
  }
//+------------------------------------------------------------------+