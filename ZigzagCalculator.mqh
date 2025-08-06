//+------------------------------------------------------------------+
//|                                               ZigzagCalculator.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

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
   if(rates_total < 100)
      return false;
      
   // 调整缓冲区大小
   ArrayResize(m_zigzagPeakBuffer, rates_total);
   ArrayResize(m_zigzagBottomBuffer, rates_total);
   ArrayResize(m_highMapBuffer, rates_total);
   ArrayResize(m_lowMapBuffer, rates_total);
   ArrayResize(m_colorBuffer, rates_total);
   
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
         m_lowMapBuffer[shift] = val;
      else
         m_lowMapBuffer[shift] = 0.0;
         
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
         m_highMapBuffer[shift] = val;
      else
         m_highMapBuffer[shift] = 0.0;
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
                  last_high = high[shift];
                  last_high_pos = shift;
                  extreme_search = Bottom;
                  m_zigzagPeakBuffer[shift] = last_high;
                  m_colorBuffer[shift] = 0;
                  res = 1;
                 }
                 
               if(m_lowMapBuffer[shift] != 0)
                 {
                  last_low = low[shift];
                  last_low_pos = shift;
                  extreme_search = Peak;
                  m_zigzagBottomBuffer[shift] = last_low;
                  m_colorBuffer[shift] = 1;
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

   return true;
  }

//+------------------------------------------------------------------+
//| 添加最近的极值点                                                  |
//+------------------------------------------------------------------+
void CZigzagCalculator::AddLatestExtremum(double &peaks[], double &bottoms[], double &colors[], 
                                         const double &high[], const double &low[], int size)
{
   if(size < 3) return; // 至少需要3个柱子

   // 找到最后一个有效的ZigZag点
   int last_valid_idx = -1;
   int last_valid_type = 0; // 0=未知, 1=峰值, -1=谷值

   for(int i = size - 1; i >= 0; i--)
   {
      if(peaks[i] != 0)
      {
         last_valid_idx = i;
         last_valid_type = 1; // 峰值
         break;
      }
      else if(bottoms[i] != 0)
      {
         last_valid_idx = i;
         last_valid_type = -1; // 谷值
         break;
      }
   }

   if(last_valid_idx < 0) return; // 没有找到有效点

   // 从最后一个有效点开始向后查找可能的新极值
   int latest_idx = size - 1;

   // 如果最后一个有效点是峰值，则查找新的谷值
   if(last_valid_type == 1)
   {
      // 查找最低点（包括最新的柱子）
      double min_val = low[last_valid_idx];
      int min_idx = last_valid_idx;

      for(int i = last_valid_idx + 1; i <= latest_idx; i++)
      {
         if(low[i] < min_val)
         {
            min_val = low[i];
            min_idx = i;
         }
      }

      // 添加可能的谷值点（即使未完全确认）
      if(min_idx > last_valid_idx)
      {
         bottoms[min_idx] = min_val;
         colors[min_idx] = 1; // 谷值颜色

         // 现在从这个谷值开始查找可能的新峰值
         double max_val = high[min_idx];
         int max_idx = min_idx;

         for(int i = min_idx + 1; i <= latest_idx; i++)
         {
            if(high[i] > max_val)
            {
               max_val = high[i];
               max_idx = i;
            }
         }

         // 添加可能的峰值点（即使未完全确认）
         if(max_idx > min_idx)
         {
            peaks[max_idx] = max_val;
            colors[max_idx] = 0; // 峰值颜色
         }
      }
   }
   // 如果最后一个有效点是谷值，则查找新的峰值
   else if(last_valid_type == -1)
   {
      // 查找最高点（包括最新的柱子）
      double max_val = high[last_valid_idx];
      int max_idx = last_valid_idx;

      for(int i = last_valid_idx + 1; i <= latest_idx; i++)
      {
         if(high[i] > max_val)
         {
            max_val = high[i];
            max_idx = i;
         }
      }

      // 添加可能的峰值点（即使未完全确认）
      if(max_idx > last_valid_idx)
      {
         peaks[max_idx] = max_val;
         colors[max_idx] = 0; // 峰值颜色

         // 现在从这个峰值开始查找可能的新谷值
         double min_val = low[max_idx];
         int min_idx = max_idx;

         for(int i = max_idx + 1; i <= latest_idx; i++)
         {
            if(low[i] < min_val)
            {
               min_val = low[i];
               min_idx = i;
            }
         }

         // 添加可能的谷值点（即使未完全确认）
         if(min_idx > max_idx)
         {
            bottoms[min_idx] = min_val;
            colors[min_idx] = 1; // 谷值颜色
         }
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
     
   return true;
  }

//+------------------------------------------------------------------+
//| 为指定品种和时间周期直接计算ZigZag值                              |
//+------------------------------------------------------------------+
bool CZigzagCalculator::CalculateForSymbol(const string symbol, ENUM_TIMEFRAMES timeframe, int bars_count)
{
   // 检查参数
   if(bars_count <= 0)
      return false;
   
   // 获取历史数据
   MqlRates rates[];
   int copied = CopyRates(symbol, timeframe, 0, bars_count + m_depth, rates);
   if(copied <= 0)
   {
      Print("无法获取历史数据: ", GetLastError());
      return false;
   }
   
   // 提取高点和低点数据
   double high[];
   double low[];
   int size = ArraySize(rates);
   ArrayResize(high, size);
   ArrayResize(low, size);
   
   // 注意: CopyRates返回的数据是从新到旧排列的，需要反转
   for(int i = 0; i < size; i++)
   {
      high[i] = rates[size-1-i].high;
      low[i] = rates[size-1-i].low;
   }
   
   // 计算ZigZag值
   if(!Calculate(high, low, size, 0))
   {
      Print("计算ZigZag值失败");
      return false;
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
   
   return CalculateForSymbol(symbol, timeframe, bars_count);
}
//+------------------------------------------------------------------+