//+------------------------------------------------------------------+
//|                                               TestZigZagFix.mq5 |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

#include "ZigzagCalculator.mqh"
#include "TradeAnalyzer.mqh"
#include "CommonUtils.mqh"

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== TestZigZagFix与MyZigzag的4H极值点对比测试 ===");
   
   // 执行4H极值点对比测试
   Test4HExtremumPointsComparison();
   
   // 执行1H子线段专项测试
   Test1HSubSegmentsSpecial();
   
   Print("\n=== 所有测试完成 ===");
   
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

//+------------------------------------------------------------------+
//| 测试4H极值点对比功能                                       |
//+------------------------------------------------------------------+
void Test4HExtremumPointsComparison()
{
   Print("\n【测试1: TestZigZagFix与MyZigzag的4H极值点对比】");
   
   string symbol = Symbol();
   
   // 创建TestZigZagFix的4H计算器
   CZigzagCalculator* testCalculator4H = new CZigzagCalculator(12, 5, 3, 3, PERIOD_H4);
   bool testResult = testCalculator4H.CalculateForSymbol(symbol, PERIOD_H4, 200);
   
   // 创建MyZigzag风格的4H计算器（模拟MyZigzag中的calculator4H）
   CZigzagCalculator* myZigzagCalculator4H = new CZigzagCalculator(12, 5, 3, 3, PERIOD_H4);
   
   // 获取4H周期价格数据（模拟MyZigzag中的方式）
   double h4_high[];
   double h4_low[];
   int maxBars4H = 200;
   
   int h4_copied_high = CopyHigh(symbol, PERIOD_H4, 0, maxBars4H, h4_high);
   int h4_copied_low = CopyLow(symbol, PERIOD_H4, 0, maxBars4H, h4_low);
   
   bool myZigzagResult = false;
   if(h4_copied_high > 0 && h4_copied_low > 0)
   {
      myZigzagResult = myZigzagCalculator4H.Calculate(h4_high, h4_low, h4_copied_high, 0);
   }
   
   Print(StringFormat("ℹ TestZigZagFix计算结果: %s", testResult ? "成功" : "失败"));
   Print(StringFormat("ℹ MyZigzag方式计算结果: %s", myZigzagResult ? "成功" : "失败"));
   
   if(testResult && myZigzagResult)
   {
      // 获取TestZigZagFix的4H极值点
      CZigzagExtremumPoint testPoints4H[];
      bool testHasPoints = testCalculator4H.GetExtremumPoints(testPoints4H);
      
      // 获取MyZigzag风格的4H极值点
      CZigzagExtremumPoint myZigzagPoints4H[];
      bool myZigzagHasPoints = myZigzagCalculator4H.GetExtremumPoints(myZigzagPoints4H);
      
      Print(StringFormat("ℹ TestZigZagFix极值点数量: %d", testHasPoints ? ArraySize(testPoints4H) : 0));
      Print(StringFormat("ℹ MyZigzag极值点数量: %d", myZigzagHasPoints ? ArraySize(myZigzagPoints4H) : 0));
      
      if(testHasPoints && myZigzagHasPoints)
      {
         // 对比前5个极值点
         int compareCount = MathMin(5, MathMin(ArraySize(testPoints4H), ArraySize(myZigzagPoints4H)));
         
         Print("\n=== 4H极值点对比结果 ===");
         Print("格式: [序号] TestZigZagFix | MyZigzag");
         
         for(int i = 0; i < compareCount; i++)
         {
            string testInfo = StringFormat("%s %.5f (%s)", 
                  TimeToString(testPoints4H[i].Time(), TIME_DATE|TIME_MINUTES),
                  testPoints4H[i].Value(),
                  (testPoints4H[i].Type() == EXTREMUM_PEAK) ? "峰" : "谷");
                  
            string myZigzagInfo = StringFormat("%s %.5f (%s)", 
                  TimeToString(myZigzagPoints4H[i].Time(), TIME_DATE|TIME_MINUTES),
                  myZigzagPoints4H[i].Value(),
                  (myZigzagPoints4H[i].Type() == EXTREMUM_PEAK) ? "峰" : "谷");
            
            // 检查是否匹配
            bool timeMatch = (testPoints4H[i].Time() == myZigzagPoints4H[i].Time());
            bool priceMatch = (MathAbs(testPoints4H[i].Value() - myZigzagPoints4H[i].Value()) < 0.00001);
            bool typeMatch = (testPoints4H[i].Type() == myZigzagPoints4H[i].Type());
            
            string matchStatus = "";
            if(timeMatch && priceMatch && typeMatch)
               matchStatus = " ✓ 完全匹配";
            else if(priceMatch && typeMatch)
               matchStatus = " ≈ 价格类型匹配";
            else
               matchStatus = " ✗ 不匹配";
            
            Print(StringFormat("[%d] %s | %s%s", i, testInfo, myZigzagInfo, matchStatus));
         }
         
         // 统计匹配情况
         int perfectMatches = 0;
         int priceMatches = 0;
         
         for(int i = 0; i < compareCount; i++)
         {
            bool timeMatch = (testPoints4H[i].Time() == myZigzagPoints4H[i].Time());
            bool priceMatch = (MathAbs(testPoints4H[i].Value() - myZigzagPoints4H[i].Value()) < 0.00001);
            bool typeMatch = (testPoints4H[i].Type() == myZigzagPoints4H[i].Type());
            
            if(timeMatch && priceMatch && typeMatch)
               perfectMatches++;
            else if(priceMatch && typeMatch)
               priceMatches++;
         }
         
         Print(StringFormat("\nℹ 对比结果统计: 完全匹配 %d个, 价格类型匹配 %d个, 共对比 %d个", 
               perfectMatches, priceMatches, compareCount));
      }
      else
      {
         Print("✗ 无法获取极值点数据进行对比");
      }
   }
   else
   {
      Print("✗ 4H ZigZag计算失败，无法进行对比");
   }
   
   // 清理内存
   delete testCalculator4H;
   delete myZigzagCalculator4H;
}

