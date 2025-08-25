//+------------------------------------------------------------------+
//|                                          ZigzagSegmentManager.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

// 引入必要的头文件
#include "EnumDefinitions.mqh"      // 包含公共枚举定义
#include "ZigzagExtremumPoint.mqh"  // 包含CZigzagExtremumPoint类定义
#include "ZigzagCalculator.mqh"
#include "CommonUtils.mqh"          // 包含通用工具函数
#include <Arrays\\ArrayObj.mqh>

// 包含ZigzagSegment类定义
#include "ZigzagSegment.mqh"

//+------------------------------------------------------------------+
//| ZigZag线段管理类                                                  |
//+------------------------------------------------------------------+
class CZigzagSegmentManager
{
private:
   CArrayObj*         m_segments_arrays[]; // 存储不同周期线段的数组
   ENUM_TIMEFRAMES    m_timeframes[];     // 对应的时间周期
   int                m_timeframe_count;   // 支持的时间周期数量
   int                m_max_segments;      // 每个周期的最大线段数量
   CZigzagCalculator* m_calculator;       // ZigZag计算器
   
   // 根据时间周期获取对应的线段数组
   CArrayObj*         GetSegmentArrayByTimeframe(ENUM_TIMEFRAMES timeframe);
   
   // 添加支持的时间周期
   bool               AddTimeframe(ENUM_TIMEFRAMES timeframe);
   
   // 从极点数组生成线段
   bool               GenerateSegmentsFromPoints(CArrayObj* segments, CZigzagExtremumPoint &points[], int pointCount, ENUM_TIMEFRAMES timeframe);
   
public:
                     CZigzagSegmentManager(int maxSegments = 50);
                    ~CZigzagSegmentManager();
   
   // 初始化和更新
   bool              Initialize();
   bool              Update();
   
   // 获取线段数量
   int               GetSegmentCount(ENUM_TIMEFRAMES timeframe) const;
   
   // 获取指定索引的线段（从缓存中）
   CZigzagSegment*   GetSegment(ENUM_TIMEFRAMES timeframe, int index);
   
   // 按需计算指定周期的线段（不缓存）
   bool              CalculateSegments(ENUM_TIMEFRAMES timeframe, CZigzagSegment* &segments[], int maxCount);
   
   // 获取最近的N个线段
   bool              GetRecentSegments(ENUM_TIMEFRAMES timeframe, CZigzagSegment* &segments[], int count);
   
   // 获取特定类型的线段（上涨/下跌）
   bool              GetUptrendSegments(ENUM_TIMEFRAMES timeframe, CZigzagSegment* &segments[], int maxCount);
   bool              GetDowntrendSegments(ENUM_TIMEFRAMES timeframe, CZigzagSegment* &segments[], int maxCount);
   
   // 清除所有线段
   void              Clear();
   
   // 打印线段信息（用于调试）
   void              PrintSegments(ENUM_TIMEFRAMES timeframe, int count = 10);
   
   // 获取指定时间范围内的线段
   bool              GetSegmentsInTimeRange(ENUM_TIMEFRAMES timeframe, datetime startTime, datetime endTime, 
                                           CZigzagSegment* &segments[], int maxCount);
};

//+------------------------------------------------------------------+
//| 构造函数                                                          |
//+------------------------------------------------------------------+
CZigzagSegmentManager::CZigzagSegmentManager(int maxSegments)
{
   m_max_segments = maxSegments;
   m_timeframe_count = 0;
   m_calculator = new CZigzagCalculator(12, 5, 3, 1000, PERIOD_CURRENT);
   
   // 不再预先添加时间周期，改为按需添加
}

//+------------------------------------------------------------------+
//| 添加支持的时间周期                                                |
//+------------------------------------------------------------------+
bool CZigzagSegmentManager::AddTimeframe(ENUM_TIMEFRAMES timeframe)
{
   // 检查是否已经支持该时间周期
   for(int i = 0; i < m_timeframe_count; i++)
   {
      if(m_timeframes[i] == timeframe)
         return true; // 已经支持该时间周期
   }
   
   // 添加新的时间周期
   int newSize = m_timeframe_count + 1;
   
   // 调整时间周期数组大小
   ArrayResize(m_timeframes, newSize);
   m_timeframes[m_timeframe_count] = timeframe;
   
   // 调整线段数组大小
   ArrayResize(m_segments_arrays, newSize);
   
   // 创建新的线段数组
   m_segments_arrays[m_timeframe_count] = new CArrayObj();
   
   if(m_segments_arrays[m_timeframe_count] != NULL)
      m_segments_arrays[m_timeframe_count].FreeMode(true); // 启用自动删除对象模式
   
   // 增加计数
   m_timeframe_count++;
   
   return true;
}

