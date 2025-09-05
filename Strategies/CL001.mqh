//+------------------------------------------------------------------+
//|                                                    CL001.mqh     |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property strict

/*
策略名称：回撤挂单策略
策略说明：
1. 当价格回撤但未超过最近周期(M5)第一个线段开始点价格时
2. 进场点=开始点价格+3点
3. 止损点=开始点价格
4. 止盈点=开始点价格+9点
5. 适用于做多交易
*/

#include <Trade/Trade.mqh>
#include <Trade/OrderInfo.mqh>
#include <Trade/PositionInfo.mqh>

// 策略状态枚举(中文描述)
enum ENUM_STRATEGY_STATE
{
   STRATEGY_IDLE_WAITING_CONDITION,    // 策略空闲状态，等待交易条件满足
   STRATEGY_PENDING_ORDER_PLACED,      // 已生成限价挂单，等待价格触发成交
   STRATEGY_ACTIVE_POSITION_MONITOR,  // 订单已成交变为持仓，正在监控价格波动
   STRATEGY_COMPLETED_CLOSED          // 策略已完成(止盈/止损/手动平仓)
};

class CStrategyCL001
{
private:
   CTrade m_trade;
   ENUM_STRATEGY_STATE m_state; // 当前策略状态
   ulong m_orderTicket;        // 挂单票号
   ulong m_positionTicket;     // 持仓票号
   double m_referencePrice;    // 参考价格(开始点价格)
   
public:
   CStrategyCL001() : m_state(STRATEGY_IDLE_WAITING_CONDITION), 
                      m_orderTicket(0),
                      m_positionTicket(0),
                      m_referencePrice(0) {}
   
   // 获取当前策略状态
   ENUM_STRATEGY_STATE GetState() const { return m_state; }
   
   // 检查策略条件是否满足
   bool CheckConditions(CTradeBasePoint &tradeBasePoint)
   {
      // 如果已有挂单或持仓，不再重复检查
      if(m_state != STRATEGY_IDLE_WAITING_CONDITION)
         return false;
         
      // 获取M5周期的第一个线段开始点价格
      CZigzagSegment* m5Segments[];
      if(tradeBasePoint.m_leftSegmentsStore.GetArray(0, m5Segments) && ArraySize(m5Segments) > 0)
      {
         m_referencePrice = m5Segments[0].m_start_point.value;
         double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
         
         // 条件：当前价格高于开始点价格
         return (currentPrice > m_referencePrice);
      }
      return false;
   }
   
   // 执行策略
   void Execute(CTradeBasePoint &tradeBasePoint)
   {
      // 检查并更新状态
      CheckStrategyStatus();
      
      switch(m_state)
      {
         case STRATEGY_IDLE_WAITING_CONDITION:
            ExecuteNewOrder(tradeBasePoint);
            break;
            
         case STRATEGY_PENDING_ORDER_PLACED:
            // 挂单待入场状态，等待即可
            break;
            
         case STRATEGY_ACTIVE_POSITION_MONITOR:
            MonitorPosition();
            break;
            
         case STRATEGY_COMPLETED_CLOSED:
            // 策略已完成，不做任何操作
            break;
      }
   }
   
private:
   // 执行新挂单
   void ExecuteNewOrder(CTradeBasePoint &tradeBasePoint)
   {
      if(!CheckConditions(tradeBasePoint))
         return;
         
      // 获取M5周期的第一个线段开始点价格
      CZigzagSegment* m5Segments[];
      if(tradeBasePoint.m_leftSegmentsStore.GetArray(0, m5Segments) && ArraySize(m5Segments) > 0)
      {
         m_referencePrice = m5Segments[0].m_start_point.value;
         
         // 检查是否已存在相同参考点的挂单
         if(HasPendingOrderForReference(m_referencePrice))
         {
            Print("CL001策略: 已存在相同参考点的挂单，不再重复创建");
            return;
         }
         
         // 计算交易参数
         double entryPrice = m_referencePrice + 3 * _Point;
         double stopLoss = m_referencePrice;
         double takeProfit = m_referencePrice + 9 * _Point;
         
         // 生成挂单
         if(m_trade.BuyLimit(0.1, entryPrice, Symbol(), stopLoss, takeProfit, ORDER_TIME_GTC, 0, "CL001 Strategy"))
         {
            m_orderTicket = m_trade.ResultOrder();
            m_state = STRATEGY_PENDING_ORDER_PLACED;
            Print("CL001策略挂单已生成: 进场=", entryPrice, " 止损=", stopLoss, " 止盈=", takeProfit);
         }
         else
         {
            Print("CL001策略挂单失败: ", GetLastError());
         }
      }
   }
   
   // 检查并更新策略状态
   void CheckStrategyStatus()
   {
      COrderInfo orderInfo;
      CPositionInfo positionInfo;
      
      switch(m_state)
      {
         case STRATEGY_PENDING_ORDER_PLACED:
            // 检查挂单是否已成交
            if(orderInfo.Select(m_orderTicket))
            {
               if(orderInfo.State() == ORDER_STATE_FILLED)
               {
                  m_positionTicket = positionInfo.Ticket();
                  m_state = STRATEGY_ACTIVE_POSITION_MONITOR;
                  Print("CL001策略: 挂单已成交，开始监控持仓");
               }
               else if(orderInfo.State() == ORDER_STATE_CANCELED ||
                      orderInfo.State() == ORDER_STATE_REJECTED)
               {
                  m_state = STRATEGY_IDLE_WAITING_CONDITION;
                  Print("CL001策略: 挂单已取消/拒绝，重置状态");
               }
            }
            break;
            
         case STRATEGY_ACTIVE_POSITION_MONITOR:
            // 检查持仓是否已平仓
            if(!positionInfo.Select(m_positionTicket))
            {
               m_state = STRATEGY_COMPLETED_CLOSED;
               Print("CL001策略: 持仓已平仓，策略完成");
            }
            break;
      }
   }
   
   // 监控持仓状态
   void MonitorPosition()
   {
      // 这里可以添加额外的持仓监控逻辑
      // 例如：移动止损、部分平仓等
   }
   
   // 检查是否已存在相同参考点的挂单
   bool HasPendingOrderForReference(double referencePrice)
   {
      COrderInfo orderInfo;
      int total = OrdersTotal();
      
      for(int i = total-1; i >= 0; i--)
      {
         if(orderInfo.SelectByIndex(i) && 
            orderInfo.Symbol() == Symbol() && 
            orderInfo.OrderType() == ORDER_TYPE_BUY_LIMIT &&
            StringFind(orderInfo.Comment(), "CL001 Strategy") != -1)
         {
            // 检查挂单的止损价是否与参考点相同
            if(MathAbs(orderInfo.StopLoss() - referencePrice) < 0.00001)
            {
               return true;
            }
         }
      }
      return false;
   }
};
