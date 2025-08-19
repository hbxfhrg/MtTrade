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
      return true;
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