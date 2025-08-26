//+------------------------------------------------------------------+
//|                                                   CommonUtils.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

// 引入必要的头文件
#include "EnumDefinitions.mqh"
#include "ZigzagExtremumPoint.mqh"
#include "ZigzagCalculator.mqh"

// 前向声明
class CZigzagSegment;

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
//| 通过价格查找K线序号（使用ENUM_SERIESMODE）                        |
//+------------------------------------------------------------------+
int FindBarIndexByPrice(double targetPrice, ENUM_SERIESMODE seriesMode, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT, int maxBarsToCheck = 1000)
  {
   // 根据时间周期调整检查的K线数量，小周期不限制数量
   int barsToCheck;
   if(timeframe == PERIOD_M1)  // 1分钟周期，搜索范围最大
     {
      barsToCheck = MathMin(maxBarsToCheck, 5000);  // 1分钟周期最大5000根K线
     }
   else if(timeframe <= PERIOD_M5)  // 5分钟及以下的小周期，使用更大的搜索范围
     {
      barsToCheck = MathMin(maxBarsToCheck, 3000);  // 5分钟周期最大3000根K线
     }
   else if(timeframe <= PERIOD_M15)  // 15分钟周期
     {
      barsToCheck = MathMin(maxBarsToCheck, 1500);  // 15分钟周期最大1500根K线
     }
   else if(timeframe <= PERIOD_H1)  // 1小时及以下的中等周期
     {
      barsToCheck = MathMin(maxBarsToCheck, 800);   // 1小时周期最大800根K线
     }
   else  // 大周期
     {
      barsToCheck = MathMin(maxBarsToCheck, 300);   // 大周期最大300根K线
     }
   
   // 设置固定容差（使用点值的0.1倍作为容差）
   double tolerance = _Point * 0.1;
   
   for(int i = 0; i < barsToCheck; i++)
     {
      double price;
      
      // 根据ENUM_SERIESMODE类型获取相应的价格
      switch(seriesMode)
        {
         case MODE_HIGH:
            price = iHigh(Symbol(), timeframe, i);
            break;
         case MODE_LOW:
            price = iLow(Symbol(), timeframe, i);
            break;
         case MODE_OPEN:
            price = iOpen(Symbol(), timeframe, i);
            break;
         case MODE_CLOSE:
            price = iClose(Symbol(), timeframe, i);
            break;
         default:
            return -1;
        }
      
      // 使用固定容差判断价格是否匹配
      if(MathAbs(price - targetPrice) <= tolerance)
        {
         return i;
        }
     }
   

   
   return -1;
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
      highTime = 0;
      return 0.0;
     }
   
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
      lowTime = 0;
      return 0.0;
     }
   
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
   
   return lowestPrice;
  }

