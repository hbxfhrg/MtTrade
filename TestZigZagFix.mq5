//+------------------------------------------------------------------+
//|                                               TestZigZagFix.mq5 |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

#include "ZigzagCalculator.mqh"

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== 测试ZigZag偏移修复 - 多周期验证 ===");
   
   string symbol = Symbol();
   
   // 测试4小时周期
   Print("\n【4小时周期测试】");
   CZigzagCalculator* calculator4H = new CZigzagCalculator(12, 5, 3, 3, PERIOD_H4);
   bool result4H = calculator4H.CalculateForSymbol(symbol, PERIOD_H4, 100);
   
   if(result4H)
   {
      Print("✓ 4H ZigZag计算成功");
      
      // 获取4H极值点
      CZigzagExtremumPoint points4H[];
      if(calculator4H.GetRecentExtremumPoints(points4H, 5))
      {
         Print("4H极值点（前5个）:");
         for(int i = 0; i < ArraySize(points4H); i++)
         {
            Print(StringFormat("  [%d] 时间: %s, 价格: %.3f, 类型: %s",
                  i,
                  TimeToString(points4H[i].Time(), TIME_DATE|TIME_MINUTES),
                  points4H[i].Value(),
                  (points4H[i].Type() == EXTREMUM_PEAK) ? "峰值" : "谷值"));
         }
      }
   }
   else
   {
      Print("✗ 4H ZigZag计算失败");
   }
   
   delete calculator4H;
   
   // 测试1小时周期
   Print("\n【1小时周期测试】");
   CZigzagCalculator* calculator1H = new CZigzagCalculator(12, 5, 3, 3, PERIOD_H1);
   bool result1H = calculator1H.CalculateForSymbol(symbol, PERIOD_H1, 100);
   
   if(result1H)
   {
      Print("✓ 1H ZigZag计算成功");
      
      // 获取1H极值点
      CZigzagExtremumPoint points1H[];
      if(calculator1H.GetRecentExtremumPoints(points1H, 5))
      {
         Print("1H极值点（前5个）:");
         for(int i = 0; i < ArraySize(points1H); i++)
         {
            Print(StringFormat("  [%d] 时间: %s, 价格: %.3f, 类型: %s",
                  i,
                  TimeToString(points1H[i].Time(), TIME_DATE|TIME_MINUTES),
                  points1H[i].Value(),
                  (points1H[i].Type() == EXTREMUM_PEAK) ? "峰值" : "谷值"));
         }
      }
   }
   else
   {
      Print("✗ 1H ZigZag计算失败");
   }
   
   delete calculator1H;
   
   Print("\n=== 测试完成 ===");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
}