//+------------------------------------------------------------------+
//|                                                  ZigzagHelper.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

#ifndef __ZIGZAGHELPER_MQH__
#define __ZIGZAGHELPER_MQH__

// 引入必要的头文件
#include "ZigzagCommon.mqh"      // 包含公共定义和前向声明
#include "CommonUtils.mqh"       // 包含通用工具函数

//+------------------------------------------------------------------+
//| ZigZag辅助类，用于解决循环引用问题                                 |
//+------------------------------------------------------------------+
class CZigzagHelper
{
public:
   // 获取线段的小周期线段
   static bool GetSmallerTimeframeSegments(CZigzagSegmentManager* manager, CZigzagSegment* segment, 
                                          ENUM_TIMEFRAMES smallerTimeframe, CZigzagSegment* &segments[], int maxCount);
};

//+------------------------------------------------------------------+
//| 获取线段的小周期线段                                              |
//+------------------------------------------------------------------+
bool CZigzagHelper::GetSmallerTimeframeSegments(CZigzagSegmentManager* manager, CZigzagSegment* segment, 
                                               ENUM_TIMEFRAMES smallerTimeframe, CZigzagSegment* &segments[], int maxCount)
{
   // 检查参数有效性
   if(manager == NULL || segment == NULL || maxCount <= 0)
      return false;
      
   // 获取线段的时间周期
   ENUM_TIMEFRAMES segmentTimeframe = segment.Timeframe();
   
   // 检查时间周期是否合理
   if(smallerTimeframe >= segmentTimeframe)
   {
      Print("错误: 指定的时间周期 ", TimeframeToString(smallerTimeframe), " 大于或等于当前线段的时间周期 ", TimeframeToString(segmentTimeframe));
      return false;
   }
      
   // 获取线段的时间范围
   datetime startTime = segment.StartTime();
   datetime endTime = segment.EndTime();
   
   // 直接按需计算指定周期的线段，不使用缓存
   CZigzagSegment* allSegments[];
   if(!manager.CalculateSegments(smallerTimeframe, allSegments, maxCount * 2))
      return false;
      
   // 然后筛选出时间范围内的线段
   int count = 0;
   CZigzagSegment* tempSegments[];
   ArrayResize(tempSegments, ArraySize(allSegments));
   
   for(int i = 0; i < ArraySize(allSegments) && count < maxCount; i++)
   {
      if(allSegments[i] != NULL)
      {
         // 检查线段是否在指定的时间范围内
         datetime segStartTime = allSegments[i].StartTime();
         datetime segEndTime = allSegments[i].EndTime();
         
         // 如果线段的时间范围与指定的时间范围有重叠，则添加到结果中
         if((segStartTime >= startTime && segStartTime <= endTime) || 
            (segEndTime >= startTime && segEndTime <= endTime) ||
            (segStartTime <= startTime && segEndTime >= endTime))
         {
            tempSegments[count++] = allSegments[i];
         }
         else
         {
            // 如果不在时间范围内，释放内存
            delete allSegments[i];
         }
      }
   }
   
   // 调整结果数组大小
   ArrayResize(segments, count);
   
   // 复制找到的线段
   for(int i = 0; i < count; i++)
   {
      segments[i] = tempSegments[i];
   }
   
   return count > 0;
}
//+------------------------------------------------------------------+

#endif // __ZIGZAGHELPER_MQH__