//+------------------------------------------------------------------+
//| 根据价格范围获取极值点                                             |
//+------------------------------------------------------------------+
bool GetExtremumPointsInPriceRange(ENUM_TIMEFRAMES timeframe, double highPrice, double lowPrice,
                                  CZigzagExtremumPoint &points[], int maxCount = 0)
  {
   // 检查参数有效性
   if(highPrice <= lowPrice || maxCount < 0)
     {
      return false;
     }
   
   // 使用默认的ZigZag参数
   int depth = 12;     // 默认值
   int deviation = 5;  // 默认值
   int backstep = 3;   // 默认值
   

   
   // 创建ZigZag计算器
   CZigzagCalculator zigzagCalc(depth, deviation, backstep, 3, timeframe);
   
   // 使用通用方法查找高低点价格对应的K线序号
   int highPriceBarIndex = FindBarIndexByPrice(highPrice, MODE_HIGH, timeframe);
   int lowPriceBarIndex = FindBarIndexByPrice(lowPrice, MODE_LOW, timeframe);
   
   if(highPriceBarIndex == -1 && lowPriceBarIndex == -1)
     {
      return false;
     }
   
   // 找到序号离当前时间最远的值（序号最大的值）
   int farthestBarIndex = MathMax(highPriceBarIndex, lowPriceBarIndex);
   if(highPriceBarIndex == -1) farthestBarIndex = lowPriceBarIndex;
   if(lowPriceBarIndex == -1) farthestBarIndex = highPriceBarIndex;
   

   // 计算指定周期的ZigZag值
   if(!zigzagCalc.CalculateForSymbol(Symbol(), timeframe, 1000))
     {
      return false;
     }
      
   // 获取所有极值点
   CZigzagExtremumPoint allPoints[];
   if(!zigzagCalc.GetExtremumPoints(allPoints))
     {
      return false;
     }
      
   // 筛选出在指定价格范围内的极值点
   CZigzagExtremumPoint tempPoints[];
   int count = 0;
   
   // 筛选的逻辑更换成高低点价格所在周期的K线序号最大值到当前序号0之间的所有极点值
   for(int i = 0; i < ArraySize(allPoints); i++)
     {
      // 获取极值点的时间和对应的K线序号
      datetime pointTime = allPoints[i].Time();
      int pointBarIndex = iBarShift(Symbol(), timeframe, pointTime);
      
      // 检查该极值点是否在指定的K线序号范围内（从最远序号到当前序号0）
      if(pointBarIndex >= 0 && pointBarIndex <= farthestBarIndex)
        {
         ArrayResize(tempPoints, count + 1);
         tempPoints[count++] = allPoints[i];
         
         // 如果达到最大数量限制，则停止添加
         if(maxCount > 0 && count >= maxCount)
            break;
        }
     }
   
   // 调整结果数组大小
   ArrayResize(points, count);
   
   // 复制找到的极值点
   for(int i = 0; i < count; i++)
     {
      points[i] = tempPoints[i];
     }
   

   
   return count > 0;
  }

//+------------------------------------------------------------------+
//| 获取指定周期和K线范围内的极点                                      |
//+------------------------------------------------------------------+
bool GetExtremumPointsInBarRange(ENUM_TIMEFRAMES timeframe, int startBar, int endBar, 
                                CZigzagExtremumPoint &points[], int maxCount = 0)
  {
   // 检查参数有效性
   if(startBar < 0 || endBar < 0 || startBar < endBar || maxCount < 0)
     {
      return false;
     }
      
   // 获取K线范围内的价格范围
   double highPrice = 0.0;
   double lowPrice = DBL_MAX;
   
   for(int i = endBar; i <= startBar; i++)
     {
      double high = iHigh(Symbol(), timeframe, i);
      double low = iLow(Symbol(), timeframe, i);
      
      if(high > highPrice) highPrice = high;
      if(low < lowPrice) lowPrice = low;
     }
   
   if(highPrice <= lowPrice)
     {
      return false;
     }
      
   // 调用基于价格范围获取极值点的方法
   return GetExtremumPointsInPriceRange(timeframe, highPrice, lowPrice, points, maxCount);
  }

//+------------------------------------------------------------------+
//| 将极点数组转换为线段数组                                           |
//+------------------------------------------------------------------+
bool ConvertExtremumPointsToSegments(const CZigzagExtremumPoint &points[], CZigzagSegment* &segments[], ENUM_TIMEFRAMES timeframe)
  {
   // 检查参数有效性
   int pointCount = ArraySize(points);
   if(pointCount < 2)
     {
      return false;
     }
      
   // 确保极点是交替的（峰值和谷值）
   for(int i = 1; i < pointCount; i++)
     {
      if(points[i].Type() == points[i-1].Type())
        {
         // 极点类型不交替，可能导致线段生成错误
        }
     }
   
   // 计算可以生成的线段数量
   int segmentCount = pointCount - 1;
   
   // 调整线段数组大小
   ArrayResize(segments, segmentCount);
   
   // 生成线段
   // 注意：由于GetExtremumPoints现在返回按时间排序的极值点（最新的在前面），
   // 我们需要确保线段的起点时间早于终点时间
   for(int i = 0; i < segmentCount; i++)
     {
      // 由于极值点已按时间排序（最新在前），points[i]的时间 >= points[i+1]的时间
      // 因此points[i+1]应该作为起点（时间更早），points[i]作为终点（时间更晚）
      segments[i] = new CZigzagSegment(points[i+1], points[i], timeframe);
     }
   
   return segmentCount > 0;
  }

