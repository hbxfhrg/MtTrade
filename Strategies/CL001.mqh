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
      {
         Print("CL001: 策略状态不是空闲等待条件，当前状态: ", EnumToString(m_state));
         return false;
      }
         
      CZigzagSegment* m5Segments[], *m15Segments[], *h1Segments[];
      if(tradeBasePoint.m_leftSegmentsStore.GetArray(0, m5Segments) && ArraySize(m5Segments) > 0 &&
         tradeBasePoint.m_leftSegmentsStore.GetArray(1, m15Segments) && ArraySize(m15Segments) > 0 &&
         tradeBasePoint.m_leftSegmentsStore.GetArray(3, h1Segments) && ArraySize(h1Segments) > 0)
      {
         // 检查1小时线段方向为上涨
         if(h1Segments[0].IsUptrend())
         {
            Print("CL001: H1线段方向为上涨");
            // 检查参考交易点的时K线序号在8以内
            int barIndex = tradeBasePoint.GetBarIndex();
            if(barIndex <= 8)
            {
               Print("CL001: K线序号 ", barIndex, " 在8以内");
               // 从极值右向线段中获取5分钟下跌线段的最低点
               CZigzagSegment* rightM5Segments[];
               if(tradeBasePoint.m_rightSegmentsStore.GetArray(0, rightM5Segments) && ArraySize(rightM5Segments) > 0)
               {
                  Print("CL001: 获取到M5右向线段，数量: ", ArraySize(rightM5Segments));
                  double minDownPrice = DBL_MAX;
                  for(int i=0; i<ArraySize(rightM5Segments); i++)
                  {
                     if(rightM5Segments[i].IsDowntrend())
                     {
                        minDownPrice = MathMin(minDownPrice, rightM5Segments[i].m_end_point.value);
                     }
                  }
                  
                  if(minDownPrice != DBL_MAX)
                  {
                     double m5StartPrice = m5Segments[0].m_start_point.value;
                     double m15StartPrice = m15Segments[0].m_start_point.value;
                     
                     Print("CL001: M5起点价格: ", m5StartPrice, ", M15起点价格: ", m15StartPrice, ", 最低下跌价格: ", minDownPrice);
                     
                     // 根据右向线段最低价格相对于M5和M15起点价格的位置，分三种下单逻辑
                     if(minDownPrice > m5StartPrice && minDownPrice > m15StartPrice)
                     {
                        Print("CL001: 情况1 - 最低价格在M5和M15起点之上");
                        // 情况1：最低价格在M5和M15起点价格之上（强势行情）
                        // 检查M5右向线段数量，当有且仅有两个线段时使用特殊逻辑
                        if(ArraySize(rightM5Segments) == 2)
                        {
                           // 使用第一个线段的终点作为参考点
                           m_referencePrice = rightM5Segments[0].m_end_point.value;
                           m_secondaryReferencePrice = rightM5Segments[0].m_end_point.value;
                           m_state = STRATEGY_PENDING_ORDER_PLACED;
                           Print("CL001: 强势行情特殊逻辑 - 使用第一个线段终点作为参考点");
                           return true;
                        }
                        else
                        {
                           // 默认逻辑：使用M5和M15起点价格
                           m_referencePrice = m5StartPrice;
                           m_secondaryReferencePrice = m15StartPrice;
                           m_state = STRATEGY_PENDING_ORDER_PLACED;
                           Print("CL001: 强势行情 - 最低价格在M5和M15起点之上");
                           return true;
                        }
                     }
                     else if(minDownPrice > m15StartPrice && minDownPrice <= m5StartPrice)
                     {
                        // 情况2：最低价格在M15起点之上但在M5起点之下（中等强度行情）
                        m_referencePrice = minDownPrice;  // 使用右向线段最低点作为参考
                        m_secondaryReferencePrice = m15StartPrice;
                        m_state = STRATEGY_PENDING_ORDER_PLACED;
                        Print("CL001: 中等强度行情 - 最低价格在M15之上但M5之下");
                        return true;
                     }
                     else if(minDownPrice <= m15StartPrice)
                     {
                        // 情况3：最低价格在M15起点之下（弱势行情）
                        m_referencePrice = minDownPrice;  // 使用右向线段最低点作为参考
                        m_secondaryReferencePrice = minDownPrice; // 副参考点也使用最低点
                        m_state = STRATEGY_PENDING_ORDER_PLACED;
                        Print("CL001: 弱势行情 - 最低价格在M15起点之下");
                        return true;
                     }
                  }
               }
               else
               {
                  // 没有右向线段时的处理逻辑（后续补充）
                  Print("CL001: 没有M5右向线段，需要补充1分钟线段分析逻辑");
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