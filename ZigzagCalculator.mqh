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
   ENUM_TIMEFRAMES   m_timeframe;   // 时间周期
   
   // 缓冲区
   double            m_zigzagPeakBuffer[];   // 峰值缓冲区
   double            m_zigzagBottomBuffer[]; // 谷值缓冲区
   double            m_highMapBuffer[];      // 高点映射缓冲区
   double            m_lowMapBuffer[];       // 低点映射缓冲区
   double            m_colorBuffer[];        // 颜色缓冲区
   
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
   
   // 添加最近的极值点
   void              AddLatestExtremum(double &peaks[], double &bottoms[], double &colors[], 
                                      const double &high[], const double &low[], int size);
   
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
   bool              GetExtremumPoints(CZigzagExtremumPoint &points[], int max_count = 0);
   
   // 获取最近的N个极值点
   bool              GetRecentExtremumPoints(CZigzagExtremumPoint &points[], int count);
   
   // 获取/设置参数
   void              SetParameters(int depth, int deviation, int backstep, ENUM_TIMEFRAMES timeframe=PERIOD_CURRENT);
   int               GetDepth() const { return m_depth; }
   int               GetDeviation() const { return m_deviation; }
   int               GetBackstep() const { return m_backstep; }
   ENUM_TIMEFRAMES   GetTimeframe() const { return m_timeframe; }
  };