//+------------------------------------------------------------------+
//| 根据价格范围获取线段                                             |
//+------------------------------------------------------------------+
bool GetSegmentsInPriceRange(ENUM_TIMEFRAMES timeframe, double highPrice, double lowPrice, 
                           CZigzagSegment* &segments[], int maxCount = 0)
  {
   // 先获取极点
   CZigzagExtremumPoint points[];
   if(!GetExtremumPointsInPriceRange(timeframe, highPrice, lowPrice, points, maxCount > 0 ? maxCount + 1 : 0))
      return false;
      
   // 将极点转换为线段
   return ConvertExtremumPointsToSegments(points, segments, timeframe);
  }

//+------------------------------------------------------------------+
//| 获取指定周期和时间范围内的线段（兼容性方法）                     |
//+------------------------------------------------------------------+
bool GetSegmentsInTimeRange(ENUM_TIMEFRAMES timeframe, datetime startTime, datetime endTime, 
                           CZigzagSegment* &segments[], int maxCount = 0)
  {
   // 获取时间范围内的价格范围
   double highPrice = 0.0;
   double lowPrice = DBL_MAX;
   
   // 通过正向遍历K线获取价格范围
   datetime currentTime = TimeCurrent();
   int barCount = 1000; // 限制检查的K线数量
   
   for(int i = 0; i < barCount; i++)
     {
      datetime barTime = iTime(Symbol(), timeframe, i);
      if(barTime == 0) break; // 如果没有更多数据，退出
      
      // 检查是否在时间范围内
      if(barTime >= MathMin(startTime, endTime) && barTime <= MathMax(startTime, endTime))
        {
         double high = iHigh(Symbol(), timeframe, i);
         double low = iLow(Symbol(), timeframe, i);
         
         if(high > highPrice) highPrice = high;
         if(low < lowPrice) lowPrice = low;
        }
      
      // 如果时间超出范围，停止查找
      if(barTime < MathMin(startTime, endTime))
         break;
     }
   
   if(highPrice <= lowPrice)
     {
      return false;
     }
   
   // 调用基于价格范围的方法
   return GetSegmentsInPriceRange(timeframe, highPrice, lowPrice, segments, maxCount);
  }

//+------------------------------------------------------------------+
//| 获取指定周期和K线范围内的线段                                      |
//+------------------------------------------------------------------+
bool GetSegmentsInBarRange(ENUM_TIMEFRAMES timeframe, int startBar, int endBar, 
                          CZigzagSegment* &segments[], int maxCount = 0)
  {
   // 先获取极点
   CZigzagExtremumPoint points[];
   if(!GetExtremumPointsInBarRange(timeframe, startBar, endBar, points, maxCount > 0 ? maxCount + 1 : 0))
      return false;
      
   // 将极点转换为线段
   return ConvertExtremumPointsToSegments(points, segments, timeframe);
  }

//+------------------------------------------------------------------+
//| 从线段数组中筛选出指定趋势方向的线段                               |
//+------------------------------------------------------------------+
bool FilterSegmentsByTrend(CZigzagSegment* &sourceSegments[], CZigzagSegment* &filteredSegments[], 
                          ENUM_SEGMENT_TREND trendType = SEGMENT_TREND_ALL, int maxCount = 0)
  {
   // 检查参数有效性
   int sourceCount = ArraySize(sourceSegments);
   if(sourceCount == 0)
     {
      return false;
     }
      
   // 临时数组，用于存储筛选后的线段
   CZigzagSegment* tempSegments[];
   int count = 0;
   
   // 遍历所有线段，根据趋势方向筛选
   for(int i = 0; i < sourceCount; i++)
     {
      if(sourceSegments[i] != NULL)
        {
         bool shouldAdd = false;
         
         // 根据趋势类型筛选
         switch(trendType)
           {
            case SEGMENT_TREND_ALL:  // 所有趋势
               shouldAdd = true;
               break;
               
            case SEGMENT_TREND_UP:   // 上涨趋势
               shouldAdd = sourceSegments[i].IsUptrend();
               break;
               
            case SEGMENT_TREND_DOWN: // 下跌趋势
               shouldAdd = sourceSegments[i].IsDowntrend();
               break;
           }
         
         if(shouldAdd)
           {
            // 调整数组大小
            ArrayResize(tempSegments, count + 1);
            
            // 创建线段的副本（避免内存问题）
            tempSegments[count] = new CZigzagSegment(*sourceSegments[i]);
            count++;
            
            // 如果达到最大数量限制，则停止添加
            if(maxCount > 0 && count >= maxCount)
               break;
           }
        }
     }
   
   // 调整结果数组大小
   ArrayResize(filteredSegments, count);
   
   // 复制找到的线段
   for(int i = 0; i < count; i++)
     {
      filteredSegments[i] = tempSegments[i];
     }
   
   return count > 0;
  }

