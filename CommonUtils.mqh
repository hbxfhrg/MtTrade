//+------------------------------------------------------------------+
//|                                                   CommonUtils.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

//+------------------------------------------------------------------+
//| 通用工具类 - 提供项目中使用的各种通用方法                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 将时间周期转换为简写形式                                           |
//+------------------------------------------------------------------+
string TimeframeToString(ENUM_TIMEFRAMES timeframe)
  {
   switch(timeframe)
     {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN";
      default:         return EnumToString(timeframe);
     }
  }

//+------------------------------------------------------------------+
//| 获取时间周期的分钟数                                              |
//+------------------------------------------------------------------+
int TimeframeMinutes(ENUM_TIMEFRAMES timeframe)
  {
   switch(timeframe)
     {
      case PERIOD_M1:  return 1;
      case PERIOD_M5:  return 5;
      case PERIOD_M15: return 15;
      case PERIOD_M30: return 30;
      case PERIOD_H1:  return 60;
      case PERIOD_H4:  return 240;
      case PERIOD_D1:  return 1440;
      case PERIOD_W1:  return 10080;
      case PERIOD_MN1: return 43200;
      default:         return (int)timeframe;
     }
  }

//+------------------------------------------------------------------+
//| 获取当前图表的时间周期                                            |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetCurrentTimeframe()
  {
   return (ENUM_TIMEFRAMES)Period();
  }

//+------------------------------------------------------------------+
//| 获取当前图表的时间周期简写形式                                     |
//+------------------------------------------------------------------+
string GetCurrentTimeframeString()
  {
   return TimeframeToString(GetCurrentTimeframe());
  }

//+------------------------------------------------------------------+
//| 格式化价格，根据品种小数位数                                       |
//+------------------------------------------------------------------+
string FormatPrice(double price, int digits = -1)
  {
   if(digits < 0)
      digits = _Digits;
      
   return DoubleToString(price, digits);
  }

//+------------------------------------------------------------------+
//| 格式化日期时间                                                    |
//+------------------------------------------------------------------+
string FormatDateTime(datetime time, bool includeSeconds = true)
  {
   if(includeSeconds)
      return TimeToString(time, TIME_DATE | TIME_MINUTES | TIME_SECONDS);
   else
      return TimeToString(time, TIME_DATE | TIME_MINUTES);
  }

//+------------------------------------------------------------------+
//| 计算两个价格之间的点数差异                                         |
//+------------------------------------------------------------------+
int PriceDifferenceInPoints(double price1, double price2)
  {
   return (int)MathRound(MathAbs(price1 - price2) / _Point);
  }

//+------------------------------------------------------------------+
//| 计算两个价格之间的百分比差异                                       |
//+------------------------------------------------------------------+
double PriceDifferenceInPercent(double price1, double price2)
  {
   if(price2 == 0)
      return 0;
      
   return (price1 - price2) / price2 * 100.0;
  }

//+------------------------------------------------------------------+
//| 检查价格点是否在另一个价格点数组中出现                              |
//+------------------------------------------------------------------+
bool IsPriceInArray(double price, const CZigzagExtremumPoint &points[], double tolerance = 0.0001)
  {
   // 遍历所有极值点
   for(int i = 0; i < ArraySize(points); i++)
     {
      // 如果价格在容差范围内匹配，则认为是同一个价格点
      if(MathAbs(price - points[i].Value()) < tolerance)
        {
         return true;
        }
     }
   
   return false;
  }

