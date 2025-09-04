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

class CStrategyCL001
{
private:
    CTrade m_trade;
    
public:
    // 检查策略条件是否满足
    bool CheckConditions(CTradeBasePoint &tradeBasePoint)
    {
        // 获取M5周期的第一个线段开始点价格
        CZigzagSegment* m5Segments[];
        if(tradeBasePoint.m_leftSegmentsStore.GetArray(0, m5Segments) && ArraySize(m5Segments) > 0)
        {
            double startPrice = m5Segments[0].m_start_point.value;
            double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
            
            // 条件：当前价格高于开始点价格
            return (currentPrice > startPrice);
        }
        return false;
    }
    
    // 执行策略
    void Execute(CTradeBasePoint &tradeBasePoint)
    {
        if(!CheckConditions(tradeBasePoint))
            return;
            
        // 获取M5周期的第一个线段开始点价格
        CZigzagSegment* m5Segments[];
        if(tradeBasePoint.m_leftSegmentsStore.GetArray(0, m5Segments) && ArraySize(m5Segments) > 0)
        {
            double startPrice = m5Segments[0].m_start_point.value;
            
            // 检查是否已存在相同参考点的挂单
            if(HasPendingOrderForReference(startPrice))
            {
                Print("CL001策略: 已存在相同参考点的挂单，不再重复创建");
                return;
            }
            
            // 计算交易参数
            double entryPrice = startPrice + 3 * _Point;
            double stopLoss = startPrice;
            double takeProfit = startPrice + 9 * _Point;
            
            // 生成挂单
            if(m_trade.BuyLimit(0.1, entryPrice, Symbol(), stopLoss, takeProfit, ORDER_TIME_GTC, 0, "CL001 Strategy"))
            {
                Print("CL001策略挂单已生成: 进场=", entryPrice, " 止损=", stopLoss, " 止盈=", takeProfit);
            }
            else
            {
                Print("CL001策略挂单失败: ", GetLastError());
            }
        }
    }
    
private:
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