//+------------------------------------------------------------------+
//| 构造函数                                                          |
//+------------------------------------------------------------------+
CZigzagCalculator::CZigzagCalculator(int depth, int deviation, int backstep, int recalcDepth, ENUM_TIMEFRAMES timeframe)
  {
   m_depth = depth;
   m_deviation = deviation;
   m_backstep = backstep;
   m_timeframe = timeframe;
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
void CZigzagCalculator::SetParameters(int depth, int deviation, int backstep, ENUM_TIMEFRAMES timeframe)
  {
   m_depth = depth;
   m_deviation = deviation;
   m_backstep = backstep;
   m_timeframe = timeframe;
   // 保持m_recalcDepth不变
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
   Print("===== 开始计算ZigZag值 =====");
   Print("参数: rates_total=", rates_total, ", prev_calculated=", prev_calculated);
   Print("参数: m_depth=", m_depth, ", m_deviation=", m_deviation, ", m_backstep=", m_backstep);
   
   // 注意：已移除high和low数组前10个值的打印
   
   // 注意：输入数据是从最新到最早排序的，序号0是最新的数据
   // ZigZag计算需要考虑这一点，确保结果的一致性
   
   if(rates_total < 100)
   {
      Print("错误: rates_total小于100");
      return false;
   }
      
   // 调整缓冲区大小
   ArrayResize(m_zigzagPeakBuffer, rates_total);
   ArrayResize(m_zigzagBottomBuffer, rates_total);
   ArrayResize(m_highMapBuffer, rates_total);
   ArrayResize(m_lowMapBuffer, rates_total);
   ArrayResize(m_colorBuffer, rates_total);
   
   Print("缓冲区大小调整完成: ", rates_total);
   
   int    i, start = 0;
   int    extreme_counter = 0, extreme_search = Extremum;
   int    shift, back = 0, last_high_pos = 0, last_low_pos = 0;
   double val = 0, res = 0;
   double cur_low = 0, cur_high = 0, last_high = 0, last_low = 0;
   
   // 初始化
   if(prev_calculated == 0)
     {
      ArrayInitialize(m_zigzagPeakBuffer, 0.0);
      ArrayInitialize(m_zigzagBottomBuffer, 0.0);
      ArrayInitialize(m_highMapBuffer, 0.0);
      ArrayInitialize(m_lowMapBuffer, 0.0);
      ArrayInitialize(m_colorBuffer, -1.0);
      
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
         res = (m_zigzagPeakBuffer[i] + m_zigzagBottomBuffer[i]);
         
         if(res != 0)
            extreme_counter++;
            
         i--;
        }
        
      i++;
      start = i;
      
      // 确定我们要搜索的极值类型
      if(m_lowMapBuffer[i] != 0)
        {
         cur_low = m_lowMapBuffer[i];
         extreme_search = Peak;
        }
      else
        {
         cur_high = m_highMapBuffer[i];
         extreme_search = Bottom;
        }
        
      // 清除指标值
      for(i = start + 1; i < rates_total; i++)
        {
         m_zigzagPeakBuffer[i] = 0.0;
         m_zigzagBottomBuffer[i] = 0.0;
         m_lowMapBuffer[i] = 0.0;
         m_highMapBuffer[i] = 0.0;
        }
     }
     
   // 搜索高低极值
   for(shift = start; shift < rates_total; shift++)
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
               if(shift - back >= 0)
                 {
                  res = m_lowMapBuffer[shift - back];
                  
                  if((res != 0) && (res > val))
                     m_lowMapBuffer[shift - back] = 0.0;
                 }
              }
           }
        }
        
      if(low[shift] == val)
      {
         // 验证价格是否合理
         if(val > 0 && val < 1000000) // 假设价格范围在0到1000000之间
         {
            m_lowMapBuffer[shift] = val;
         }
         else
         {
            Print("无效的低点价格: ", val, " 在索引 ", shift);
            m_lowMapBuffer[shift] = 0.0;
         }
      }
      else
      {
         m_lowMapBuffer[shift] = 0.0;
      }
         
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
               if(shift - back >= 0)
                 {
                  res = m_highMapBuffer[shift - back];
                  
                  if((res != 0) && (res < val))
                     m_highMapBuffer[shift - back] = 0.0;
                 }
              }
           }
        }
        
      if(high[shift] == val)
      {
         // 验证价格是否合理
         if(val > 0 && val < 1000000) // 假设价格范围在0到1000000之间
         {
            m_highMapBuffer[shift] = val;
         }
         else
         {
            Print("无效的高点价格: ", val, " 在索引 ", shift);
            m_highMapBuffer[shift] = 0.0;
         }
      }
      else
      {
         m_highMapBuffer[shift] = 0.0;
      }
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
   for(shift = start; shift < rates_total; shift++)
     {
      res = 0.0;
      switch(extreme_search)
        {
         case Extremum:
            if(last_low == 0 && last_high == 0)
              {
               if(m_highMapBuffer[shift] != 0)
                 {
                  // 验证高点价格是否合理
                  if(high[shift] > 0 && high[shift] < 1000000)
                  {
                     last_high = high[shift];
                     last_high_pos = shift;
                     extreme_search = Bottom;
                     m_zigzagPeakBuffer[shift] = last_high;
                     m_colorBuffer[shift] = 0;
                  }
                  else
                  {
                     Print("忽略无效的高点价格: ", high[shift], " 在索引 ", shift);
                     m_zigzagPeakBuffer[shift] = 0.0;
                  }
                  res = 1;
                 }
                 
               if(m_lowMapBuffer[shift] != 0)
                 {
                  // 验证低点价格是否合理
                  if(low[shift] > 0 && low[shift] < 1000000)
                  {
                     last_low = low[shift];
                     last_low_pos = shift;
                     extreme_search = Peak;
                     m_zigzagBottomBuffer[shift] = last_low;
                     m_colorBuffer[shift] = 1;
                  }
                  else
                  {
                     Print("忽略无效的低点价格: ", low[shift], " 在索引 ", shift);
                     m_zigzagBottomBuffer[shift] = 0.0;
                  }
                  res = 1;
                 }
              }
            break;
            
         case Peak:
            if(m_lowMapBuffer[shift] != 0.0 && m_lowMapBuffer[shift] < last_low &&
               m_highMapBuffer[shift] == 0.0)
              {
               m_zigzagBottomBuffer[last_low_pos] = 0.0;
               last_low_pos = shift;
               last_low = m_lowMapBuffer[shift];
               m_zigzagBottomBuffer[shift] = last_low;
               m_colorBuffer[shift] = 1;
               res = 1;
              }
              
            if(m_highMapBuffer[shift] != 0.0 && m_lowMapBuffer[shift] == 0.0)
              {
               last_high = m_highMapBuffer[shift];
               last_high_pos = shift;
               m_zigzagPeakBuffer[shift] = last_high;
               m_colorBuffer[shift] = 0;
               extreme_search = Bottom;
               res = 1;
              }
            break;
            
         case Bottom:
            if(m_highMapBuffer[shift] != 0.0 &&
               m_highMapBuffer[shift] > last_high &&
               m_lowMapBuffer[shift] == 0.0)
              {
               m_zigzagPeakBuffer[last_high_pos] = 0.0;
               last_high_pos = shift;
               last_high = m_highMapBuffer[shift];
               m_zigzagPeakBuffer[shift] = last_high;
               m_colorBuffer[shift] = 0;
              }
              
            if(m_lowMapBuffer[shift] != 0.0 && m_highMapBuffer[shift] == 0.0)
              {
               last_low = m_lowMapBuffer[shift];
               last_low_pos = shift;
               m_zigzagBottomBuffer[shift] = last_low;
               m_colorBuffer[shift] = 1;
               extreme_search = Peak;
              }
            break;
            
         default:
            return false;
        }
     }
     
   // 添加最近的极值点以确保与图表显示一致
   AddLatestExtremum(m_zigzagPeakBuffer, m_zigzagBottomBuffer, m_colorBuffer, high, low, rates_total);

   // 统计有效的极值点数量
   int total_peaks = 0, total_bottoms = 0;
   for(int i = 0; i < ArraySize(m_zigzagPeakBuffer); i++)
   {
      if(m_zigzagPeakBuffer[i] != 0) total_peaks++;
      if(m_zigzagBottomBuffer[i] != 0) total_bottoms++;
   }
   
   Print("计算完成，找到 ", total_peaks, " 个峰值点和 ", total_bottoms, " 个谷值点");
   
   if(total_peaks == 0 && total_bottoms == 0)
   {
      Print("警告: 未找到任何有效的极值点");
   }
   
   return true;
  }

