//+------------------------------------------------------------------+
//|                                          LowPositionStrategy.mqh |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023"
#property link      ""

#include "../EnumDefinitions.mqh"
#include "../ZigzagExtremumPoint.mqh"
#include "../ZigzagSegment.mqh"
#include "../TradeAnalyzer.mqh"
#include "../GlobalInstances.mqh"

//+------------------------------------------------------------------+
//| 低位交易策略类                                                    |
//+------------------------------------------------------------------+
class CLowPositionStrategy
  {
private:
   // 策略参数
   double            m_stopLoss;           // 止损点数
   double            m_takeProfit;         // 止盈点数
   int               m_maxBars;            // 最大查找K线数
   
   // 内部状态
   bool              m_isMonitoring;       // 是否正在监控价格
   double            m_entryPrice;         // 进场价格
   double            m_exitPrice;          // 出场价格
   ENUM_TRADE_TYPE   m_currentTradeType;   // 当前交易类型(做多/做空)
   
public:
   // 构造函数
                     CLowPositionStrategy(double stopLoss = 120.0, double takeProfit = 240.0, int maxBars = 200);
   // 析构函数
                    ~CLowPositionStrategy();
   
   // 检查进场条件
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
   
   // 检查是否达到出场价格(止盈/止损)
   bool              CheckExitPriceReached(double currentPrice);
   
   // 获取当前交易状态
   bool              IsMonitoring() const { return m_isMonitoring; }
   double            GetEntryPrice() const { return m_entryPrice; }
   double            GetExitPrice() const { return m_exitPrice; }
   ENUM_TRADE_TYPE   GetTradeType() const { return m_currentTradeType; }
  };

//+------------------------------------------------------------------+
//| 构造函数                                                          |
//+------------------------------------------------------------------+
CLowPositionStrategy::CLowPositionStrategy(double stopLoss = 120.0, double takeProfit = 240.0, int maxBars = 200)
  {
   m_stopLoss = stopLoss;
   m_takeProfit = takeProfit;
   m_maxBars = maxBars;
   
   m_isMonitoring = false;
   m_entryPrice = 0.0;
   m_exitPrice = 0.0;
   m_currentTradeType = TRADE_TYPE_NONE;
  }

//+------------------------------------------------------------------+
//| 析构函数                                                          |
//+------------------------------------------------------------------+
CLowPositionStrategy::~CLowPositionStrategy()
  {
   // 清理资源
  }

//+------------------------------------------------------------------+
//| 检查进场条件                                                      |
//+------------------------------------------------------------------+
bool CLowPositionStrategy::CheckEntryCondition(CZigzagExtremumPoint &points[], int pointCount)
  {
   // 低位交易策略的进场条件逻辑
   // 低位定义：回撤或反弹幅度在66.6%到100%之间
   
   // 检查点数是否足够
   if(pointCount < 2)
      return false;
      
   // 首先使用TradeAnalyzer分析市场区间和趋势
   if(!g_tradeAnalyzer.AnalyzeRange(points, pointCount))
      return false;
      
   // 获取回撤或反弹百分比
   double retracePercent = g_tradeAnalyzer.GetRetracePercent();
   
   // 检查是否在低位区间（66.6%到100%之间）
   if(retracePercent >= 66.6 && retracePercent <= 100.0)
     {
      // 根据趋势方向确定交易类型
      if(g_tradeAnalyzer.IsUpTrend())
        {
         // 上涨趋势中的深度回撤，考虑做多
         m_currentTradeType = TRADE_TYPE_BUY;
         
         // 设置进场价格为回撤价格
         m_entryPrice = g_tradeAnalyzer.GetRetracePrice();
         
         return true;
        }
      else
        {
         // 下跌趋势中的深度反弹，考虑做空
         m_currentTradeType = TRADE_TYPE_SELL;
         
         // 设置进场价格为反弹价格
         m_entryPrice = g_tradeAnalyzer.GetRetracePrice();
         
         return true;
        }
     }
   
   return false;
  }

//+------------------------------------------------------------------+
//| 开始监控进场价格                                                  |
//+------------------------------------------------------------------+
bool CLowPositionStrategy::StartEntryPriceMonitoring(double entryPrice, ENUM_TRADE_TYPE tradeType)
  {
   if(entryPrice <= 0.0 || (tradeType != TRADE_TYPE_BUY && tradeType != TRADE_TYPE_SELL))
      return false;
      
   m_isMonitoring = true;
   m_entryPrice = entryPrice;
   m_currentTradeType = tradeType;
   
   return true;
  }

//+------------------------------------------------------------------+
//| 停止监控进场价格                                                  |
//+------------------------------------------------------------------+
void CLowPositionStrategy::StopEntryPriceMonitoring()
  {
   m_isMonitoring = false;
   m_entryPrice = 0.0;
  }

//+------------------------------------------------------------------+
//| 检查是否达到进场价格                                              |
//+------------------------------------------------------------------+
bool CLowPositionStrategy::CheckEntryPriceReached(double currentPrice)
  {
   if(!m_isMonitoring || m_entryPrice <= 0.0)
      return false;
      
   // 根据交易类型检查价格是否达到进场条件
   if(m_currentTradeType == TRADE_TYPE_BUY)
     {
      // 做多：当前价格低于等于进场价格时触发
      return currentPrice <= m_entryPrice;
     }
   else if(m_currentTradeType == TRADE_TYPE_SELL)
     {
      // 做空：当前价格高于等于进场价格时触发
      return currentPrice >= m_entryPrice;
     }
     
   return false;
  }

//+------------------------------------------------------------------+
//| 开始监控出场价格                                                  |
//+------------------------------------------------------------------+
bool CLowPositionStrategy::StartExitPriceMonitoring(double exitPrice)
  {
   if(exitPrice <= 0.0)
      return false;
      
   m_exitPrice = exitPrice;
   
   return true;
  }

//+------------------------------------------------------------------+
//| 停止监控出场价格                                                  |
//+------------------------------------------------------------------+
void CLowPositionStrategy::StopExitPriceMonitoring()
  {
   m_exitPrice = 0.0;
  }

//+------------------------------------------------------------------+
//| 检查是否达到出场价格(止盈/止损)                                   |
//+------------------------------------------------------------------+
bool CLowPositionStrategy::CheckExitPriceReached(double currentPrice)
  {
   if(m_exitPrice <= 0.0)
      return false;
      
   // 根据交易类型检查价格是否达到出场条件
   if(m_currentTradeType == TRADE_TYPE_BUY)
     {
      // 做多：当前价格高于等于止盈价格或低于等于止损价格时触发
      double takeProfitPrice = m_entryPrice + m_takeProfit * _Point;
      double stopLossPrice = m_entryPrice - m_stopLoss * _Point;
      
      return (currentPrice >= takeProfitPrice) || (currentPrice <= stopLossPrice);
     }
   else if(m_currentTradeType == TRADE_TYPE_SELL)
     {
      // 做空：当前价格低于等于止盈价格或高于等于止损价格时触发
      double takeProfitPrice = m_entryPrice - m_takeProfit * _Point;
      double stopLossPrice = m_entryPrice + m_stopLoss * _Point;
      
      return (currentPrice <= takeProfitPrice) || (currentPrice >= stopLossPrice);
     }
     
   return false;
  }
//+------------------------------------------------------------------+