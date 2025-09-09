//+------------------------------------------------------------------+
//|                                                    CL001.mqh     |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property strict

/*
策略名称：双起点挂单策略
策略说明：
1. 当1小时线段方向为上涨且参考交易点时K线序号在3以内
2. 从右向线段中获取5分钟下跌线段的最低点
3. 当前价格高于5分钟和15分钟线段起点价格
4. 同时挂两个进场单：
   - 主进场点=5分钟起点价格+EntryOffset点
   - 副进场点=15分钟起点价格+EntryOffset点
5. 止损点分别为对应起点价格
6. 止盈点分别为对应起点价格+TakeProfitOffset点
7. 适用于做多交易
*/

input int EntryOffset = 3000;      // 进场点偏移点数(默认3000点)
input int TakeProfitOffset = 9000; // 止盈点偏移点数(默认9000点)
input double LotSize = 0.1;        // 交易手数(默认0.1手)

// 策略状态枚举
enum ENUM_STRATEGY_STATE
{
   STRATEGY_IDLE_WAITING_CONDITION,    // 策略空闲状态，等待交易条件满足
   STRATEGY_PENDING_ORDER_PLACED,      // 已生成限价挂单，等待价格触发成交
   STRATEGY_ACTIVE_POSITION_MONITOR,  // 订单已成交变为持仓，正在监控价格波动
   STRATEGY_COMPLETED_CLOSED           // 策略已完成(止盈/止损/手动平仓)
};

#include <Trade/Trade.mqh>
#include <Trade/OrderInfo.mqh>
#include <Trade/PositionInfo.mqh>

class CStrategyCL001
{
private:
   CTrade m_trade;
   ENUM_STRATEGY_STATE m_state;
   ulong m_orderTicket;
   ulong m_secondaryOrderTicket;
   ulong m_positionTicket;
   double m_referencePrice;
   double m_secondaryReferencePrice;
   
public:
   CStrategyCL001() : m_state(STRATEGY_IDLE_WAITING_CONDITION), 
                     m_orderTicket(0),
                     m_secondaryOrderTicket(0),
                     m_positionTicket(0),
                     m_referencePrice(0),
                     m_secondaryReferencePrice(0) {}
   
   string GetStrategyName() const { return "CL001"; }
   string GetStrategyDescription() const { return "双起点挂单策略"; }
   
   ENUM_STRATEGY_STATE GetState() const { return m_state; }
   
   bool CheckConditions(CTradeBasePoint &tradeBasePoint)
   {
      if(m_state != STRATEGY_IDLE_WAITING_CONDITION)
         return false;
         
      CZigzagSegment* m5Segments[], *m15Segments[], *localH1Segments[];
      if(tradeBasePoint.m_leftSegmentsStore.GetArray(0, m5Segments) && ArraySize(m5Segments) > 0 &&
         tradeBasePoint.m_leftSegmentsStore.GetArray(1, m15Segments) && ArraySize(m15Segments) > 0 &&
         tradeBasePoint.m_leftSegmentsStore.GetArray(3, h1Segments) && ArraySize(h1Segments) > 0)
      {
         // 检查1小时线段方向为上涨
         if(localH1Segments[0].IsUptrend())
         {
            // 检查参考交易点的时K线序号在3以内
            if(tradeBasePoint.GetBarIndex() <= 3)
            {
               // 从右向线段中获取5分钟下跌线段的最低点,如果未有5分钟右向线段则说明行情强势
               CZigzagSegment* rightM5Segments[];
               if(tradeBasePoint.m_rightSegmentsStore.GetArray(0, rightM5Segments) && ArraySize(rightM5Segments) > 0)
               {
                  double minDownPrice = DBL_MAX;
                  for(int i=0; i<ArraySize(rightM5Segments); i++)
                  {
                     if(rightM5Segments[i].IsDowntrend())
                     {
                        minDownPrice = MathMin(minDownPrice, rightM5Segments[i].m_end_point.value);
                     }
                  }
                  
                  if(minDownPrice != DBL_MAX && 
                     SymbolInfoDouble(Symbol(), SYMBOL_BID) > minDownPrice &&
                     SymbolInfoDouble(Symbol(), SYMBOL_BID) > m5Segments[0].m_start_point.value &&
                     SymbolInfoDouble(Symbol(), SYMBOL_BID) > m15Segments[0].m_start_point.value)
                  {
                     m_referencePrice = m5Segments[0].m_start_point.value;
                     m_secondaryReferencePrice = m15Segments[0].m_start_point.value;
                     m_state = STRATEGY_PENDING_ORDER_PLACED;
                     return true;
                  }
               }
               else
               {
                  //补右向线段为0时，即强势行情的，寻找1分钟右向K线段，至少出现2根以上线段，
                 // 即（到至少出现在1个下跌，1个上升）这个时候才允许定位到下跌线段的的低点，
                 // 做为进场的点参考点。（要考虑幅度，后续做为参数，这个线段允许幅度是多少应该是个范围，不能太大也不能太小）
               }
            }
         }
      }
      return false;
   }
   