//+------------------------------------------------------------------+
//| 测试1H子线段专项测试                                       |
//+------------------------------------------------------------------+
void Test1HSubSegmentsSpecial()
{
   Print("\n【测试2: 1H子线段专项测试】");
   
   string symbol = Symbol();
   
   // 创建4H计算器获取主线段
   CZigzagCalculator* calculator4H = new CZigzagCalculator(12, 5, 3, 3, PERIOD_H4);
   bool result4H = calculator4H.CalculateForSymbol(symbol, PERIOD_H4, 200);
   
   if(!result4H)
   {
      Print("✗ 4H ZigZag计算失败，无法进行1H子线段测试");
      delete calculator4H;
      return;
   }
   
   // 获取4H极值点
   CZigzagExtremumPoint points4H[];
   if(!calculator4H.GetExtremumPoints(points4H) || ArraySize(points4H) < 2)
   {
      Print("✗ 获取4H极值点失败或数量不足");
      delete calculator4H;
      return;
   }
   
   Print(StringFormat("✓ 成功获取%d个4H极值点", ArraySize(points4H)));
   
   // 初始化TradeAnalyzer
   CTradeAnalyzer tradeAnalyzer(symbol);
   tradeAnalyzer.Init();
   
   if(!tradeAnalyzer.InitializeMainSegmentsFromPoints(points4H))
   {
      Print("✗ 初始化主交易线段失败");
      delete calculator4H;
      return;
   }
   
   Print(StringFormat("✓ 成功初始化%d个主交易线段", tradeAnalyzer.GetMainTradingSegmentsCount()));
   
   // 获取当前主线段
   CZigzagSegment* currentMainSegment = tradeAnalyzer.GetCurrentSegment();
   if(currentMainSegment == NULL)
   {
      Print("✗ 获取当前主线段失败");
      delete calculator4H;
      return;
   }
   
   Print(StringFormat("✓ 当前主线段: %s 从%.5f到%.5f (%.2f点)", 
         currentMainSegment.IsUptrend() ? "上升" : "下降",
         currentMainSegment.StartPrice(),
         currentMainSegment.EndPrice(),
         MathAbs(currentMainSegment.EndPrice() - currentMainSegment.StartPrice()) / _Point));
   
   Print(StringFormat("ℹ 主线段时间: %s 到 %s", 
         TimeToString(currentMainSegment.StartTime(), TIME_DATE|TIME_MINUTES),
         TimeToString(currentMainSegment.EndTime(), TIME_DATE|TIME_MINUTES)));
   
   // 获取1H子线段
   CZigzagSegment* h1Segments[];
   bool segmentResult = currentMainSegment.GetSmallerTimeframeSegments(h1Segments, PERIOD_H1, 500);
   
   Print(StringFormat("ℹ 获取1H子线段结果: %s", segmentResult ? "成功" : "失败"));
   
   if(segmentResult && ArraySize(h1Segments) > 0)
   {
      int h1Count = ArraySize(h1Segments);
      Print(StringFormat("✓ 成功获取%d个1H子线段", h1Count));
      
      // 显示前10个1H子线段详细信息
      int displayCount = MathMin(10, h1Count);
      Print("\n=== 1H子线段详细信息 ===");
      
      for(int i = 0; i < displayCount; i++)
      {
         if(h1Segments[i] != NULL)
         {
            Print(StringFormat("[%d] %s: %.5f→%.5f (%.2f点) %s→%s", 
                  i,
                  h1Segments[i].IsUptrend() ? "上升" : "下降",
                  h1Segments[i].StartPrice(),
                  h1Segments[i].EndPrice(),
                  MathAbs(h1Segments[i].EndPrice() - h1Segments[i].StartPrice()) / _Point,
                  TimeToString(h1Segments[i].StartTime(), TIME_DATE|TIME_MINUTES),
                  TimeToString(h1Segments[i].EndTime(), TIME_DATE|TIME_MINUTES)));
         }
      }
      
      // 统计线段信息
      int uptrendCount = 0;
      int downtrendCount = 0;
      double totalMove = 0.0;
      
      for(int i = 0; i < h1Count; i++)
      {
         if(h1Segments[i] != NULL)
         {
            if(h1Segments[i].IsUptrend())
               uptrendCount++;
            else
               downtrendCount++;
               
            totalMove += MathAbs(h1Segments[i].EndPrice() - h1Segments[i].StartPrice());
         }
      }
      
      double avgMove = (h1Count > 0) ? totalMove / h1Count : 0.0;
      
      Print(StringFormat("\nℹ 1H子线段统计: 上升%d个, 下降%d个, 平均波动%.2f点", 
            uptrendCount, downtrendCount, avgMove / _Point));
      
      // 清理内存
      for(int i = 0; i < ArraySize(h1Segments); i++)
      {
         if(h1Segments[i] != NULL)
         {
            delete h1Segments[i];
            h1Segments[i] = NULL;
         }
      }
   }
   else
   {
      Print("✗ 获取1H子线段失败或数量为0");
      
      // 输出调试信息
      Print("ℹ 调试信息:");
      Print(StringFormat("  - 主线段时间范围: %s 到 %s", 
            TimeToString(currentMainSegment.StartTime(), TIME_DATE|TIME_MINUTES),
            TimeToString(currentMainSegment.EndTime(), TIME_DATE|TIME_MINUTES)));
      Print(StringFormat("  - 主线段价格范围: %.5f 到 %.5f", 
            currentMainSegment.StartPrice(),
            currentMainSegment.EndPrice()));
   }
   
   delete calculator4H;
}