//+------------------------------------------------------------------+
//| 添加最近的极值点                                                  |
//+------------------------------------------------------------------+
void CZigzagCalculator::AddLatestExtremum(double &peaks[], double &bottoms[], double &colors[], 
                                         const double &high[], const double &low[], int size)
{
   Print("===== 开始添加最新极值点 =====");
   Print("参数: size=", size);
   
   // 打印peaks数组前10个值
   Print("peaks数组前10个值(序号0为最新数据):");
   for(int p = 0; p < MathMin(10, ArraySize(peaks)); p++)
   {
      if(peaks[p] != 0)
         Print("peaks[", p, "]=", peaks[p]);
   }
   
   // 打印bottoms数组前10个值
   Print("bottoms数组前10个值(序号0为最新数据):");
   for(int b = 0; b < MathMin(10, ArraySize(bottoms)); b++)
   {
      if(bottoms[b] != 0)
         Print("bottoms[", b, "]=", bottoms[b]);
   }
   
   // 注意：已移除high和low数组前10个值的打印
   
   // 注意：输入数据是从最新到最早排序的，序号0是最新的数据
   // ZigZag计算需要考虑这一点，确保结果的一致性
   
   if(size < 3) 
   {
      Print("错误: 柱子数量不足，无法添加最新极值点");
      return; // 至少需要3个柱子
   }

   Print("开始添加最新极值点...");

   // 找到最后一个有效的ZigZag点
   int last_valid_idx = -1;
   int last_valid_type = 0; // 0=未知, 1=峰值, -1=谷值

   for(int i = size - 1; i >= 0; i--)
   {
      if(peaks[i] != 0)
      {
         last_valid_idx = i;
         last_valid_type = 1; // 峰值
         Print("找到最后一个有效峰值点，索引:", i, ", 值:", peaks[i]);
         break;
      }
      else if(bottoms[i] != 0)
      {
         last_valid_idx = i;
         last_valid_type = -1; // 谷值
         Print("找到最后一个有效谷值点，索引:", i, ", 值:", bottoms[i]);
         break;
      }
   }

   if(last_valid_idx < 0) 
   {
      Print("没有找到有效的极值点，无法添加最新极值");
      return; // 没有找到有效点
   }
   
   Print("最后一个有效点索引:", last_valid_idx, ", 类型:", (last_valid_type == 1 ? "峰值" : "谷值"));

   // 从最后一个有效点开始向后查找可能的新极值
   int latest_idx = size - 1;
   // 移除时间打印，因为time数组未传入
   Print("最新柱子索引:", latest_idx);

   // 清除未确认区间内的所有之前的临时极值点
   Print("清除未确认区间内的临时极值点，从", last_valid_idx + 1, "到", latest_idx);
   for(int i = last_valid_idx + 1; i <= latest_idx; i++)
   {
      peaks[i] = 0;
      bottoms[i] = 0;
      colors[i] = -1;
   }

   // 如果最后一个有效点是峰值，则查找新的谷值
   if(last_valid_type == 1)
   {
      Print("查找新的谷值点...");
      // 查找最低点（包括最新的柱子）
      double min_val = low[last_valid_idx];
      int min_idx = last_valid_idx;

      for(int i = last_valid_idx + 1; i <= latest_idx; i++)
      {
         if(low[i] < min_val)
         {
            min_val = low[i];
            min_idx = i;
            Print("发现新的低点，索引:", i, ", 值:", min_val);
         }
      }

      // 只添加一个谷值点（即使未完全确认）
      if(min_idx > last_valid_idx)
      {
         double adjusted_min_val = NormalizeDouble(min_val, _Digits);
         // 验证价格是否合理
         if(adjusted_min_val > 0 && adjusted_min_val < 1000000)
         {
            bottoms[min_idx] = adjusted_min_val;
            colors[min_idx] = 1; // 谷值颜色
            Print("添加新的谷值点，索引:", min_idx, ", 值:", adjusted_min_val);
         }
         else
         {
            Print("无效的谷值价格: ", adjusted_min_val);
         }

         // 如果有新的低点突破，移除之前的临时谷值点
         for(int i = last_valid_idx + 1; i < min_idx; i++)
         {
            bottoms[i] = 0;
            if(colors[i] == 1) colors[i] = -1;
         }
      }
      else
      {
         Print("未找到新的谷值点");
      }
   }
   // 如果最后一个有效点是谷值，则查找新的峰值
   else if(last_valid_type == -1)
   {
      Print("查找新的峰值点...");
      // 查找最高点（包括最新的柱子）
      double max_val = high[last_valid_idx];
      int max_idx = last_valid_idx;

      for(int i = last_valid_idx + 1; i <= latest_idx; i++)
      {
         if(high[i] > max_val)
         {
            max_val = high[i];
            max_idx = i;
            Print("发现新的高点，索引:", i, ", 值:", max_val);
         }
      }

      // 只添加一个峰值点（即使未完全确认）
      if(max_idx > last_valid_idx)
      {
         double adjusted_max_val = NormalizeDouble(max_val, _Digits);
         // 验证价格是否合理
         if(adjusted_max_val > 0 && adjusted_max_val < 1000000)
         {
            peaks[max_idx] = adjusted_max_val;
            colors[max_idx] = 0; // 峰值颜色
            Print("添加新的峰值点，索引:", max_idx, ", 值:", adjusted_max_val);
         }
         else
         {
            Print("无效的峰值价格: ", adjusted_max_val);
         }

         // 如果有新的高点突破，移除之前的临时峰值点
         for(int i = last_valid_idx + 1; i < max_idx; i++)
         {
            peaks[i] = 0;
            if(colors[i] == 0) colors[i] = -1;
         }
      }
      else
      {
         Print("未找到新的峰值点");
      }
   }
}