//+------------------------------------------------------------------+
//| 在指定周期定位低点价格，然后向未来方向搜索最高价格                   |
//+------------------------------------------------------------------+
double FindHighestPriceAfterLowPrice(double lowPrice, datetime &highTime, ENUM_TIMEFRAMES timeframe = PERIOD_H1, ENUM_TIMEFRAMES smallerTimeframe = PERIOD_M1, datetime startTime = 0)
  {
   // 如果没有指定起始时间，使用当前时间
   if(startTime == 0)
      startTime = TimeCurrent();
      
   // 在指定周期上查找与指定价格最接近的K线
   int barIndex = -1;
   double closestPrice = DBL_MAX;
   int barsToCheck = (timeframe <= PERIOD_H1) ? 100 : 500; // 根据周期调整检查的K线数量
   
   for(int i = 0; i < barsToCheck; i++)
     {
      double low = iLow(Symbol(), timeframe, i);
      
      // 如果找到与指定价格更接近的低点
      if(MathAbs(low - lowPrice) < MathAbs(closestPrice - lowPrice))
        {
         closestPrice = low;
         barIndex = i;
        }
        
      // 如果K线时间早于起始时间，则停止查找
      if(iTime(Symbol(), timeframe, i) < startTime)
         break;
     }
   
   // 如果找不到匹配的K线
   if(barIndex < 0)
     {
      Print("无法在", EnumToString(timeframe), "周期上找到与价格 ", DoubleToString(lowPrice, _Digits), " 接近的K线");
      highTime = 0;
      return 0.0;
     }
   
   Print("在", EnumToString(timeframe), "周期上找到最接近的K线: 索引=", barIndex, ", 时间=", TimeToString(iTime(Symbol(), timeframe, barIndex)), ", 最低价=", DoubleToString(closestPrice, _Digits));
   
   // 如果是当前K线（索引为0），则切换到更小的周期
   if(barIndex == 0 && smallerTimeframe != timeframe)
     {
      // 递归调用，使用更小的周期
      return FindHighestPriceAfterLowPrice(lowPrice, highTime, smallerTimeframe, smallerTimeframe, startTime);
     }
   
   // 获取指定周期上的K线时间
   datetime barTime = iTime(Symbol(), timeframe, barIndex);
   
   // 从该K线开始向未来方向查找最高价
   double highestPrice = closestPrice;
   int highestPriceIndex = barIndex;
   int futureBarsToCheck = (timeframe <= PERIOD_H1) ? 200 : 50; // 根据周期调整检查的未来K线数量
   
   for(int i = barIndex - 1; i >= 0 && i >= barIndex - futureBarsToCheck; i--)
     {
      double high = iHigh(Symbol(), timeframe, i);
      if(high > highestPrice)
        {
         highestPrice = high;
         highestPriceIndex = i;
        }
     }
   
   // 记录最高点的时间
   highTime = iTime(Symbol(), timeframe, highestPriceIndex);
   
   Print("在", EnumToString(timeframe), "周期上找到最高点: 索引=", highestPriceIndex, ", 时间=", TimeToString(highTime), ", 价格=", DoubleToString(highestPrice, _Digits));
   
   return highestPrice;
  }

//+------------------------------------------------------------------+
//| 在指定周期定位高点价格，然后向未来方向搜索最低价格                   |
//+------------------------------------------------------------------+
double FindLowestPriceAfterHighPrice(double highPrice, datetime &lowTime, ENUM_TIMEFRAMES timeframe = PERIOD_H1, ENUM_TIMEFRAMES smallerTimeframe = PERIOD_M1, datetime startTime = 0)
  {
   // 如果没有指定起始时间，使用当前时间
   if(startTime == 0)
      startTime = TimeCurrent();
      
   // 在指定周期上查找与指定价格最接近的K线
   int barIndex = -1;
   double closestPrice = DBL_MIN;
   int barsToCheck = (timeframe <= PERIOD_H1) ? 100 : 500; // 根据周期调整检查的K线数量
   
   for(int i = 0; i < barsToCheck; i++)
     {
      double high = iHigh(Symbol(), timeframe, i);
      
      // 如果找到与指定价格更接近的高点
      if(MathAbs(high - highPrice) < MathAbs(closestPrice - highPrice))
        {
         closestPrice = high;
         barIndex = i;
        }
        
      // 如果K线时间早于起始时间，则停止查找
      if(iTime(Symbol(), timeframe, i) < startTime)
         break;
     }
   
   // 如果找不到匹配的K线
   if(barIndex < 0)
     {
      Print("无法在", EnumToString(timeframe), "周期上找到与价格 ", DoubleToString(highPrice, _Digits), " 接近的K线");
      lowTime = 0;
      return 0.0;
     }
   
   Print("在", EnumToString(timeframe), "周期上找到最接近的K线: 索引=", barIndex, ", 时间=", TimeToString(iTime(Symbol(), timeframe, barIndex)), ", 最高价=", DoubleToString(closestPrice, _Digits));
   
   // 如果是当前K线（索引为0），则切换到更小的周期
   if(barIndex == 0 && smallerTimeframe != timeframe)
     {
      // 递归调用，使用更小的周期
      return FindLowestPriceAfterHighPrice(highPrice, lowTime, smallerTimeframe, smallerTimeframe, startTime);
     }
   
   // 获取指定周期上的K线时间
   datetime barTime = iTime(Symbol(), timeframe, barIndex);
   
   // 从该K线开始向未来方向查找最低价
   double lowestPrice = closestPrice;
   int lowestPriceIndex = barIndex;
   int futureBarsToCheck = (timeframe <= PERIOD_H1) ? 200 : 50; // 根据周期调整检查的未来K线数量
   
   for(int i = barIndex - 1; i >= 0 && i >= barIndex - futureBarsToCheck; i--)
     {
      double low = iLow(Symbol(), timeframe, i);
      if(low < lowestPrice)
        {
         lowestPrice = low;
         lowestPriceIndex = i;
        }
     }
   
   // 记录最低点的时间
   lowTime = iTime(Symbol(), timeframe, lowestPriceIndex);
   
   Print("在", EnumToString(timeframe), "周期上找到最低点: 索引=", lowestPriceIndex, ", 时间=", TimeToString(lowTime), ", 价格=", DoubleToString(lowestPrice, _Digits));
   
   return lowestPrice;
  }

