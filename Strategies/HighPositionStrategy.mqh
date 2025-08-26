//+------------------------------------------------------------------+
//|                                         HighPositionStrategy.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      ""

// 引入必要的头文件
#include "../EnumDefinitions.mqh"
#include "../ZigzagExtremumPoint.mqh"
#include "../ZigzagSegment.mqh"
#include "../TradeAnalyzer.mqh"
#include "../GlobalInstances.mqh"

//+------------------------------------------------------------------+
//| 高位交易策略类                                                    |
//+------------------------------------------------------------------+
class CHighPositionStrategy
{
private:
   // 策略参数
   double            m_stopLoss;           // 止损点数
   double            m_takeProfit;         // 止盈点数
   int               m_maxBars;            // 最大查找K线数
   
   // 内部状态
   bool              m_isMonitoring;       // 是否正在监控价格
   ENUM_TRADE_TYPE   m_currentTradeType;   // 当前交易类型
   double            m_entryPrice;         // 入场价格
   double            m_exitPrice;          // 出场价格
   double            m_stopLossPrice;      // 止损价格
   double            m_takeProfitPrice;    // 止盈价格

public:
                     CHighPositionStrategy(double stopLoss = 100.0, double takeProfit = 200.0, int maxBars = 200);
                    ~CHighPositionStrategy();
   
   // 检查入场条件
   bool              CheckEntryCondition(CZigzagExtremumPoint &points[], int pointCount);
   
   // 开始监控进场价格
   bool              StartEntryPriceMonitoring(double entryPrice, ENUM_TRADE_TYPE tradeType);
   
   // 停止监控进场价格
   void              StopEntryPriceMonitoring();
   
   // 检查是否达到进场价格
   bool              CheckEntryPriceReached(double currentPrice);
   
   // 开始监控出场价格
   bool              StartExitPriceMonitoring(double exitPrice);
   
   // 停止监控出场价格
   void              StopExitPriceMonitoring();
   
   // 检查是否达到出场价格
   bool              CheckExitPriceReached(double currentPrice);
   
   // 是否正在监控价格
   bool              IsMonitoring() const { return m_isMonitoring; }
   
   // 获取交易信息
   ENUM_TRADE_TYPE   GetTradeType() const { return m_currentTradeType; }
   double            GetEntryPrice() const { return m_entryPrice; }
   double            GetExitPrice() const { return m_exitPrice; }
   double            GetStopLossPrice() const { return m_stopLossPrice; }
   double            GetTakeProfitPrice() const { return m_takeProfitPrice; }
};

//+------------------------------------------------------------------+
//| 构造函数                                                          |
//+------------------------------------------------------------------+
CHighPositionStrategy::CHighPositionStrategy(double stopLoss = 100.0, double takeProfit = 200.0, int maxBars = 200)
{
   m_stopLoss = stopLoss;
   m_takeProfit = takeProfit;
   m_maxBars = maxBars;
   
   m_isMonitoring = false;
   m_currentTradeType = TRADE_TYPE_NONE;
   m_entryPrice = 0.0;
   m_exitPrice = 0.0;
   m_stopLossPrice = 0.0;
   m_takeProfitPrice = 0.0;
}

//+------------------------------------------------------------------+
//| 析构函数                                                          |
//+------------------------------------------------------------------+
CHighPositionStrategy::~CHighPositionStrategy()
{
   // 清理资源
}