//+------------------------------------------------------------------+
//| 析构函数                                                          |
//+------------------------------------------------------------------+
CZigzagSegmentManager::~CZigzagSegmentManager()
{
   Clear();
   
   // 释放所有线段数组
   for(int i = 0; i < m_timeframe_count; i++)
   {
      if(m_segments_arrays[i] != NULL)
      {
         delete m_segments_arrays[i];
         m_segments_arrays[i] = NULL;
      }
   }
   
   if(m_calculator != NULL)
   {
      delete m_calculator;
      m_calculator = NULL;
   }
}

//+------------------------------------------------------------------+
//| 获取指定时间周期的线段数量                                        |
//+------------------------------------------------------------------+
int CZigzagSegmentManager::GetSegmentCount(ENUM_TIMEFRAMES timeframe) const
{
   CArrayObj* segments = NULL;
   
   // 查找对应时间周期的线段数组
   for(int i = 0; i < m_timeframe_count; i++)
   {
      if(m_timeframes[i] == timeframe)
      {
         segments = m_segments_arrays[i];
         break;
      }
   }
   
   return segments ? segments.Total() : 0;
}

//+------------------------------------------------------------------+
//| 初始化线段管理器                                                  |
//+------------------------------------------------------------------+
bool CZigzagSegmentManager::Initialize()
{
   // 检查计算器是否已初始化
   if(m_calculator == NULL)
      return false;
      
   // 清除现有线段
   Clear();
   
   // 更新线段
   return Update();
}

