//+------------------------------------------------------------------+
//|                                                 TradeAnalyzer.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

// 引入极值点类定义
#include "ZigzagExtremumPoint.mqh"
#include "CommonUtils.mqh"

//+------------------------------------------------------------------+
//| 交易分析类 - 用于分析价格区间和趋势方向                            |
//+------------------------------------------------------------------+
class CTradeAnalyzer
  {
private:
   // 区间高点和低点
   static double    m_rangeHigh;       // 区间高点（大周期的离当前最近的极点值）
   static double    m_rangeLow;        // 区间低点（大周期离当前次近的极点值）
   static datetime  m_rangeHighTime;   // 区间高点时间
   static datetime  m_rangeLowTime;    // 区间低点时间
   static bool      m_isUpTrend;       // 当前趋势方向（true为上涨，false为下跌）
   static bool      m_isValid;         // 数据是否有效
   
   // 回撤和反弹相关变量
   static double    m_retracePrice;    // 回撤最低点或反弹最高点
   static datetime  m_retraceTime;     // 回撤或反弹点的时间
   static double    m_retracePercent;  // 回撤或反弹的百分比
   static double    m_retraceDiff;     // 回撤或反弹的绝对值差距
   
   // 多时间周期支撑和压力
   static double    m_support1H;       // 1小时支撑
   static double    m_support4H;       // 4小时支撑
   static double    m_supportD1;       // 日线支撑
   static double    m_resistance1H;    // 1小时压力
   static double    m_resistance4H;    // 4小时压力
   static double    m_resistanceD1;    // 日线压力
   
   // 支撑和压力对应的1小时K线时间
   static datetime  m_support1HTime;   // 1小时支撑对应的1小时K线时间
   static datetime  m_support4HTime;   // 4小时支撑对应的1小时K线时间
   static datetime  m_supportD1Time;   // 日线支撑对应的1小时K线时间
   static datetime  m_resistance1HTime; // 1小时压力对应的1小时K线时间
   static datetime  m_resistance4HTime; // 4小时压力对应的1小时K线时间
   static datetime  m_resistanceD1Time; // 日线压力对应的1小时K线时间

public:
   // 初始化方法
   static void Init()
     {
      m_rangeHigh = 0.0;
      m_rangeLow = 0.0;
      m_rangeHighTime = 0;
      m_rangeLowTime = 0;
      m_isUpTrend = false;
      m_isValid = false;
      m_retracePrice = 0.0;
      m_retraceTime = 0;
      m_retracePercent = 0.0;
      m_retraceDiff = 0.0;
      m_support1H = 0.0;
      m_support4H = 0.0;
      m_supportD1 = 0.0;
      m_resistance1H = 0.0;
      m_resistance4H = 0.0;
      m_resistanceD1 = 0.0;
      m_support1HTime = 0;
      m_support4HTime = 0;
      m_supportD1Time = 0;
      m_resistance1HTime = 0;
      m_resistance4HTime = 0;
      m_resistanceD1Time = 0;
     }
     
   // 从极点数组中分析区间
   static bool AnalyzeRange(CZigzagExtremumPoint &points[], int minPoints = 2)
     {
      // 检查数据有效性
      if(ArraySize(points) < minPoints)
        {
         m_isValid = false;
         return false;
        }
        
      // 获取最近的两个极点
      CZigzagExtremumPoint point1 = points[0]; // 最近的点
      CZigzagExtremumPoint point2 = points[1]; // 次近的点
      
      // 确定高点和低点
      if(point1.Value() > point2.Value())
        {
         // 最近的点是高点
         m_rangeHigh = point1.Value();
         m_rangeLow = point2.Value();
         m_rangeHighTime = point1.Time();
         m_rangeLowTime = point2.Time();
         m_isUpTrend = true; // 从低点到高点，趋势向上
        }
      else
        {
         // 最近的点是低点
         m_rangeHigh = point2.Value();
         m_rangeLow = point1.Value();
         m_rangeHighTime = point2.Time();
         m_rangeLowTime = point1.Time();
         m_isUpTrend = false; // 从高点到低点，趋势向下
        }
        
      m_isValid = true;
      
      // 分析完区间后立即计算回撤或反弹
      CalculateRetracement();
      
      // 计算多时间周期支撑和压力
      CalculateSupportResistance();
      
      return true;
     }
     
   // 计算回撤或反弹
   static void CalculateRetracement()
     {
      if(!m_isValid)
         return;
         
      double currentPrice = GetCurrentPrice();
      
      // 根据趋势方向计算回撤或反弹
      if(m_isUpTrend)
        {
         // 上涨趋势，计算回撤（从最高点到当前的最低点）
         // 使用通用函数查找高点之后的最低价格
         m_retracePrice = FindLowestPriceAfterHighPrice(m_rangeHigh, m_retraceTime, PERIOD_CURRENT, PERIOD_M1, m_rangeHighTime);
         
         // 计算回撤绝对值
         m_retraceDiff = m_rangeHigh - m_retracePrice;
           
         // 计算回撤百分比 - 使用区间高低点差值作为分母
         double rangeDiff = m_rangeHigh - m_rangeLow;
         if(rangeDiff > 0)
            m_retracePercent = m_retraceDiff / rangeDiff * 100.0;
        }
      else
        {
         // 下跌趋势，计算反弹（从最低点到当前的最高点）
         // 使用通用函数查找低点之后的最高价格
         m_retracePrice = FindHighestPriceAfterLowPrice(m_rangeLow, m_retraceTime, PERIOD_CURRENT, PERIOD_M1, m_rangeLowTime);
         
         // 计算反弹绝对值
         m_retraceDiff = m_retracePrice - m_rangeLow;
           
         // 计算反弹百分比 - 使用区间高低点差值作为分母
         double rangeDiff = m_rangeHigh - m_rangeLow;
         if(rangeDiff > 0)
            m_retracePercent = m_retraceDiff / rangeDiff * 100.0;
        }
     }
     
     
   // 计算多时间周期的支撑和压力
   static void CalculateSupportResistance()
     {
      if(!m_isValid)
         return;
         
      // 根据趋势方向计算支撑或压力
      if(m_isUpTrend)
        {
         // 上涨趋势，计算支撑位（传入区间高点）
         CalculateSupport(PERIOD_H1, m_support1H, m_rangeHigh);
         CalculateSupport(PERIOD_H4, m_support4H, m_rangeHigh);
         CalculateSupport(PERIOD_D1, m_supportD1, m_rangeHigh);
        }
      else
        {
         // 下跌趋势，计算压力位（传入区间低点）
         CalculateResistance(PERIOD_H1, m_resistance1H, m_rangeLow);
         CalculateResistance(PERIOD_H4, m_resistance4H, m_rangeLow);
         CalculateResistance(PERIOD_D1, m_resistanceD1, m_rangeLow);
        }
     }
     
   // 计算指定时间周期的支撑位
   static void CalculateSupport(ENUM_TIMEFRAMES timeframe, double &supportPrice, double referencePrice)
     {
      // 如果参考价格为0，则不计算支撑位
      if(referencePrice <= 0)
        {
         supportPrice = 0.0;
         return;
        }
      
      // 初始化支撑价格
      supportPrice = 0.0;
      
      // 在当前周期的K线中查找与参考价格最接近的K线
      int bars = Bars(Symbol(), timeframe);
      int priceShift = -1;
      
      // 遍历K线，查找与参考价格匹配的K线
      for(int i = 0; i < bars; i++)
        {
         double high = iHigh(Symbol(), timeframe, i);
         
         // 如果找到与参考价格相等或非常接近的高点
         if(MathAbs(high - referencePrice) < Point() * 10)
           {
            priceShift = i;
            break;
           }
        }
      
      // 如果找不到匹配的K线，使用时间查找
      if(priceShift < 0)
        {
         priceShift = iBarShift(Symbol(), timeframe, m_rangeHighTime);
        }          
       
      
      // 如果价格K线索引有效且至少有一根前面的K线
      if(priceShift >= 0 && priceShift + 1 < bars)
        {
         // 取前一根K线的最低价作为支撑位
         supportPrice = iLow(Symbol(), timeframe, priceShift + 1);
         
         // 获取支撑位对应的K线时间
         datetime supportTime = iTime(Symbol(), timeframe, priceShift + 1);
         
         // 根据时间周期保存对应的1小时K线时间
         if(timeframe == PERIOD_H1)
           {
            m_support1HTime = supportTime;
            Print("计算得到的1小时支撑位: ", DoubleToString(supportPrice, _Digits), 
                  " (来自K线序号: ", priceShift + 1, ", 时间: ", TimeToString(supportTime), ")");
           }
         else if(timeframe == PERIOD_H4)
           {
            // 将4小时K线时间转换为对应的1小时K线时间
            m_support4HTime = supportTime;
            Print("计算得到的4小时支撑位: ", DoubleToString(supportPrice, _Digits), 
                  " (来自K线序号: ", priceShift + 1, ", 时间: ", TimeToString(supportTime), ")");
           }
         else if(timeframe == PERIOD_D1)
           {
            // 在1小时周期上查找与日线支撑价格最接近的K线
            int h1Bars = Bars(Symbol(), PERIOD_H1);
            int h1Shift = -1;
            
            // 遍历1小时K线，查找与日线支撑价格匹配的K线
            for(int i = 0; i < h1Bars; i++)
              {
               double h1Low = iLow(Symbol(), PERIOD_H1, i);
               
               // 如果找到与支撑价格相等或非常接近的低点
               if(MathAbs(h1Low - supportPrice) < Point() * 10)
                 {
                  h1Shift = i;
                  break;
                 }
              }
            
            // 如果找到了匹配的1小时K线
            if(h1Shift >= 0)
              {
               m_supportD1Time = iTime(Symbol(), PERIOD_H1, h1Shift);
               Print("计算得到的日线支撑位: ", DoubleToString(supportPrice, _Digits), 
                     " (来自D1 K线序号: ", priceShift + 1, ", 时间: ", TimeToString(supportTime),
                     ", 在1H周期找到匹配K线序号: ", h1Shift, ", 时间: ", TimeToString(m_supportD1Time), ")");
              }
            else
              {
               // 如果没有找到匹配的K线，使用当前时间
               m_supportD1Time = supportTime;
               Print("计算得到的日线支撑位: ", DoubleToString(supportPrice, _Digits), 
                     " (来自D1 K线序号: ", priceShift + 1, ", 时间: ", TimeToString(supportTime),
                     ", 在1H周期未找到匹配K线，使用原始时间)");
              }
           }
        }
      else if(priceShift >= 0)
        {
         // 如果无法获取前一根K线，使用当前K线的最低价
         supportPrice = iLow(Symbol(), timeframe, priceShift);
         
         // 获取支撑位对应的K线时间
         datetime supportTime = iTime(Symbol(), timeframe, priceShift);
         
         // 根据时间周期保存对应的1小时K线时间
         if(timeframe == PERIOD_H1)
           {
            m_support1HTime = supportTime;
            Print("无法获取前一根K线，使用当前K线的最低价作为支撑位: ", 
                  DoubleToString(supportPrice, _Digits), 
                  " (来自K线序号: ", priceShift, ", 时间: ", TimeToString(supportTime), ")");
           }
         else if(timeframe == PERIOD_H4)
           {
            // 在1小时周期上查找与4小时支撑价格最接近的K线
            int h1Bars = Bars(Symbol(), PERIOD_H1);
            int h1Shift = -1;
            
            // 遍历1小时K线，查找与4小时支撑价格匹配的K线
            for(int i = 0; i < h1Bars; i++)
              {
               double h1Low = iLow(Symbol(), PERIOD_H1, i);
               
               // 如果找到与支撑价格相等或非常接近的低点
               if(MathAbs(h1Low - supportPrice) < Point() * 10)
                 {
                  h1Shift = i;
                  break;
                 }
              }
            
            // 如果找到了匹配的1小时K线
            if(h1Shift >= 0)
              {
               m_support4HTime = iTime(Symbol(), PERIOD_H1, h1Shift);
               Print("计算得到的4小时支撑位: ", DoubleToString(supportPrice, _Digits), 
                     " (来自4H K线序号: ", priceShift + 1, ", 时间: ", TimeToString(supportTime),
                     ", 在1H周期找到匹配K线序号: ", h1Shift, ", 时间: ", TimeToString(m_support4HTime), ")");
              }
            else
              {
               // 如果没有找到匹配的K线，使用当前时间
               m_support4HTime = TimeCurrent();
               Print("计算得到的4小时支撑位: ", DoubleToString(supportPrice, _Digits), 
                     " (来自4H K线序号: ", priceShift + 1, ", 时间: ", TimeToString(supportTime),
                     ", 在1H周期未找到匹配K线，使用当前时间)");
              }
           }
         else if(timeframe == PERIOD_D1)
           {
            // 在1小时周期上查找与日线支撑价格最接近的K线
            int h1Bars = Bars(Symbol(), PERIOD_H1);
            int h1Shift = -1;
            
            // 遍历1小时K线，查找与日线支撑价格匹配的K线
            for(int i = 0; i < h1Bars; i++)
              {
               double h1Low = iLow(Symbol(), PERIOD_H1, i);
               
               // 如果找到与支撑价格相等或非常接近的低点
               if(MathAbs(h1Low - supportPrice) < Point() * 10)
                 {
                  h1Shift = i;
                  break;
                 }
              }
            
            // 如果找到了匹配的1小时K线
            if(h1Shift >= 0)
              {
               m_supportD1Time = iTime(Symbol(), PERIOD_H1, h1Shift);
               Print("计算得到的日线支撑位: ", DoubleToString(supportPrice, _Digits), 
                     " (来自D1 K线序号: ", priceShift + 1, ", 时间: ", TimeToString(supportTime),
                     ", 在1H周期找到匹配K线序号: ", h1Shift, ", 时间: ", TimeToString(m_supportD1Time), ")");
              }
            else
              {
               // 如果没有找到匹配的K线，使用当前时间
               m_supportD1Time = TimeCurrent();
               Print("计算得到的日线支撑位: ", DoubleToString(supportPrice, _Digits), 
                     " (来自D1 K线序号: ", priceShift + 1, ", 时间: ", TimeToString(supportTime),
                     ", 在1H周期未找到匹配K线，使用当前时间)");
              }
           }
        }
     }
     
   // 计算指定时间周期的压力位
   static void CalculateResistance(ENUM_TIMEFRAMES timeframe, double &resistancePrice, double referencePrice)
     {
      // 如果参考价格为0，则不计算压力位
      if(referencePrice <= 0)
        {
         resistancePrice = 0.0;
         return;
        }
      
      // 初始化压力价格
      resistancePrice = 0.0;
      
      // 在当前周期的K线中查找与参考价格最接近的K线
      int bars = Bars(Symbol(), timeframe);
      int priceShift = -1;
      
      // 遍历K线，查找与参考价格匹配的K线
      for(int i = 0; i < bars; i++)
        {
         double low = iLow(Symbol(), timeframe, i);
         
         // 如果找到与参考价格相等或非常接近的低点
         if(MathAbs(low - referencePrice) < Point() * 10)
           {
            priceShift = i;
            break;
           }
        }
      
      // 如果找不到匹配的K线，使用时间查找
      if(priceShift < 0)
        {
         priceShift = iBarShift(Symbol(), timeframe, m_rangeLowTime);
        }
      
      // 如果价格K线索引有效且至少有一根前面的K线
      if(priceShift >= 0 && priceShift + 1 < bars)
        {
         // 取前一根K线的最高价作为压力位
         resistancePrice = iHigh(Symbol(), timeframe, priceShift + 1);
         
         // 获取压力位对应的K线时间
         datetime resistanceTime = iTime(Symbol(), timeframe, priceShift + 1);
         
         // 根据时间周期保存对应的1小时K线时间
         if(timeframe == PERIOD_H1)
           {
            m_resistance1HTime = resistanceTime;
            Print("计算得到的1小时压力位: ", DoubleToString(resistancePrice, _Digits), 
                  " (来自K线序号: ", priceShift + 1, ", 时间: ", TimeToString(resistanceTime), ")");
           }
         else if(timeframe == PERIOD_H4)
           {
            // 在1小时周期上查找与4小时压力价格最接近的K线
            int h1Bars = Bars(Symbol(), PERIOD_H1);
            int h1Shift = -1;
            
            // 遍历1小时K线，查找与4小时压力价格匹配的K线
            for(int i = 0; i < h1Bars; i++)
              {
               double h1High = iHigh(Symbol(), PERIOD_H1, i);
               
               // 如果找到与压力价格相等或非常接近的高点
               if(MathAbs(h1High - resistancePrice) < Point() * 10)
                 {
                  h1Shift = i;
                  break;
                 }
              }
            
            // 如果找到了匹配的1小时K线
            if(h1Shift >= 0)
              {
               m_resistance4HTime = iTime(Symbol(), PERIOD_H1, h1Shift);
               Print("计算得到的4小时压力位: ", DoubleToString(resistancePrice, _Digits), 
                     " (来自4H K线序号: ", priceShift + 1, ", 时间: ", TimeToString(resistanceTime),
                     ", 在1H周期找到匹配K线序号: ", h1Shift, ", 时间: ", TimeToString(m_resistance4HTime), ")");
              }
            else
              {
               // 如果没有找到匹配的K线，使用当前时间
               m_resistance4HTime = TimeCurrent();
               Print("计算得到的4小时压力位: ", DoubleToString(resistancePrice, _Digits), 
                     " (来自4H K线序号: ", priceShift + 1, ", 时间: ", TimeToString(resistanceTime),
                     ", 在1H周期未找到匹配K线，使用当前时间)");
              }
           }
         else if(timeframe == PERIOD_D1)
           {
            // 在1小时周期上查找与日线压力价格最接近的K线
            int h1Bars = Bars(Symbol(), PERIOD_H1);
            int h1Shift = -1;
            
            // 遍历1小时K线，查找与日线压力价格匹配的K线
            for(int i = 0; i < h1Bars; i++)
              {
               double h1High = iHigh(Symbol(), PERIOD_H1, i);
               
               // 如果找到与压力价格相等或非常接近的高点
               if(MathAbs(h1High - resistancePrice) < Point() * 10)
                 {
                  h1Shift = i;
                  break;
                 }
              }
            
            // 如果找到了匹配的1小时K线
            if(h1Shift >= 0)
              {
               m_resistanceD1Time = iTime(Symbol(), PERIOD_H1, h1Shift);
               Print("计算得到的日线压力位: ", DoubleToString(resistancePrice, _Digits), 
                     " (来自D1 K线序号: ", priceShift + 1, ", 时间: ", TimeToString(resistanceTime),
                     ", 在1H周期找到匹配K线序号: ", h1Shift, ", 时间: ", TimeToString(m_resistanceD1Time), ")");
              }
            else
              {
               // 如果没有找到匹配的K线，使用当前时间
               m_resistanceD1Time = TimeCurrent();
               Print("计算得到的日线压力位: ", DoubleToString(resistancePrice, _Digits), 
                     " (来自D1 K线序号: ", priceShift + 1, ", 时间: ", TimeToString(resistanceTime),
                     ", 在1H周期未找到匹配K线，使用当前时间)");
              }
           }
        }
      else if(priceShift >= 0)
        {
         // 如果无法获取前一根K线，使用当前K线的最高价
         resistancePrice = iHigh(Symbol(), timeframe, priceShift);
         
         // 获取压力位对应的K线时间
         datetime resistanceTime = iTime(Symbol(), timeframe, priceShift);
         
         // 根据时间周期保存对应的1小时K线时间
         if(timeframe == PERIOD_H1)
           {
            m_resistance1HTime = resistanceTime;
            Print("无法获取前一根K线，使用当前K线的最高价作为压力位: ", 
                  DoubleToString(resistancePrice, _Digits), 
                  " (来自K线序号: ", priceShift, ", 时间: ", TimeToString(resistanceTime), ")");
           }
         else if(timeframe == PERIOD_H4)
           {
            // 将4小时K线时间转换为对应的1小时K线时间
            m_resistance4HTime = resistanceTime;
           }
         else if(timeframe == PERIOD_D1)
           {
            // 将日线K线时间转换为对应的1小时K线时间
            m_resistanceD1Time = resistanceTime;
           }
        }
     }
     
   // 获取1小时支撑
   static double GetSupport1H()
     {
      return m_support1H;
     }
     
   // 获取4小时支撑
   static double GetSupport4H()
     {
      return m_support4H;
     }
     
   // 获取日线支撑
   static double GetSupportD1()
     {
      return m_supportD1;
     }
     
   // 获取1小时压力
   static double GetResistance1H()
     {
      return m_resistance1H;
     }
     
   // 获取4小时压力
   static double GetResistance4H()
     {
      return m_resistance4H;
     }
     
   // 获取日线压力
   static double GetResistanceD1()
     {
      Print("获取日线压力值: ", DoubleToString(m_resistanceD1, _Digits), ", 时间: ", TimeToString(m_resistanceD1Time));
      return m_resistanceD1;
     }
     
   // 获取1小时支撑时间
   static datetime GetSupport1HTime()
     {
      return m_support1HTime;
     }
     
   // 获取4小时支撑时间
   static datetime GetSupport4HTime()
     {
      return m_support4HTime;
     }
     
   // 获取日线支撑时间
   static datetime GetSupportD1Time()
     {
      return m_supportD1Time;
     }
     
   // 获取1小时压力时间
   static datetime GetResistance1HTime()
     {
      return m_resistance1HTime;
     }
     
   // 获取4小时压力时间
   static datetime GetResistance4HTime()
     {
      return m_resistance4HTime;
     }
     
   // 获取日线压力时间
   static datetime GetResistanceD1Time()
     {
      return m_resistanceD1Time;
     }
     
   // 获取支撑压力描述
   static string GetSupportResistanceDescription()
     {
      if(!m_isValid)
         return "";
         
      if(m_isUpTrend)
        {
         // 上涨趋势，显示支撑位和参考点
         string support1HText = DoubleToString(m_support1H, _Digits);
         string referenceText = DoubleToString(m_rangeHigh, _Digits);
         
         return "支撑：参考点" + referenceText;
        }
      else
        {
         // 下跌趋势，显示压力位和参考点
         string resistance1HText = DoubleToString(m_resistance1H, _Digits);
         string referenceText = DoubleToString(m_rangeLow, _Digits);
         
         return "压力：参考点" + referenceText;
        }
     }
     
   // 获取4小时支撑/压力描述
   static string GetSupportResistance4HDescription()
     {
      if(!m_isValid)
         return "";
         
      if(m_isUpTrend)
        {
         // 上涨趋势，显示支撑位
         string support4HText = DoubleToString(m_support4H, _Digits);
         return "4H=" + support4HText;
        }
      else
        {
         // 下跌趋势，显示压力位
         string resistance4HText = DoubleToString(m_resistance4H, _Digits);
         return "4H=" + resistance4HText;
        }
     }
     
   // 获取日线支撑/压力描述
   static string GetSupportResistanceD1Description()
     {
      if(!m_isValid)
         return "";
         
      if(m_isUpTrend)
        {
         // 上涨趋势，显示支撑位
         string supportD1Text = DoubleToString(m_supportD1, _Digits);
         return "D1=" + supportD1Text;
        }
      else
        {
         // 下跌趋势，显示压力位
         string resistanceD1Text = DoubleToString(m_resistanceD1, _Digits);
         return "D1=" + resistanceD1Text;
        }
     }
     
   // 获取回撤或反弹价格
   static double GetRetracePrice()
     {
      return m_retracePrice;
     }
     
   // 获取回撤或反弹时间
   static datetime GetRetraceTime()
     {
      return m_retraceTime;
     }
     
   // 获取回撤或反弹百分比
   static double GetRetracePercent()
     {
      return m_retracePercent;
     }
     
   // 获取回撤或反弹绝对值差距
   static double GetRetraceDiff()
     {
      return m_retraceDiff;
     }
     
   // 获取回撤或反弹描述
   static string GetRetraceDescription()
     {
      if(!m_isValid)
         return "";
         
      string retraceType = m_isUpTrend ? "回撤" : "反弹";
      string priceText = DoubleToString(m_retracePrice, _Digits);
      string diffText = DoubleToString(m_retraceDiff, _Digits);
      string percentText = DoubleToString(m_retracePercent, 2);
      
      return StringFormat("%s: %s (%s点, %s%%)", 
                         retraceType, priceText, diffText, percentText);
     }
     
   // 获取区间高点
   static double GetRangeHigh()
     {
      return m_rangeHigh;
     }
     
   // 获取区间低点
   static double GetRangeLow()
     {
      return m_rangeLow;
     }
     
   // 获取区间高点时间
   static datetime GetRangeHighTime()
     {
      return m_rangeHighTime;
     }
     
   // 获取区间低点时间
   static datetime GetRangeLowTime()
     {
      return m_rangeLowTime;
     }
     
   // 获取趋势方向
   static bool IsUpTrend()
     {
      return m_isUpTrend;
     }
     
   // 获取趋势方向描述
   static string GetTrendDirection()
     {
      return m_isUpTrend ? "上涨" : "下跌";
     }
     
   // 检查数据是否有效
   static bool IsValid()
     {
      return m_isValid;
     }
     
   // 这些方法已被移除，不再计算价格位置和距离
     
   // 获取区间分析结果的文本描述
   static string GetRangeAnalysisText(double currentPrice)
     {
      if(!m_isValid)
         return "区间数据无效";
         
      string direction = GetTrendDirection();
      string highText = DoubleToString(m_rangeHigh, _Digits);
      string lowText = DoubleToString(m_rangeLow, _Digits);
      
      // 根据趋势方向调整显示顺序
      if(m_isUpTrend)
        {
         // 上涨趋势，显示从低到高
         return StringFormat("区间: %s - %s (%s)", 
                           lowText, highText, direction);
        }
      else
        {
         // 下跌趋势，显示从高到低
         return StringFormat("区间: %s - %s (%s)", 
                           highText, lowText, direction);
        }
     }
     
   // 获取当前价格
   static double GetCurrentPrice()
     {
      double price = 0.0;
      
      // 获取当前品种的最新价格
      MqlTick last_tick;
      if(SymbolInfoTick(Symbol(), last_tick))
        {
         // 使用最后成交价作为当前价格
         price = last_tick.last;
         
         // 如果最后成交价为0，则使用买卖价的中间价
         if(price == 0)
           {
            price = (last_tick.bid + last_tick.ask) / 2.0;
           }
        }
      
      return price;
     }
     
   // 在1分钟K线上查找反弹高点 - 使用CommonUtils中的通用函数
   static double FindReboundHighOnM1(int lowestBarIndex, datetime &highTime)
     {
      // 检查参数
      if(lowestBarIndex < 0)
        {
         Print("无效的K线索引");
         highTime = 0;
         return 0.0;
        }
        
      // 获取当前周期的最低点时间
      datetime lowestTime = iTime(Symbol(), Period(), lowestBarIndex);
      Print("最低点出现在序号为", lowestBarIndex, "的K线上，时间为", TimeToString(lowestTime));
      
      // 获取1分钟周期上的最低价
      double lowestPrice = iLow(Symbol(), PERIOD_M1, iBarShift(Symbol(), PERIOD_M1, lowestTime));
      
      // 使用通用函数查找最高价格
      return FindHighestPriceAfterLowPrice(lowestPrice, highTime, PERIOD_M1, PERIOD_M1, lowestTime);
     }
  };

