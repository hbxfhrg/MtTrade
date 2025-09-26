//+------------------------------------------------------------------+
//|                                                    CL001.mqh     |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property strict

/*
策略名称：新突破行情5分钟追方向策略
策略说明：
1. 当1小时线段方向为上涨且参考交易点时K线序号在3以内
2. 从右向线段中获取5分钟下跌线段的最低点
3. 根据右向线段最低价格相对于M5和M15起点价格的位置分三种情况：
   - 情况1：最低价格在M5和M15起点之上（强势行情）
   - 情况2：最低价格在M15起点之上但在M5起点之下（中等强度行情）
   - 情况3：最低价格在M15起点之下（弱势行情）
4. 特殊处理：当M5右向线段数量为2时使用特殊挂单逻辑
5. 止损和止盈根据线段起点和终点计算
6. 适用于做多交易
*/

input int EntryOffset = 3000;      // 进场点偏移点数(默认3000点)
input int StopLossOffset = 3000;   // 止损点偏移点数(默认3000点)
input int TakeProfitOffset = 9000; // 止盈点偏移点数(默认9000点)
input double LotSize = 0.1;        // 交易手数(默认0.1手)
input int OrderExpiryHours = 24;   // 挂单有效时间(小时，默认24小时)



#include <Trade/Trade.mqh>
#include <Trade/OrderInfo.mqh>
#include <Trade/PositionInfo.mqh>
#include "../Database/DatabaseManager.mqh"

class CStrategyCL001
{
protected:  // 修改为protected以允许子类访问
   CTrade m_trade; 
   ulong m_orderTicket;
   ulong m_secondaryOrderTicket;
   ulong m_positionTicket;
   double m_referencePrice;
   double m_secondaryReferencePrice;
   
public:
   CStrategyCL001() : m_orderTicket(0),
                     m_secondaryOrderTicket(0),
                     m_positionTicket(0),
                     m_referencePrice(0),
                     m_secondaryReferencePrice(0) {}
   
   string GetStrategyName() const { return "CL001"; }
   string GetStrategyDescription() const { return "新突破行情5分钟追方向策略"; }

   // 修改挂单价格
   bool ModifyOrderPrice(ulong ticket, double newPrice)
   {
      if(m_trade.OrderModify(ticket, newPrice, 0, 0, 0, "CL001 Modified"))
      {
         m_orderTicket = ticket;
         return true;
      }
      return false;
   }