//+------------------------------------------------------------------+
//| 检查入场条件                                                      |
//+------------------------------------------------------------------+
bool CHighPositionStrategy::CheckEntryCondition(CZigzagExtremumPoint &points[], int pointCount)
{
   // 重置交易信息
   m_currentTradeType = TRADE_TYPE_NONE;
   m_entryPrice = 0.0;
   m_stopLossPrice = 0.0;
   m_takeProfitPrice = 0.0;
   
   // 检查点数是否足够
   if(pointCount < 2)
      return false;
      
   // 首先使用TradeAnalyzer分析市场区间和趋势
   if(!g_tradeAnalyzer.AnalyzeRange(points, pointCount))
      return false;
      
   // 获取回撤或反弹百分比
   double retracePercent = g_tradeAnalyzer.GetRetracePercent();
   
   // 检查是否在高位区间（0%到33.3%之间）
   if(retracePercent >= 0.0 && retracePercent < 33.3)
   {
      // 根据趋势方向确定交易类型
      if(g_tradeAnalyzer.IsUpTrend())
      {
         // 上涨趋势中的回撤，考虑做多
         m_currentTradeType = TRADE_TYPE_BUY;
         
         // 设置进场价格为回撤价格
         m_entryPrice = g_tradeAnalyzer.GetRetracePrice();
         
         // 设置止损和止盈价格
         m_stopLossPrice = m_entryPrice - m_stopLoss * _Point;
         m_takeProfitPrice = m_entryPrice + m_takeProfit * _Point;
         
         return true;
      }
      else
      {
         // 下跌趋势中的反弹，考虑做空
         m_currentTradeType = TRADE_TYPE_SELL;
         
         // 设置进场价格为反弹价格
         m_entryPrice = g_tradeAnalyzer.GetRetracePrice();
         
         // 设置止损和止盈价格
         m_stopLossPrice = m_entryPrice + m_stopLoss * _Point;
         m_takeProfitPrice = m_entryPrice - m_takeProfit * _Point;
         
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| 开始监控进场价格                                                  |
//+------------------------------------------------------------------+
bool CHighPositionStrategy::StartEntryPriceMonitoring(double entryPrice, ENUM_TRADE_TYPE tradeType)
{
   if(m_isMonitoring)
      return false; // 已经在监控中
      
   m_entryPrice = entryPrice;
   m_currentTradeType = tradeType;
   m_isMonitoring = true;
   
   // 设置止损和止盈价格
   if(m_currentTradeType == TRADE_TYPE_BUY)
   {
      m_stopLossPrice = m_entryPrice - m_stopLoss * _Point;
      m_takeProfitPrice = m_entryPrice + m_takeProfit * _Point;
   }
   else if(m_currentTradeType == TRADE_TYPE_SELL)
   {
      m_stopLossPrice = m_entryPrice + m_stopLoss * _Point;
      m_takeProfitPrice = m_entryPrice - m_takeProfit * _Point;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| 停止监控进场价格                                                  |
//+------------------------------------------------------------------+
void CHighPositionStrategy::StopEntryPriceMonitoring()
{
   m_isMonitoring = false;
}

//+------------------------------------------------------------------+
//| 检查是否达到进场价格                                              |
//+------------------------------------------------------------------+
bool CHighPositionStrategy::CheckEntryPriceReached(double currentPrice)
{
   if(!m_isMonitoring)
      return false;
      
   // 根据交易类型检查是否达到进场价格
   if(m_currentTradeType == TRADE_TYPE_BUY)
   {
      // 做多，当前价格低于等于进场价格时触发
      return currentPrice <= m_entryPrice;
   }
   else if(m_currentTradeType == TRADE_TYPE_SELL)
   {
      // 做空，当前价格高于等于进场价格时触发
      return currentPrice >= m_entryPrice;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| 开始监控出场价格                                                  |
//+------------------------------------------------------------------+
bool CHighPositionStrategy::StartExitPriceMonitoring(double exitPrice)
{
   if(!m_isMonitoring)
      return false;
      
   m_exitPrice = exitPrice;
   return true;
}

//+------------------------------------------------------------------+
//| 停止监控出场价格                                                  |
//+------------------------------------------------------------------+
void CHighPositionStrategy::StopExitPriceMonitoring()
{
   m_exitPrice = 0.0;
}

//+------------------------------------------------------------------+
//| 检查是否达到出场价格                                              |
//+------------------------------------------------------------------+
bool CHighPositionStrategy::CheckExitPriceReached(double currentPrice)
{
   if(!m_isMonitoring || m_exitPrice == 0.0)
      return false;
      
   // 检查是否达到止损或止盈价格
   if(m_currentTradeType == TRADE_TYPE_BUY)
   {
      // 做多，当前价格低于等于止损价格或高于等于止盈价格时触发
      return (currentPrice <= m_stopLossPrice) || (currentPrice >= m_takeProfitPrice);
   }
   else if(m_currentTradeType == TRADE_TYPE_SELL)
   {
      // 做空，当前价格高于等于止损价格或低于等于止盈价格时触发
      return (currentPrice >= m_stopLossPrice) || (currentPrice <= m_takeProfitPrice);
   }
   
   return false;
}
//+------------------------------------------------------------------+