// 初始化静态成员变量
double CTradeAnalyzer::m_rangeHigh = 0.0;
double CTradeAnalyzer::m_rangeLow = 0.0;
datetime CTradeAnalyzer::m_rangeHighTime = 0;
datetime CTradeAnalyzer::m_rangeLowTime = 0;
bool CTradeAnalyzer::m_isUpTrend = false;
bool CTradeAnalyzer::m_isValid = false;
double CTradeAnalyzer::m_retracePrice = 0.0;
datetime CTradeAnalyzer::m_retraceTime = 0;
double CTradeAnalyzer::m_retracePercent = 0.0;
double CTradeAnalyzer::m_retraceDiff = 0.0;
double CTradeAnalyzer::m_support1H = 0.0;
double CTradeAnalyzer::m_support4H = 0.0;
double CTradeAnalyzer::m_supportD1 = 0.0;
double CTradeAnalyzer::m_resistance1H = 0.0;
double CTradeAnalyzer::m_resistance4H = 0.0;
double CTradeAnalyzer::m_resistanceD1 = 0.0;
datetime CTradeAnalyzer::m_support1HTime = 0;
datetime CTradeAnalyzer::m_support4HTime = 0;
datetime CTradeAnalyzer::m_supportD1Time = 0;
datetime CTradeAnalyzer::m_resistance1HTime = 0;
datetime CTradeAnalyzer::m_resistance4HTime = 0;
datetime CTradeAnalyzer::m_resistanceD1Time = 0;