//+------------------------------------------------------------------+
//| 获取ZigZag值                                                      |
//+------------------------------------------------------------------+
bool CZigzagCalculator::GetZigzagValues(int bars_count, double &peaks[], double &bottoms[], double &colors[])
  {
   // 检查参数
   if(bars_count <= 0)
      return false;
      
   // 检查缓冲区是否已初始化
   int size = ArraySize(m_zigzagPeakBuffer);
   if(size == 0)
      return false;
      
   // 调整输出数组大小
   ArrayResize(peaks, bars_count);
   ArrayResize(bottoms, bars_count);
   ArrayResize(colors, bars_count);
   
   // 初始化数组
   ArrayInitialize(peaks, 0.0);
   ArrayInitialize(bottoms, 0.0);
   ArrayInitialize(colors, -1.0);
   
   // 确定要复制的数据量和起始位置
   int copy_size = MathMin(bars_count, size);
   int start_copy_index = size - copy_size; // 从最新的数据开始复制
   
   // 复制数据（确保复制最新的数据）
   for(int i = 0; i < copy_size; i++)
     {
      int src_index = start_copy_index + i;
      peaks[i] = m_zigzagPeakBuffer[src_index];
      bottoms[i] = m_zigzagBottomBuffer[src_index];
      colors[i] = m_colorBuffer[src_index];
     }
     
   // 统计有效的极值点数量
   int total_peaks = 0, total_bottoms = 0;
   for(int i = 0; i < ArraySize(m_zigzagPeakBuffer); i++)
   {
      if(m_zigzagPeakBuffer[i] != 0) total_peaks++;
      if(m_zigzagBottomBuffer[i] != 0) total_bottoms++;
   }
   
   Print("计算完成，找到 ", total_peaks, " 个峰值点和 ", total_bottoms, " 个谷值点");
   
   if(total_peaks == 0 && total_bottoms == 0)
   {
      Print("警告: 未找到任何有效的极值点");
   }
   
   return true;
  }

