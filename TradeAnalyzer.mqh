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
#include "LogUtil.mqh"
#include "SupportResistancePoint.mqh"
#include "DynamicSupportResistancePoints.mqh"
#include "EnumDefinitions.mqh"

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
   
   // 动态支撑和压力点
   static CDynamicSupportResistancePoints m_supportPoints;    // 支撑点集合
   static CDynamicSupportResistancePoints m_resistancePoints; // 压力点集合

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
      
      // 初始化动态支撑和压力点
      m_supportPoints = CDynamicSupportResistancePoints(0.0, SR_SUPPORT);
      m_resistancePoints = CDynamicSupportResistancePoints(0.0, SR_RESISTANCE);
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
         // 上涨趋势
         // 1. 计算区间高点的支撑
         m_supportPoints.Recalculate(m_rangeHigh, SR_SUPPORT_RANGE_HIGH);
         
         // 2. 如果有回撤点，计算回撤点的压力
         if(m_retracePrice > 0.0)
           {
            m_resistancePoints.Recalculate(m_retracePrice, SR_RESISTANCE_RETRACE);
           }
        }
      else
        {
         // 下跌趋势
         // 1. 计算区间低点的压力
         m_resistancePoints.Recalculate(m_rangeLow, SR_RESISTANCE_RANGE_LOW);
         
         // 2. 如果有反弹点，计算反弹点的支撑
         if(m_retracePrice > 0.0)
           {
            m_supportPoints.Recalculate(m_retracePrice, SR_SUPPORT_REBOUND);
           }
        }
     }
     
     
   // 获取指定时间周期的支撑
   static double GetSupportPrice(ENUM_TIMEFRAMES timeframe)
     {
      return m_supportPoints.GetPrice(timeframe);
     }
     
   // 获取指定时间周期的压力
   static double GetResistancePrice(ENUM_TIMEFRAMES timeframe)
     {
      return m_resistancePoints.GetPrice(timeframe);
     }
     
   // 获取指定时间周期的支撑时间
   static datetime GetSupportTime(ENUM_TIMEFRAMES timeframe)
     {
      return m_supportPoints.GetTime(timeframe);
     }
     
   // 获取指定时间周期的压力时间
   static datetime GetResistanceTime(ENUM_TIMEFRAMES timeframe)
     {
      return m_resistancePoints.GetTime(timeframe);
     }
     
   // 获取指定时间周期的支撑/压力描述
   static string GetSupportResistanceDescription(ENUM_TIMEFRAMES timeframe = PERIOD_H1, string prefix = "")
     {
      if(!m_isValid)
         return "";
         
      if(m_isUpTrend)
        {
         // 上涨趋势，显示支撑位
         string supportText = DoubleToString(m_supportPoints.GetPrice(timeframe), _Digits);
         if(timeframe == PERIOD_H1 && prefix == "")
           {
            string referenceText = DoubleToString(m_rangeHigh, _Digits);
            return "支撑：参考点" + referenceText;
           }
         else
           {
            string tfName = (timeframe == PERIOD_H1) ? "H1" : 
                           (timeframe == PERIOD_H4) ? "4H" : 
                           (timeframe == PERIOD_D1) ? "D1" : "未知";
            return prefix + tfName + "=" + supportText;
           }
        }
      else
        {
         // 下跌趋势，显示压力位
         string resistanceText = DoubleToString(m_resistancePoints.GetPrice(timeframe), _Digits);
         if(timeframe == PERIOD_H1 && prefix == "")
           {
            string referenceText = DoubleToString(m_rangeLow, _Digits);
            return "压力：参考点" + referenceText;
           }
         else
           {
            string tfName = (timeframe == PERIOD_H1) ? "H1" : 
                           (timeframe == PERIOD_H4) ? "4H" : 
                           (timeframe == PERIOD_D1) ? "D1" : "未知";
            return prefix + tfName + "=" + resistanceText;
           }
        }
     }
     
   // 以下方法保留以兼容现有代码
   static string GetSupportResistance4HDescription()
     {
      return GetSupportResistanceDescription(PERIOD_H4);
     }
     
   static string GetSupportResistanceD1Description()
     {
      return GetSupportResistanceDescription(PERIOD_D1);
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
         highTime = 0;
         return 0.0;
        }
        
      // 获取当前周期的最低点时间
      datetime lowestTime = iTime(Symbol(), Period(), lowestBarIndex);
      
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
CDynamicSupportResistancePoints CTradeAnalyzer::m_supportPoints;
CDynamicSupportResistancePoints CTradeAnalyzer::m_resistancePoints;