   // 基于行情取消订单(无参数版本)
   bool CancelOrderByMarket()
   {
      COrderInfo orderInfo;
      // 遍历所有订单查找本策略的挂单
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         if(orderInfo.SelectByIndex(i) && 
            orderInfo.Symbol() == Symbol() && 
            orderInfo.OrderType() == ORDER_TYPE_BUY_LIMIT &&
            StringFind(orderInfo.Comment(), "CL001_") != -1)
         {
            // 计算从挂单时间后的最高价
            int startBar = iBarShift(Symbol(), PERIOD_CURRENT, orderInfo.TimeSetup());
            double highestPrice = 0;
            for(int j = startBar; j >= 0; j--)
            {
               highestPrice = MathMax(highestPrice, iHigh(Symbol(), PERIOD_CURRENT, j));
            }
            if(highestPrice > orderInfo.TakeProfit())
            {
               Print("取消订单: 最高价", highestPrice, "已超过止盈价", orderInfo.TakeProfit());
               return m_trade.OrderDelete(orderInfo.Ticket());
            }
         }
      }
      return false;
   }

   // 基于行情关闭订单
   bool ClosePositionByMarket(ulong ticket, double currentPrice, double threshold)
   {
      CPositionInfo positionInfo;
      if(positionInfo.Select(ticket))
      {
         if(MathAbs(positionInfo.PriceOpen() - currentPrice) > threshold * _Point)
         {
            return m_trade.PositionClose(ticket);
         }
      }
      return false;
   }
   
   bool CheckConditions(CTradeBasePoint &tradeBasePoint)
   {
      CZigzagSegment* m5Segments[], *m15Segments[], *h1SegmentsLocal[];
      if(tradeBasePoint.m_leftSegmentsStore.GetArray(0, m5Segments) && ArraySize(m5Segments) > 0 &&
         tradeBasePoint.m_leftSegmentsStore.GetArray(1, m15Segments) && ArraySize(m15Segments) > 0 &&
         tradeBasePoint.m_leftSegmentsStore.GetArray(3, h1SegmentsLocal) && ArraySize(h1SegmentsLocal) > 0)
      {
         // 检查1小时线段方向为上涨
         // 输出H1线段详细信息
         bool isH1Uptrend = h1SegmentsLocal[0].IsUptrend();
         double h1StartPrice = h1SegmentsLocal[0].m_start_point.value;
         double h1EndPrice = h1SegmentsLocal[0].m_end_point.value;
         string h1Direction = isH1Uptrend ? "上涨↑" : "下跌↓";
         
         // 获取右侧线段数量
         CZigzagSegment* m5RightSegments[], *m15RightSegments[], *h1RightSegments[];
         int m5RightCount = 0, m15RightCount = 0, h1RightCount = 0;
         if(tradeBasePoint.m_rightSegmentsStore.GetArray(0, m5RightSegments)) m5RightCount = ArraySize(m5RightSegments);
         if(tradeBasePoint.m_rightSegmentsStore.GetArray(1, m15RightSegments)) m15RightCount = ArraySize(m15RightSegments);
         if(tradeBasePoint.m_rightSegmentsStore.GetArray(3, h1RightSegments)) h1RightCount = ArraySize(h1RightSegments);
         
         Print(StringFormat("CL001: H1线段方向=%s, 开始价格=%.5f, 结束价格=%.5f", h1Direction, h1StartPrice, h1EndPrice));
         Print(StringFormat("CL001: 右侧线段数量 - M5:%d, M15:%d, H1:%d", m5RightCount, m15RightCount, h1RightCount));
         
         // 当M5右侧线段数量为2时，输出额外信息
         if(m5RightCount == 2)
         {
            int h1Index = tradeBasePoint.GetBarIndex();
            Print(StringFormat("CL001: M5右侧线段数量为2 - tradeBasePoint信息: H1线段索引=%d", h1Index));
         }
         
         if(isH1Uptrend)
         {
            // 检查参考交易点的时K线序号在8以内
            int barIndex = tradeBasePoint.GetBarIndex();
            if(barIndex <= 3)
            {
               Print("CL001: K线序号 ", barIndex, " 在3以内");
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
                           // 使用第一个线段的终点作为参考点，直接生成挂单
                           double entryPrice = rightM5Segments[0].m_end_point.value;
                           double stopLoss = rightM5Segments[0].m_end_point.value - StopLossOffset * _Point;
                           double takeProfit = rightM5Segments[0].m_start_point.value;
                           
                           // 检查是否已存在相同点位的挂单
                           if(HasExistingOrderAtPrice(entryPrice, stopLoss))
                           {
                              Print("CL001策略: 已存在相同点位的挂单，跳过重复挂单 进场=", DoubleToString(entryPrice, _Digits), " 止损=", DoubleToString(stopLoss, _Digits));
                              return false;
                           }
                         
                           
                           // 计算过期时间（当前时间 + OrderExpiryHours小时）
                           datetime expiryTime = TimeCurrent() + (OrderExpiryHours * 3600);
                           
                           // 使用"CL001_" + 订单票据作为备注
                           string orderComment = StringFormat("CL001_%d", (int)TimeCurrent());
                           
                           if(m_trade.BuyLimit(LotSize, entryPrice, NULL, stopLoss, takeProfit, ORDER_TIME_SPECIFIED, expiryTime, orderComment))
                           {
                              // 获取并验证订单票据
                              m_orderTicket = m_trade.ResultOrder();                            
                              
                              Print("CL001策略特殊挂单已生成: 订单号=", m_orderTicket, 
                                   " 进场=", DoubleToString(entryPrice, _Digits), 
                                   " 止损=", DoubleToString(stopLoss, _Digits), 
                                   " 止盈=", DoubleToString(takeProfit, _Digits));
                              
                              // 检查并关闭价格更高的旧挂单(仅限本策略)
                              COrderInfo orderInfo;
                              for(int k = OrdersTotal() - 1; k >= 0; k--)
                              {
                                 if(orderInfo.SelectByIndex(k) && 
                                    orderInfo.Symbol() == Symbol() && 
                                    orderInfo.OrderType() == ORDER_TYPE_BUY_LIMIT &&
                                    orderInfo.PriceOpen() > entryPrice &&
                                    StringFind(orderInfo.Comment(), "CL001") != -1)
                                 {
                                    m_trade.OrderDelete(orderInfo.Ticket());
                                    Print("关闭本策略旧挂单: 价格=", DoubleToString(orderInfo.PriceOpen(), _Digits));
                                 }
                              }
                              return true;
                           }
                           return false;

                        }
                     
                     }
                     else if(minDownPrice > m15StartPrice && minDownPrice <= m5StartPrice)
                     {
                        // 情况2：最低价格在M15起点之上但在M5起点之下（中等强度行情）
                        m_referencePrice = minDownPrice;  // 使用右向线段最低点作为参考
                        m_secondaryReferencePrice = m15StartPrice;
                        Print("CL001: 中等强度行情 - 最低价格在M15之上但M5之下");
                        return true;
                     }
                     else if(minDownPrice <= m15StartPrice)
                     {
                        // 情况3：最低价格在M15起点之下（弱势行情）
                        m_referencePrice = minDownPrice;  // 使用右向线段最低点作为参考
                        m_secondaryReferencePrice = minDownPrice; // 副参考点也使用最低点
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
     CheckConditions(tradeBasePoint);
    
    // 检查并取消不符合条件的订单
    CancelOrderByMarket();
      
       
   }
   
  
 
private:

   

   bool HasExistingOrderAtPrice(double entryPrice, double stopLoss)
   {
      COrderInfo orderInfo;
      CPositionInfo positionInfo;
      
      // 检查挂单
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         if(orderInfo.SelectByIndex(i))
         {
            if(orderInfo.Symbol() == Symbol() && 
               orderInfo.OrderType() == ORDER_TYPE_BUY_LIMIT &&
               MathAbs(orderInfo.PriceOpen() - entryPrice) < _Point * 10 && // 允许10点误差
               MathAbs(orderInfo.StopLoss() - stopLoss) < _Point * 10)
            {
               return true;
            }
         }
      }
      
      // 检查持仓
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(positionInfo.SelectByIndex(i))
         {
            if(positionInfo.Symbol() == Symbol() && 
               positionInfo.PositionType() == POSITION_TYPE_BUY &&
               MathAbs(positionInfo.PriceOpen() - entryPrice) < _Point * 10 &&
               MathAbs(positionInfo.StopLoss() - stopLoss) < _Point * 10)
            {
               return true;
            }
         }
      }
      
      return false;
   }
   

};