   void Execute(CTradeBasePoint &tradeBasePoint)
   {
      CheckStrategyStatus();
      
      switch(m_state)
      {
         case STRATEGY_IDLE_WAITING_CONDITION:
            break;
            
         case STRATEGY_PENDING_ORDER_PLACED:
            ExecuteNewOrder(tradeBasePoint);
            break;
            
         case STRATEGY_ACTIVE_POSITION_MONITOR:
            MonitorPosition();
            break;
            
         case STRATEGY_COMPLETED_CLOSED:
            break;
      }
   }
   
private:
   void ExecuteNewOrder(CTradeBasePoint &tradeBasePoint)
   {
      if(!CheckConditions(tradeBasePoint))
         return;
         
      CZigzagSegment* m5Segments[];
      if(tradeBasePoint.m_leftSegmentsStore.GetArray(0, m5Segments) && ArraySize(m5Segments) > 0)
      {
         // 主挂单(基于5分钟起点)
         double entryPrice = m_referencePrice + EntryOffset * _Point;
         double stopLoss = m_referencePrice;
         double takeProfit = m_referencePrice + TakeProfitOffset * _Point;
         
         if(m_trade.BuyLimit(LotSize, entryPrice, Symbol(), stopLoss, takeProfit, ORDER_TIME_GTC, 0, "CL001 Strategy (M5)"))
         {
            m_orderTicket = m_trade.ResultOrder();
            Print("CL001策略主挂单已生成(基于M5): 进场=", DoubleToString(entryPrice, _Digits), " 止损=", DoubleToString(stopLoss, _Digits), " 止盈=", DoubleToString(takeProfit, _Digits));
            
            // 副挂单(基于15分钟起点)
            double secondaryEntryPrice = m_secondaryReferencePrice + EntryOffset * _Point;
            double secondaryStopLoss = m_secondaryReferencePrice;
            double secondaryTakeProfit = m_secondaryReferencePrice + TakeProfitOffset * _Point;
            
            if(m_trade.BuyLimit(LotSize, secondaryEntryPrice, Symbol(), secondaryStopLoss, secondaryTakeProfit, ORDER_TIME_GTC, 0, "CL001 Strategy (M15)"))
            {
               m_secondaryOrderTicket = m_trade.ResultOrder();
               Print("CL001策略副挂单已生成(基于M15): 进场=", DoubleToString(secondaryEntryPrice, _Digits), " 止损=", DoubleToString(secondaryStopLoss, _Digits), " 止盈=", DoubleToString(secondaryTakeProfit, _Digits));
            }
         }
      }
   }
   
   void CheckStrategyStatus()
   {
      COrderInfo orderInfo;
      CPositionInfo positionInfo;
      
      switch(m_state)
      {
         case STRATEGY_PENDING_ORDER_PLACED:
            if(orderInfo.Select(m_orderTicket))
            {
               if(orderInfo.State() == ORDER_STATE_FILLED)
               {
                  m_positionTicket = positionInfo.Ticket();
                  m_state = STRATEGY_ACTIVE_POSITION_MONITOR;
               }
               else if(orderInfo.State() == ORDER_STATE_CANCELED || orderInfo.State() == ORDER_STATE_REJECTED)
               {
                  m_state = STRATEGY_IDLE_WAITING_CONDITION;
               }
            }
            break;
            
         case STRATEGY_ACTIVE_POSITION_MONITOR:
            if(!positionInfo.Select(m_positionTicket))
            {
               m_state = STRATEGY_COMPLETED_CLOSED;
            }
            break;
      }
   }
   
   void MonitorPosition()
   {
      // 持仓监控逻辑
   }
};