//+------------------------------------------------------------------+
//| 获取指定周期、时间范围和趋势方向的线段                             |
//+------------------------------------------------------------------+
bool GetSegmentsByTrendInTimeRange(ENUM_TIMEFRAMES timeframe, datetime startTime, datetime endTime, 
                                  CZigzagSegment* &segments[], ENUM_SEGMENT_TREND trendType = SEGMENT_TREND_ALL, 
                                  int maxCount = 0)
  {
   // 先获取所有线段
   CZigzagSegment* allSegments[];
   if(!GetSegmentsInTimeRange(timeframe, startTime, endTime, allSegments, 0))
      return false;
      
   // 根据趋势方向筛选线段
   return FilterSegmentsByTrend(allSegments, segments, trendType, maxCount);
  }

//+------------------------------------------------------------------+
//| 获取指定周期、K线范围和趋势方向的线段                              |
//+------------------------------------------------------------------+
bool GetSegmentsByTrendInBarRange(ENUM_TIMEFRAMES timeframe, int startBar, int endBar, 
                                 CZigzagSegment* &segments[], ENUM_SEGMENT_TREND trendType = SEGMENT_TREND_ALL, 
                                 int maxCount = 0)
  {
   // 先获取所有线段
   CZigzagSegment* allSegments[];
   if(!GetSegmentsInBarRange(timeframe, startBar, endBar, allSegments, 0))
      return false;
      
   // 根据趋势方向筛选线段
   bool result = FilterSegmentsByTrend(allSegments, segments, trendType, maxCount);
   
   // 释放原始线段数组中的对象
   for(int i = 0; i < ArraySize(allSegments); i++)
     {
      if(allSegments[i] != NULL)
         delete allSegments[i];
     }
   
   return result;
  }