//+------------------------------------------------------------------+
//| 从指定时间周期获取ZigZag值                                         |
//+------------------------------------------------------------------+
bool CZigzagCalculator::GetZigzagValuesForTimeframe(string symbol, ENUM_TIMEFRAMES timeframe, int bars_count, double &peaks[], double &bottoms[], double &colors[])
  {
   // 检查参数
   if(bars_count <= 0)
      return false;
      
   // 获取历史数据
   MqlRates rates[];
   if(CopyRates(symbol, timeframe, 0, bars_count + m_depth, rates) <= 0)
     {
      Print("无法获取历史数据: ", GetLastError());
      return false;
     }
     
   Print("rates-------------------复制K线数据----------------------------");
   // 注意：CopyRates返回的数据是从最新到最早排序的，即rates[0]是最新的K线数据
   // 打印rates[]前10列值   int print_count = MathMin(10, ArraySize(rates));   
     
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
   if(!GetZigzagValues(bars_count, peaks, bottoms, colors))
     {
      Print("获取ZigZag值失败");
      return false;
     }
     
   // 统计有效的极值点数量
   int total_peaks = 0, total_bottoms = 0;
   for(int i = 0; i < ArraySize(m_zigzagPeakBuffer); i++)
   {
      if(m_zigzagPeakBuffer[i] != 0) total_peaks++;
      if(m_zigzagBottomBuffer[i] != 0) total_bottoms++;
   }
   
   Print("计算完成，找到 ", total_peaks, " 个峰值点和 ", total_bottoms, " 个谷值点");
   
   if(total_peaks == 0 && total_bottoms == 0)
   {
      Print("警告: 未找到任何有效的极值点");
   }
   
   return true;
  }

