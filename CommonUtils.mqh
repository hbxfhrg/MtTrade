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

// 在包含ZigzagSegment.mqh之前先声明所需的类

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
      Print("无法在", EnumToString(timeframe), "周期上找到与价格 ", DoubleToString(highPrice, _Digits), " 接近的K线");
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
//| 获取指定周期和时间范围内的极点                                     |
//+------------------------------------------------------------------+
bool GetExtremumPointsInTimeRange(ENUM_TIMEFRAMES timeframe, datetime startTime, datetime endTime, 
                                 CZigzagExtremumPoint &points[], int maxCount = 0, 
                                 int depth = 12, int deviation = 5, int backstep = 3)
  {
   // 检查参数有效性
   if(startTime >= endTime || maxCount < 0)
     {
      Print("参数无效: startTime=", TimeToString(startTime), ", endTime=", TimeToString(endTime), ", maxCount=", maxCount);
      return false;
     }
      
   // 创建ZigZag计算器
   CZigzagCalculator zigzagCalc(depth, deviation, backstep, 3, timeframe);
   
   // 计算指定周期的ZigZag值
   if(!zigzagCalc.CalculateForSymbol(Symbol(), timeframe, 1000))
     {
      Print("计算ZigZag值失败: ", GetLastError());
      return false;
     }
      
   // 获取所有极值点
   CZigzagExtremumPoint allPoints[];
   if(!zigzagCalc.GetExtremumPoints(allPoints))
     {
      Print("获取极值点失败: ", GetLastError());
      return false;
     }
      
   // 筛选出指定时间范围内的极值点
   CZigzagExtremumPoint tempPoints[];
   int count = 0;
   
   for(int i = 0; i < ArraySize(allPoints); i++)
     {
      datetime pointTime = allPoints[i].Time();
      
      // 如果极值点在指定的时间范围内，则添加到结果中
      if(pointTime >= startTime && pointTime <= endTime)
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
                                CZigzagExtremumPoint &points[], int maxCount = 0, 
                                int depth = 12, int deviation = 5, int backstep = 3)
  {
   // 检查参数有效性
   if(startBar < 0 || endBar < 0 || startBar < endBar || maxCount < 0)
     {
      Print("参数无效: startBar=", startBar, ", endBar=", endBar, ", maxCount=", maxCount);
      return false;
     }
      
   // 获取K线的时间
   datetime startTime = iTime(Symbol(), timeframe, startBar);
   datetime endTime = iTime(Symbol(), timeframe, endBar);
   
   if(startTime == 0 || endTime == 0)
     {
      Print("无法获取K线时间: startBar=", startBar, ", endBar=", endBar);
      return false;
     }
      
   // 调用按时间范围获取极值点的方法
   return GetExtremumPointsInTimeRange(timeframe, endTime, startTime, points, maxCount, depth, deviation, backstep);
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
      Print("极点数量不足，无法生成线段: pointCount=", pointCount);
      return false;
     }
      
   // 确保极点是交替的（峰值和谷值）
   for(int i = 1; i < pointCount; i++)
     {
      if(points[i].Type() == points[i-1].Type())
        {
         Print("警告: 极点类型不交替，可能导致线段生成错误: index=", i, ", type=", EnumToString(points[i].Type()));
        }
     }
   
   // 计算可以生成的线段数量
   int segmentCount = pointCount - 1;
   
   // 调整线段数组大小
   ArrayResize(segments, segmentCount);
   
   // 生成线段
   for(int i = 0; i < segmentCount; i++)
     {
      // 创建新线段（注意：线段的起点是i+1，终点是i，这样可以保持与ZigzagSegmentManager中相同的顺序）
      segments[i] = new CZigzagSegment(points[i+1], points[i], timeframe);
     }
   
   return segmentCount > 0;
  }

//+------------------------------------------------------------------+
//| 获取指定周期和时间范围内的线段                                     |
//+------------------------------------------------------------------+
bool GetSegmentsInTimeRange(ENUM_TIMEFRAMES timeframe, datetime startTime, datetime endTime, 
                           CZigzagSegment* &segments[], int maxCount = 0, 
                           int depth = 12, int deviation = 5, int backstep = 3)
  {
   // 先获取极点
   CZigzagExtremumPoint points[];
   if(!GetExtremumPointsInTimeRange(timeframe, startTime, endTime, points, maxCount > 0 ? maxCount + 1 : 0, depth, deviation, backstep))
      return false;
      
   // 将极点转换为线段
   return ConvertExtremumPointsToSegments(points, segments, timeframe);
  }

//+------------------------------------------------------------------+
//| 获取指定周期和K线范围内的线段                                      |
//+------------------------------------------------------------------+
bool GetSegmentsInBarRange(ENUM_TIMEFRAMES timeframe, int startBar, int endBar, 
                          CZigzagSegment* &segments[], int maxCount = 0, 
                          int depth = 12, int deviation = 5, int backstep = 3)
  {
   // 先获取极点
   CZigzagExtremumPoint points[];
   if(!GetExtremumPointsInBarRange(timeframe, startBar, endBar, points, maxCount > 0 ? maxCount + 1 : 0, depth, deviation, backstep))
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
      Print("源线段数组为空");
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
                                  int maxCount = 0, int depth = 12, int deviation = 5, int backstep = 3)
  {
   // 先获取所有线段
   CZigzagSegment* allSegments[];
   if(!GetSegmentsInTimeRange(timeframe, startTime, endTime, allSegments, 0, depth, deviation, backstep))
      return false;
      
   // 根据趋势方向筛选线段
   return FilterSegmentsByTrend(allSegments, segments, trendType, maxCount);
  }

//+------------------------------------------------------------------+
//| 获取指定周期、K线范围和趋势方向的线段                              |
//+------------------------------------------------------------------+
bool GetSegmentsByTrendInBarRange(ENUM_TIMEFRAMES timeframe, int startBar, int endBar, 
                                 CZigzagSegment* &segments[], ENUM_SEGMENT_TREND trendType = SEGMENT_TREND_ALL, 
                                 int maxCount = 0, int depth = 12, int deviation = 5, int backstep = 3)
  {
   // 先获取所有线段
   CZigzagSegment* allSegments[];
   if(!GetSegmentsInBarRange(timeframe, startBar, endBar, allSegments, 0, depth, deviation, backstep))
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

// 包含ZigzagSegment.mqh，放在文件末尾以避免循环引用
#include "ZigzagSegment.mqh"