//+------------------------------------------------------------------+
//| 更新线段数据                                                      |
//+------------------------------------------------------------------+
bool CZigzagSegmentManager::Update()
{
   bool result = true;
   
   // 检查计算器是否已初始化
   if(m_calculator == NULL)
      return false;
   
   // 遍历所有支持的时间周期
   for(int i = 0; i < m_timeframe_count; i++)
   {
      ENUM_TIMEFRAMES timeframe = m_timeframes[i];
      CArrayObj* segments = m_segments_arrays[i];
      
      if(segments != NULL)
      {
         // 获取当前时间周期的ZigZag极点数据
         CZigzagExtremumPoint points[];
         int point_count = m_calculator.GetExtremumPoints(points, m_max_segments * 2, timeframe);
         
         if(point_count >= 2)
         {
            // 从极点生成线段
            result &= GenerateSegmentsFromPoints(segments, points, point_count, timeframe);
         }
      }
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| 从极点数组生成线段                                                |
//+------------------------------------------------------------------+
bool CZigzagSegmentManager::GenerateSegmentsFromPoints(CArrayObj* segments, CZigzagExtremumPoint &points[], int pointCount, ENUM_TIMEFRAMES timeframe)
{
   if(segments == NULL)
      return false;
      
   // 清除现有线段
   segments.Clear();
   
   // 至少需要两个点才能形成线段
   if(pointCount < 2)
      return false;
   
   // 生成线段
   for(int i = 0; i < pointCount - 1; i++)
   {
      // 设置时间周期
      points[i].Timeframe(timeframe);
      points[i+1].Timeframe(timeframe);
      
      // 创建新线段
      CZigzagSegment* segment = new CZigzagSegment(points[i+1], points[i], timeframe);
      
      // 添加到线段数组
      if(segment != NULL)
      {
         // 设置线段管理器引用
         segment.SetManager(this);
         
         // 创建包装器并添加到数组
         CZigzagSegmentWrapper* wrapper = new CZigzagSegmentWrapper(segment);
         if(wrapper != NULL)
         {
            segments.Add(wrapper);
            
            // 如果达到最大线段数量，停止添加
            if(segments.Total() >= m_max_segments)
               break;
         }
      }
   }
   
   return segments.Total() > 0;
}


//+------------------------------------------------------------------+
//| 获取最近的N个指定周期的线段                                       |
//+------------------------------------------------------------------+
bool CZigzagSegmentManager::GetRecentSegments(ENUM_TIMEFRAMES timeframe, CZigzagSegment* &segments[], int count)
{
   CArrayObj* segmentsArray = GetSegmentArrayByTimeframe(timeframe);
   
   if(segmentsArray == NULL)
      return false;
      
   int total = segmentsArray.Total();
   
   // 检查参数有效性
   if(count <= 0 || total == 0)
      return false;
   
   // 调整count，不超过实际线段数量
   count = MathMin(count, total);
   
   // 调整数组大小
   ArrayResize(segments, count);
   
   // 复制最近的线段
   for(int i = 0; i < count; i++)
   {
      segments[i] = GetSegment(timeframe, i);
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| 获取上涨趋势的指定周期线段                                        |
//+------------------------------------------------------------------+
bool CZigzagSegmentManager::GetUptrendSegments(ENUM_TIMEFRAMES timeframe, CZigzagSegment* &segments[], int maxCount)
{
   CArrayObj* segmentsArray = GetSegmentArrayByTimeframe(timeframe);
   
   if(segmentsArray == NULL)
      return false;
      
   int total = segmentsArray.Total();
   
   // 检查参数有效性
   if(maxCount <= 0 || total == 0)
      return false;
   
   // 获取所有线段
   CZigzagSegment* allSegments[];
   ArrayResize(allSegments, total);
   
   for(int i = 0; i < total; i++)
   {
      allSegments[i] = GetSegment(timeframe, i);
   }
   
   // 使用CommonUtils中的静态方法筛选上涨线段
   return FilterSegmentsByTrend(allSegments, segments, SEGMENT_TREND_UP, maxCount);
}

//+------------------------------------------------------------------+
//| 获取下跌趋势的指定周期线段                                        |
//+------------------------------------------------------------------+
bool CZigzagSegmentManager::GetDowntrendSegments(ENUM_TIMEFRAMES timeframe, CZigzagSegment* &segments[], int maxCount)
{
   CArrayObj* segmentsArray = GetSegmentArrayByTimeframe(timeframe);
   
   if(segmentsArray == NULL)
      return false;
      
   int total = segmentsArray.Total();
   
   // 检查参数有效性
   if(maxCount <= 0 || total == 0)
      return false;
   
   // 获取所有线段
   CZigzagSegment* allSegments[];
   ArrayResize(allSegments, total);
   
   for(int i = 0; i < total; i++)
   {
      allSegments[i] = GetSegment(timeframe, i);
   }
   
   // 使用CommonUtils中的静态方法筛选下跌线段
   return FilterSegmentsByTrend(allSegments, segments, SEGMENT_TREND_DOWN, maxCount);
}

//+------------------------------------------------------------------+
//| 清除所有线段                                                      |
//+------------------------------------------------------------------+
void CZigzagSegmentManager::Clear()
{
   for(int i = 0; i < m_timeframe_count; i++)
   {
      if(m_segments_arrays[i] != NULL)
         m_segments_arrays[i].Clear();
   }
}

//+------------------------------------------------------------------+
//| 打印指定周期的线段信息（用于调试）                                |
//+------------------------------------------------------------------+
void CZigzagSegmentManager::PrintSegments(ENUM_TIMEFRAMES timeframe, int count)
{
   CArrayObj* segmentsArray = GetSegmentArrayByTimeframe(timeframe);
   
   if(segmentsArray == NULL)
      return;
      
   int total = segmentsArray.Total();
   
   // 调整count，不超过实际线段数量
   count = MathMin(count, total);
   
   // 使用公共工具函数获取时间周期的字符串表示
   string timeframeStr = TimeframeToString(timeframe);
   
   Print("===== ", timeframeStr, " ZigZag线段信息 =====");
   for(int i = 0; i < count; i++)
   {
      CZigzagSegment* segment = GetSegment(timeframe, i);
      if(segment != NULL)
      {
         Print(i, ": ", segment.ToString());
      }
   }
   Print("=========================");
}

//+------------------------------------------------------------------+
//| 获取指定时间范围内的线段                                          |
//+------------------------------------------------------------------+
bool CZigzagSegmentManager::GetSegmentsInTimeRange(ENUM_TIMEFRAMES timeframe, datetime startTime, datetime endTime, 
                                                  CZigzagSegment* &segments[], int maxCount)
{
   // 检查参数有效性
   if(maxCount <= 0)
      return false;
      
   // 如果需要计算新的线段，使用CommonUtils中的静态方法
   if(m_calculator != NULL)
   {
      // 使用CommonUtils中的静态方法获取时间范围内的线段
      return ::GetSegmentsInTimeRange(timeframe, startTime, endTime, segments, maxCount, 
                                     m_calculator.Depth(), m_calculator.Deviation(), m_calculator.Backstep());
   }
   
   // 如果没有计算器，则从缓存中获取
   CArrayObj* segmentsArray = GetSegmentArrayByTimeframe(timeframe);
   
   if(segmentsArray == NULL)
      return false;
      
   int total = segmentsArray.Total();
   
   if(total == 0)
      return false;
   
   // 获取所有线段
   CZigzagSegment* allSegments[];
   ArrayResize(allSegments, total);
   
   for(int i = 0; i < total; i++)
   {
      allSegments[i] = GetSegment(timeframe, i);
   }
   
   // 临时数组，用于存储符合条件的线段
   CZigzagSegment* tempSegments[];
   int count = 0;
   
   // 找出时间范围内的线段
   for(int i = 0; i < total && count < maxCount; i++)
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
            // 调整数组大小
            ArrayResize(tempSegments, count + 1);
            
            // 创建线段的副本（避免内存问题）
            tempSegments[count] = new CZigzagSegment(*allSegments[i]);
            count++;
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
//| 根据时间周期获取对应的线段数组                                    |
//+------------------------------------------------------------------+
CArrayObj* CZigzagSegmentManager::GetSegmentArrayByTimeframe(ENUM_TIMEFRAMES timeframe)
{
   for(int i = 0; i < m_timeframe_count; i++)
   {
      if(m_timeframes[i] == timeframe)
         return m_segments_arrays[i];
   }
   
   return NULL; // 未找到对应的时间周期
}

//+------------------------------------------------------------------+
//| 通用方法：根据时间周期和索引获取线段                              |
//+------------------------------------------------------------------+
CZigzagSegment* CZigzagSegmentManager::GetSegment(ENUM_TIMEFRAMES timeframe, int index)
{
   CArrayObj* segments = GetSegmentArrayByTimeframe(timeframe);
   
   if(segments == NULL || index < 0 || index >= segments.Total())
      return NULL;
      
   CZigzagSegmentWrapper* wrapper = (CZigzagSegmentWrapper*)segments.At(index);
   if(wrapper != NULL)
      return wrapper.GetSegment();
      
   return NULL;
}

//+------------------------------------------------------------------+
//| 按需计算指定周期的线段（不缓存）                                  |
//+------------------------------------------------------------------+
bool CZigzagSegmentManager::CalculateSegments(ENUM_TIMEFRAMES timeframe, CZigzagSegment* &segments[], int maxCount)
{
   // 检查参数有效性
   if(m_calculator == NULL || maxCount <= 0)
      return false;
      
   // 获取当前时间周期的ZigZag极点数据
   CZigzagExtremumPoint points[];
   int point_count = m_calculator.GetExtremumPoints(points, maxCount * 2, timeframe);
   
   if(point_count < 2)
      return false;
      
   // 调整数组大小
   int segmentCount = MathMin(maxCount, point_count - 1);
   ArrayResize(segments, segmentCount);
   
   // 生成线段
   for(int i = 0; i < segmentCount; i++)
   {
      // 设置时间周期
      points[i].Timeframe(timeframe);
      points[i+1].Timeframe(timeframe);
      
      // 创建新线段
      segments[i] = new CZigzagSegment(points[i+1], points[i], timeframe);
      
      // 设置线段管理器引用
      if(segments[i] != NULL)
         segments[i].SetManager(this);
   }
   
   return segmentCount > 0;
}
//+------------------------------------------------------------------+


