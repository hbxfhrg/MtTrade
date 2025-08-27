//+------------------------------------------------------------------+
//|                                              QuickDataTest.mq5 |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

#include "CommonUtils.mqh"

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== 快速验证数据排序方式 ===");
   
   // 测试当前品种的4H周期
   string symbol = Symbol();
   ENUM_TIMEFRAMES timeframe = PERIOD_H4;
   
   // 获取前3个时间点
   datetime time0 = iTime(symbol, timeframe, 0);
   datetime time1 = iTime(symbol, timeframe, 1);
   datetime time2 = iTime(symbol, timeframe, 2);
   
   Print("iTime排序测试：");
   Print("  索引0: ", TimeToString(time0, TIME_DATE|TIME_MINUTES));
   Print("  索引1: ", TimeToString(time1, TIME_DATE|TIME_MINUTES));
   Print("  索引2: ", TimeToString(time2, TIME_DATE|TIME_MINUTES));
   
   if(time0 > time1 && time1 > time2)
   {
      Print("✓ iTime排序：从当前时间到过去时间（正确）");
   }
   else if(time0 < time1 && time1 < time2)
   {
      Print("✗ iTime排序：从过去时间到当前时间（需要调整）");
   }
   else
   {
      Print("? iTime排序：不规律或有问题");
   }
   
   // 对比CopyTime
   datetime timeArray[];
   int copied = CopyTime(symbol, timeframe, 0, 3, timeArray);
   
   if(copied >= 3)
   {
      Print("CopyTime排序测试：");
      Print("  索引0: ", TimeToString(timeArray[0], TIME_DATE|TIME_MINUTES));
      Print("  索引1: ", TimeToString(timeArray[1], TIME_DATE|TIME_MINUTES));
      Print("  索引2: ", TimeToString(timeArray[2], TIME_DATE|TIME_MINUTES));
      
      if(timeArray[0] > timeArray[1] && timeArray[1] > timeArray[2])
      {
         Print("✓ CopyTime排序：从当前时间到过去时间");
      }
      else if(timeArray[0] < timeArray[1] && timeArray[1] < timeArray[2])
      {
         Print("✗ CopyTime排序：从过去时间到当前时间");
      }
      
      // 比较两者的索引0
      if(time0 == timeArray[0])
      {
         Print("✓ iTime与CopyTime排序一致");
      }
      else
      {
         Print("✗ iTime与CopyTime排序不一致");
      }
   }
   
   // 结论
   Print("");
   if(time0 > time1)
   {
      Print("【结论】iTime、iHigh、iLow方法排序正确，无需修改");
   }
   else
   {
      Print("【结论】iTime、iHigh、iLow方法排序需要调整");
   }
   
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