//+------------------------------------------------------------------+
//| 为指定品种和时间周期直接计算ZigZag值                              |
//+------------------------------------------------------------------+
bool CZigzagCalculator::CalculateForSymbol(const string symbol, ENUM_TIMEFRAMES timeframe, int bars_count)
{
   Print("===== 开始为品种计算ZigZag值 =====");
   Print("参数: symbol=", symbol, ", timeframe=", EnumToString(timeframe), ", bars_count=", bars_count);
   Print("参数: m_depth=", m_depth, ", m_deviation=", m_deviation, ", m_backstep=", m_backstep);
   
   // 检查参数
   if(bars_count <= 0)
   {
      Print("错误: bars_count参数无效");
      return false;
   }
   
   // 获取历史数据
   MqlRates rates[];
   int copied = 0;
   int max_attempts = 3;
   
   for(int attempt = 1; attempt <= max_attempts; attempt++)
   {
      Print("尝试获取历史数据，第", attempt, "次尝试");
      copied = CopyRates(symbol, timeframe, 0, bars_count + m_depth, rates);
      Print("CopyRates结果: copied=", copied, ", 请求数量=", bars_count + m_depth);
      
      if(copied > 0)
      {
         Print("成功获取历史数据");
         break;
      }
      else
      {
         int error = GetLastError();
         Print("错误: 无法获取历史数据: ", error);
         
         // 如果是因为周期切换导致的数据不可用，等待并重试
         if(error == 4006 || error == 4016)
         {
            Print("尝试等待数据加载...");
            Sleep(100 * attempt); // 逐次增加等待时间
         }
         else
         {
            Print("严重错误，放弃尝试");
            return false;
         }
      }
   }
   
   if(copied <= 0)
   {
      Print("错误: 多次尝试后仍无法获取历史数据");
      return false;
   }
   
   // 检查获取的数据量是否足够
   if(copied < m_depth + 10) // 至少需要depth+10个数据点才能计算有效的ZigZag
   {
      Print("警告: 获取的数据量不足，可能导致计算结果不准确: ", copied);
      // 继续执行，但记录警告
   }
   
   // 打印rates数组前10个值
   Print("rates数组前10个值(序号0为最新数据):");
   for(int r = 0; r < MathMin(10, ArraySize(rates)); r++)
   {
      Print("rates[", r, "]: time=", TimeToString(rates[r].time), 
            ", open=", rates[r].open, 
            ", high=", rates[r].high, 
            ", low=", rates[r].low, 
            ", close=", rates[r].close);
   }
   
   // 注意：CopyRates返回的数据是从最新到最早排序的（rates[0]是最新的K线）
   // ZigZag计算时会通过Highest和Lowest函数处理这种顺序，无需手动反转数组
   
   // 直接从rates数组中提取高点和低点数据
   double high[], low[];
   datetime time[];
   int size = ArraySize(rates);
   ArrayResize(high, size);
   ArrayResize(low, size);
   ArrayResize(time, size);
   
   // 确保high、low和time数组的序号与rates完全一致
   for(int i = 0; i < size; i++)
   {
      high[i] = rates[i].high;
      low[i] = rates[i].low;
      time[i] = rates[i].time;
      // 验证价格是否合理
      if(high[i] <= 0 || high[i] > 1000000 || low[i] <= 0 || low[i] > 1000000)
      {
         Print("无效的价格数据: high=", high[i], ", low=", low[i]);
         return false;
      }
   }
   
   // 已取消输出所有极值点数据
   
   // 计算ZigZag值
   if(!Calculate(high, low, size, 0))
   {
      Print("计算ZigZag值失败");
      return false;
   }
   
   // 统计有效的极值点数量
   int total_peaks = 0, total_bottoms = 0;
   for(int i = 0; i < ArraySize(m_zigzagPeakBuffer); i++)
   {
      if(m_zigzagPeakBuffer[i] != 0) total_peaks++;
      if(m_zigzagBottomBuffer[i] != 0) total_bottoms++;
   }
   
   Print("计算完成，找到 ", total_peaks, " 个峰值点和 ", total_bottoms, " 个谷值点");
   
   if(total_peaks == 0 && total_bottoms == 0)
   {
      Print("警告: 未找到任何有效的极值点");
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| 为当前图表计算ZigZag值                                           |
//+------------------------------------------------------------------+
bool CZigzagCalculator::CalculateForCurrentChart(int bars_count)
{
   // 获取当前图表的符号和时间周期
   string symbol = Symbol();
   ENUM_TIMEFRAMES timeframe = (m_timeframe == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : m_timeframe;
   
   // 记录当前时间周期，用于调试
   static ENUM_TIMEFRAMES last_timeframe = PERIOD_CURRENT;
   if(last_timeframe != timeframe)
   {
      Print("时间周期已变更: 从 ", EnumToString(last_timeframe), " 到 ", EnumToString(timeframe));
      last_timeframe = timeframe;
      
      // 在周期变更时，重置缓冲区
      ArrayFree(m_zigzagPeakBuffer);
      ArrayFree(m_zigzagBottomBuffer);
      ArrayFree(m_highMapBuffer);
      ArrayFree(m_lowMapBuffer);
      ArrayFree(m_colorBuffer);
      Print("已重置所有缓冲区");
   }
   
   Print("CalculateForCurrentChart: 使用品种=", symbol, ", 时间周期=", EnumToString(timeframe), ", 数据条数=", bars_count);
   
   // 检查品种和时间周期是否有效
   if(symbol == "" || timeframe == PERIOD_CURRENT)
   {
      Print("错误: 无效的品种或时间周期");
      return false;
   }
   
   // 调用CalculateForSymbol方法，让它负责获取数据
   bool result = CalculateForSymbol(symbol, timeframe, bars_count);
   
   // 记录计算结果
   if(!result)
   {
      Print("警告: CalculateForSymbol返回失败");
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| 获取极值点对象数组                                                |
//+------------------------------------------------------------------+
bool CZigzagCalculator::GetExtremumPoints(CZigzagExtremumPoint &points[], int max_count/* = 0*/)
{
   Print("===== 开始获取极值点 =====");
   Print("参数: max_count=", max_count);
   
   // 检查缓冲区是否已初始化
   int size = ArraySize(m_zigzagPeakBuffer);
   Print("缓冲区大小: size=", size);
   
   if(size == 0)
   {
      Print("错误: 缓冲区未初始化");
      return false;
   }
   
   // 检查底部缓冲区是否与峰值缓冲区大小一致
   if(ArraySize(m_zigzagBottomBuffer) != size)
   {
      Print("错误: 缓冲区大小不一致，峰值缓冲区=", size, ", 底部缓冲区=", ArraySize(m_zigzagBottomBuffer));
      return false;
   }
   
   // 打印m_zigzagPeakBuffer数组前10个值
   Print("m_zigzagPeakBuffer数组前10个值(序号0为最早数据):");
   int peak_count = 0;
   for(int p = 0; p < MathMin(size, 100); p++)
   {
      if(m_zigzagPeakBuffer[p] != 0)
      {
         Print("m_zigzagPeakBuffer[", p, "]=", m_zigzagPeakBuffer[p]);
         peak_count++;
         if(peak_count >= 10) break;
      }
   }
   
   // 打印m_zigzagBottomBuffer数组前10个值
   Print("m_zigzagBottomBuffer数组前10个值(序号0为最早数据):");
   int bottom_count = 0;
   for(int b = 0; b < MathMin(size, 100); b++)
   {
      if(m_zigzagBottomBuffer[b] != 0)
      {
         Print("m_zigzagBottomBuffer[", b, "]=", m_zigzagBottomBuffer[b]);
         bottom_count++;
         if(bottom_count >= 10) break;
      }
   }
      
   // 获取时间数组
   datetime time_array[];
   int copied = CopyTime(Symbol(), m_timeframe, 0, size, time_array);
   if(copied <= 0)
   {
      int error = GetLastError();
      Print("错误: 无法获取时间数据: ", error);
      
      // 如果是因为周期切换导致的数据不可用，等待并重试一次
      if(error == ERR_UNKNOWN_SYMBOL || error == ERR_SERIES_NOT_AVAILABLE)
      {
         Print("尝试等待数据加载...");
         Sleep(100);
         copied = CopyTime(Symbol(), m_timeframe, 0, size, time_array);
         if(copied <= 0)
         {
            Print("重试失败，仍然无法获取时间数据: ", GetLastError());
            return false;
         }
         Print("重试成功，获取了 ", copied, " 条时间数据");
      }
      else
      {
         return false;
      }
   }
   
   // 确保获取的数据量与缓冲区大小匹配
   if(copied < size)
   {
      Print("警告: 获取的时间数据量(", copied, ")小于请求的数量(", size, ")");
      size = copied; // 调整处理的数据量
   }
   
   // 打印time_array数组前10个值
   Print("time_array数组前10个值(序号0为最新数据):");
   for(int t = 0; t < MathMin(10, ArraySize(time_array)); t++)
   {
      Print("time_array[", t, "]=", TimeToString(time_array[t]));
   }
   
   // 注意：CopyTime返回的数据是从最新到最早排序的，与CopyRates一致
   
   // 计算有效极值点的数量
   int valid_count = 0;
   for(int i = 0; i < size; i++)
   {
      if(m_zigzagPeakBuffer[i] != 0 || m_zigzagBottomBuffer[i] != 0)
         valid_count++;
   }
   
   // 如果指定了最大数量，则限制返回的点数
   if(max_count > 0 && max_count < valid_count)
      valid_count = max_count;
      
   // 调整输出数组大小
   ArrayResize(points, valid_count);
   
   // 填充极值点数组
   int point_index = 0;
   
   // 打印当前时间周期
   Print("当前时间周期: ", EnumToString(m_timeframe));
   
   for(int i = 0; i < size && point_index < valid_count; i++)
   {
      if(m_zigzagPeakBuffer[i] != 0)
      {
         // 创建峰值点，确保价格正确
         double adjusted_price = NormalizeDouble(m_zigzagPeakBuffer[i], _Digits);
         // 验证价格是否合理
         if(adjusted_price > 0 && adjusted_price < 1000000) // 假设价格范围在0到1000000之间
         {
            // 验证时间是否有效
            if(time_array[i] > 0)
            {
               points[point_index] = CZigzagExtremumPoint(
                  m_timeframe,
                  time_array[i],
                  i,
                  adjusted_price,
                  EXTREMUM_PEAK
               );
               point_index++;
            }
            else
            {
               Print("无效的时间戳: ", time_array[i], " 在索引 ", i);
            }
         }
         else
         {
            double peak_price = m_zigzagPeakBuffer[i];
            Print("无效的峰值价格: ", peak_price, " 在索引 ", i);
         }
      }
      else if(m_zigzagBottomBuffer[i] != 0)
      {
         // 创建谷值点，确保价格正确
         double adjusted_price = NormalizeDouble(m_zigzagBottomBuffer[i], _Digits);
         // 验证价格是否合理
         if(adjusted_price > 0 && adjusted_price < 1000000) // 假设价格范围在0到1000000之间
         {
            // 验证时间是否有效
            if(time_array[i] > 0)
            {
               points[point_index] = CZigzagExtremumPoint(
                  m_timeframe,
                  time_array[i],
                  i,
                  adjusted_price,
                  EXTREMUM_BOTTOM
               );
               point_index++;
            }
            else
            {
               Print("创建谷值点时发生异常，索引: ", i, ", 时间: ", TimeToString(time_array[i]), ", 价格: ", adjusted_price);
            }
         }
         else
         {
            double bottom_price = m_zigzagBottomBuffer[i];
            Print("无效的谷值价格: ", bottom_price, " 在索引 ", i);
         }
      }
   }
   
   // 统计有效的极值点数量
   int total_peaks = 0, total_bottoms = 0;
   for(int i = 0; i < ArraySize(m_zigzagPeakBuffer); i++)
   {
      if(m_zigzagPeakBuffer[i] != 0) total_peaks++;
      if(m_zigzagBottomBuffer[i] != 0) total_bottoms++;
   }
   
   Print("计算完成，找到 ", total_peaks, " 个峰值点和 ", total_bottoms, " 个谷值点");
   
   if(total_peaks == 0 && total_bottoms == 0)
   {
      Print("警告: 未找到任何有效的极值点");
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| 获取最近的N个极值点                                               |
//+------------------------------------------------------------------+
bool CZigzagCalculator::GetRecentExtremumPoints(CZigzagExtremumPoint &points[], int count)
{
   if(count <= 0)
      return false;
      
   // 获取所有极值点
   CZigzagExtremumPoint all_points[];
   if(!GetExtremumPoints(all_points))
      return false;
      
   // 打印排序前的前几个点的时间
   Print("排序前的前5个点时间:");
   for(int i = 0; i < MathMin(5, ArraySize(all_points)); i++)
   {
      Print("点#", i, " 时间: ", TimeToString(all_points[i].Time()), " 索引: ", all_points[i].BarIndex());
   }
   
   // 手动实现降序排序（按时间，确保从最近到最远排列）
   // 无论输入数据的顺序如何，都确保输出是从最近到最远
   for(int i = 0; i < ArraySize(all_points) - 1; i++)
   {
      for(int j = i + 1; j < ArraySize(all_points); j++)
      {
         // 比较时间戳，确保降序排列（最新的在前面）
         if(all_points[i].Time() < all_points[j].Time())
         {
            CZigzagExtremumPoint temp = all_points[i];
            all_points[i] = all_points[j];
            all_points[j] = temp;
         }
      }
   }
   
   // 打印排序后的前几个点的时间
   Print("排序后的前5个点时间:");
   for(int i = 0; i < MathMin(5, ArraySize(all_points)); i++)
   {
      Print("点#", i, " 时间: ", TimeToString(all_points[i].Time()), " 索引: ", all_points[i].BarIndex());
   }
   
   // 打印排序后的前几个点，确认顺序正确
   Print("排序后的极值点(从最近到最远):");
   for(int i = 0; i < MathMin(5, ArraySize(all_points)); i++)
   {
      Print("点[", i, "]: 时间=", TimeToString(all_points[i].Time()), 
            ", 价格=", all_points[i].Value(), 
            ", 类型=", all_points[i].Type() == EXTREMUM_PEAK ? "峰值" : "谷值");
   }
      
   // 确定要返回的点数
   int total_points = ArraySize(all_points);
   int return_count = MathMin(count, total_points);
   
   // 调整输出数组大小
   ArrayResize(points, return_count);
   
   // 复制最近的N个点（从最新到最旧）
   for(int i = 0; i < return_count; i++)
   {
      points[i] = all_points[i];
   }
   
   // 统计有效的极值点数量
   int total_peaks = 0, total_bottoms = 0;
   for(int i = 0; i < ArraySize(m_zigzagPeakBuffer); i++)
   {
      if(m_zigzagPeakBuffer[i] != 0) total_peaks++;
      if(m_zigzagBottomBuffer[i] != 0) total_bottoms++;
   }
   
   Print("计算完成，找到 ", total_peaks, " 个峰值点和 ", total_bottoms, " 个谷值点");
   
   if(total_peaks == 0 && total_bottoms == 0)
   {
      Print("警告: 未找到任何有效的极值点");
   }
   
   return true;
}
//+------------------------------------------------------------------+