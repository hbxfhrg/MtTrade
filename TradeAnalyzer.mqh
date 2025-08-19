//+------------------------------------------------------------------+
//|                                                 TradeAnalyzer.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

// 引入极值点类定义
#include "ZigzagExtremumPoint.mqh"

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
         // 获取从高点时间到现在的最低价格
         m_retracePrice = currentPrice; // 初始化为当前价格
         m_retraceTime = TimeCurrent();
         
         // 遍历从高点时间到现在的K线，找出最低价
         int bars = Bars(Symbol(), PERIOD_CURRENT);
         datetime currentTime = TimeCurrent();
         
         for(int i = 0; i < bars; i++)
           {
            datetime barTime = iTime(Symbol(), PERIOD_CURRENT, i);
            
            // 如果K线时间在高点之后且在当前时间之前
            if(barTime >= m_rangeHighTime && barTime <= currentTime)
              {
               double lowPrice = iLow(Symbol(), PERIOD_CURRENT, i);
               
               // 更新最低价
               if(lowPrice < m_retracePrice)
                 {
                  m_retracePrice = lowPrice;
                  m_retraceTime = barTime;
                 }
              }
              
            // 如果K线时间早于高点时间，则停止遍历
            if(barTime < m_rangeHighTime)
               break;
           }
           
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
         // 获取从低点时间到现在的最高价格
         m_retracePrice = currentPrice; // 初始化为当前价格
         m_retraceTime = TimeCurrent();
         
         // 遍历从低点时间到现在的K线，找出最高价
         int bars = Bars(Symbol(), PERIOD_CURRENT);
         datetime currentTime = TimeCurrent();
         
         for(int i = 0; i < bars; i++)
           {
            datetime barTime = iTime(Symbol(), PERIOD_CURRENT, i);
            
            // 如果K线时间在低点之后且在当前时间之前
            if(barTime >= m_rangeLowTime && barTime <= currentTime)
              {
               double highPrice = iHigh(Symbol(), PERIOD_CURRENT, i);
               
               // 更新最高价
               if(highPrice > m_retracePrice)
                 {
                  m_retracePrice = highPrice;
                  m_retraceTime = barTime;
                 }
              }
              
            // 如果K线时间早于低点时间，则停止遍历
            if(barTime < m_rangeLowTime)
               break;
           }
           
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
         // 上涨趋势，计算支撑位
         CalculateSupport(PERIOD_H1, m_support1H);
         CalculateSupport(PERIOD_H4, m_support4H);
         CalculateSupport(PERIOD_D1, m_supportD1);
        }
      else
        {
         // 下跌趋势，计算压力位
         CalculateResistance(PERIOD_H1, m_resistance1H);
         CalculateResistance(PERIOD_H4, m_resistance4H);
         CalculateResistance(PERIOD_D1, m_resistanceD1);
        }
     }
     
   // 计算指定时间周期的支撑位
   static void CalculateSupport(ENUM_TIMEFRAMES timeframe, double &supportPrice)
     {
      // 获取当前价格
      double currentPrice = GetCurrentPrice();
      
      // 找到当前价格所在的K线
      int currentShift = 0; // 当前K线的索引
      
      // 初始化支撑价格
      supportPrice = 0.0;
      
      // 如果当前K线索引有效且至少有一根前面的K线
      if(currentShift >= 0 && currentShift + 1 < Bars(Symbol(), timeframe))
        {
         // 直接取前一根K线的最低价作为支撑位
         supportPrice = iLow(Symbol(), timeframe, currentShift + 1);
        }
      else
        {
         // 如果无法获取前一根K线，使用当前K线的最低价
         supportPrice = iLow(Symbol(), timeframe, currentShift);
        }
     }
     
   // 计算指定时间周期的压力位
   static void CalculateResistance(ENUM_TIMEFRAMES timeframe, double &resistancePrice)
     {
      // 获取当前价格
      double currentPrice = GetCurrentPrice();
      
      // 找到当前价格所在的K线
      int currentShift = 0; // 当前K线的索引
      
      // 初始化压力价格
      resistancePrice = 0.0;
      
      // 如果当前K线索引有效且至少有一根前面的K线
      if(currentShift >= 0 && currentShift + 1 < Bars(Symbol(), timeframe))
        {
         // 直接取前一根K线的最高价作为压力位
         resistancePrice = iHigh(Symbol(), timeframe, currentShift + 1);
        }
      else
        {
         // 如果无法获取前一根K线，使用当前K线的最高价
         resistancePrice = iHigh(Symbol(), timeframe, currentShift);
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
      return m_resistanceD1;
     }
     
   // 获取支撑压力描述
   static string GetSupportResistanceDescription()
     {
      if(!m_isValid)
         return "";
         
      if(m_isUpTrend)
        {
         // 上涨趋势，显示支撑位
         string support1HText = DoubleToString(m_support1H, _Digits);
         
         return "1H=" + support1HText;
        }
      else
        {
         // 下跌趋势，显示压力位
         string resistance1HText = DoubleToString(m_resistance1H, _Digits);
         
         return "1H=" + resistance1HText;
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
      
      // 不再计算价格位置百分比
      return StringFormat("区间: %s - %s (%s)", 
                         lowText, highText, direction);
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