//+------------------------------------------------------------------+
//| 获取小周期线段，基于区间高点时间确定获取范围                        |
//+------------------------------------------------------------------+
bool GetSmallTimeframeSegmentsExcludingRange(ENUM_TIMEFRAMES smallTimeframe, ENUM_TIMEFRAMES largeTimeframe,
                                           datetime startTime, datetime endTime,
                                           CZigzagSegment* &segments[], ENUM_SEGMENT_TREND trendType = SEGMENT_TREND_ALL,
                                           int maxCount = 0)
  {
   // 获取大周期的价格范围
   double highPrice = 0.0;
   double lowPrice = DBL_MAX;
   
   // 通过正向遍历K线获取价格范围
   int barCount = 1000; // 限制检查的K线数量
   
   for(int i = 0; i < barCount; i++)
     {
      datetime barTime = iTime(Symbol(), largeTimeframe, i);
      if(barTime == 0) break; // 如果没有更多数据，退出
      
      // 检查是否在时间范围内
      if(barTime >= MathMin(startTime, endTime) && barTime <= MathMax(startTime, endTime))
        {
         double high = iHigh(Symbol(), largeTimeframe, i);
         double low = iLow(Symbol(), largeTimeframe, i);
         
         if(high > highPrice) highPrice = high;
         if(low < lowPrice) lowPrice = low;
        }
      
      // 如果时间超出范围，停止查找
      if(barTime < MathMin(startTime, endTime))
         break;
     }
   
   if(highPrice <= lowPrice)
     {
      return false;
     }
   
   // 先获取大周期的极值点，用于确定区间高低点
   CZigzagExtremumPoint largePoints[];
   if(!GetExtremumPointsInPriceRange(largeTimeframe, highPrice, lowPrice, largePoints, 0))
     {
      return false;
     }
   
   // 找到最近的区间高点和低点时间
   datetime latestHighTime = 0;
   datetime latestLowTime = 0;
   
   for(int i = 0; i < ArraySize(largePoints); i++)
     {
      if(largePoints[i].Type() == EXTREMUM_PEAK) // 高点
        {
         if(largePoints[i].Time() > latestHighTime)
           {
            latestHighTime = largePoints[i].Time();
           }
        }
      else if(largePoints[i].Type() == EXTREMUM_BOTTOM) // 低点
        {
         if(largePoints[i].Time() > latestLowTime)
           {
            latestLowTime = largePoints[i].Time();
           }
        }
     }
   
   // 根据趋势类型确定调整时间范围的逻辑
   datetime adjustedStartTime = startTime;
   
   if(trendType == SEGMENT_TREND_UP || trendType == SEGMENT_TREND_ALL)
     {
      // 对于上涨趋势，从最近的区间高点时间开始获取
      if(latestHighTime > 0)
        {
         adjustedStartTime = MathMax(adjustedStartTime, latestHighTime);
        }
     }
   
   if(trendType == SEGMENT_TREND_DOWN || trendType == SEGMENT_TREND_ALL)
     {
      // 对于下跌趋势，从最近的区间低点时间开始获取
      if(latestLowTime > 0)
        {
         adjustedStartTime = MathMax(adjustedStartTime, latestLowTime);
        }
     }
   

   
   // 获取调整后时间范围内的小周期线段
   CZigzagSegment* allSmallSegments[];
   if(!GetSegmentsInTimeRange(smallTimeframe, adjustedStartTime, endTime, allSmallSegments, 0))
     {
      return false;
     }
   
   // 根据趋势类型筛选线段
   CZigzagSegment* filteredSegments[];
   int count = 0;
   
   for(int i = 0; i < ArraySize(allSmallSegments); i++)
     {
      if(allSmallSegments[i] != NULL)
        {
         // 根据趋势类型筛选
         bool shouldAdd = false;
         switch(trendType)
           {
            case SEGMENT_TREND_ALL:
               shouldAdd = true;
               break;
            case SEGMENT_TREND_UP:
               shouldAdd = allSmallSegments[i].IsUptrend();
               break;
            case SEGMENT_TREND_DOWN:
               shouldAdd = allSmallSegments[i].IsDowntrend();
               break;
           }
         
         if(shouldAdd)
           {
            ArrayResize(filteredSegments, count + 1);
            filteredSegments[count] = new CZigzagSegment(*allSmallSegments[i]);
            count++;
            
            // 如果达到最大数量限制，则停止添加
            if(maxCount > 0 && count >= maxCount)
               break;
           }
        }
     }
   
   // 调整结果数组大小
   ArrayResize(segments, count);
   
   // 复制筛选后的线段
   for(int i = 0; i < count; i++)
     {
      segments[i] = filteredSegments[i];
     }
   
   // 释放原始线段数组中的对象
   for(int i = 0; i < ArraySize(allSmallSegments); i++)
     {
      if(allSmallSegments[i] != NULL)
         delete allSmallSegments[i];
     }
   
   return count > 0;
  }

//+------------------------------------------------------------------+
//| 按时间排序线段数组（从晚到早，最近的在前面）                        |
//+------------------------------------------------------------------+
void SortSegmentsByTime(CZigzagSegment* &segments[])
{
   int size = ArraySize(segments);
   if(size <= 1)
      return;
      
   // 使用简单的冒泡排序，按时间从晚到早排序
   for(int i = 0; i < size - 1; i++)
   {
      for(int j = 0; j < size - i - 1; j++)
      {
         if(segments[j] != NULL && segments[j+1] != NULL)
         {
            // 按开始时间反向排序（最近的时间在前面）
            if(segments[j].StartTime() < segments[j+1].StartTime())
            {
               // 交换位置
               CZigzagSegment* temp = segments[j];
               segments[j] = segments[j+1];
               segments[j+1] = temp;
            }
         }
      }
   }
}


// 包含ZigzagSegment.mqh，放在文件末尾以避免循环引用
#include "ZigzagSegment.mqh"
