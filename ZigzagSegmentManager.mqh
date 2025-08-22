//+------------------------------------------------------------------+
//|                                          ZigzagSegmentManager.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

// 引入必要的头文件
#include "ZigzagExtremumPoint.mqh"  // 包含CZigzagExtremumPoint类定义
#include "ZigzagSegment.mqh"        // 包含CZigzagSegment类和CZigzagSegmentWrapper类定义
#include "ZigzagCalculator.mqh"
#include <Arrays\\ArrayObj.mqh>

//+------------------------------------------------------------------+
//| ZigZag线段管理类                                                  |
//+------------------------------------------------------------------+
class CZigzagSegmentManager
{
private:
   CArrayObj*         m_segments_h1;     // H1线段数组
   CArrayObj*         m_segments_h4;     // H4线段数组
   int                m_max_segments;     // 最大线段数量
   CZigzagCalculator* m_calculator;      // ZigZag计算器
   
   // 从极点数组生成线段
   bool               GenerateSegmentsFromPoints(CArrayObj* segments, CZigzagExtremumPoint &points[], int pointCount, ENUM_TIMEFRAMES timeframe);
   
public:
                     CZigzagSegmentManager(int maxSegments = 50);
                    ~CZigzagSegmentManager();
   
   // 初始化和更新
   bool              Initialize();
   bool              Update();
   
   // 获取线段数量
   int               H1SegmentCount() const { return m_segments_h1 ? m_segments_h1.Total() : 0; }
   int               H4SegmentCount() const { return m_segments_h4 ? m_segments_h4.Total() : 0; }
   
   // 获取指定索引的线段
   CZigzagSegment*   GetH1Segment(int index);
   CZigzagSegment*   GetH4Segment(int index);
   
   // 获取最近的N个线段
   bool              GetRecentH1Segments(CZigzagSegment* &segments[], int count);
   bool              GetRecentH4Segments(CZigzagSegment* &segments[], int count);
   
   // 获取特定类型的线段（上涨/下跌）
   bool              GetUptrendH1Segments(CZigzagSegment* &segments[], int maxCount);
   bool              GetDowntrendH1Segments(CZigzagSegment* &segments[], int maxCount);
   bool              GetUptrendH4Segments(CZigzagSegment* &segments[], int maxCount);
   bool              GetDowntrendH4Segments(CZigzagSegment* &segments[], int maxCount);
   
   // 清除所有线段
   void              Clear();
   
   // 打印线段信息（用于调试）
   void              PrintH1Segments(int count = 10);
   void              PrintH4Segments(int count = 10);
};

//+------------------------------------------------------------------+
//| 构造函数                                                          |
//+------------------------------------------------------------------+
CZigzagSegmentManager::CZigzagSegmentManager(int maxSegments)
{
   m_max_segments = maxSegments;
   m_segments_h1 = new CArrayObj();
   m_segments_h4 = new CArrayObj();
   m_calculator = new CZigzagCalculator(12, 5, 3, 1000, PERIOD_CURRENT);
   
   if(m_segments_h1 != NULL)
      m_segments_h1.FreeMode(true); // 启用自动删除对象模式
      
   if(m_segments_h4 != NULL)
      m_segments_h4.FreeMode(true); // 启用自动删除对象模式
}

//+------------------------------------------------------------------+
//| 析构函数                                                          |
//+------------------------------------------------------------------+
CZigzagSegmentManager::~CZigzagSegmentManager()
{
   Clear();
   
   if(m_segments_h1 != NULL)
   {
      delete m_segments_h1;
      m_segments_h1 = NULL;
   }
   
   if(m_segments_h4 != NULL)
   {
      delete m_segments_h4;
      m_segments_h4 = NULL;
   }
   
   if(m_calculator != NULL)
   {
      delete m_calculator;
      m_calculator = NULL;
   }
}

//+------------------------------------------------------------------+
//| 初始化线段管理器                                                  |
//+------------------------------------------------------------------+
bool CZigzagSegmentManager::Initialize()
{
   // 检查数组是否已初始化
   if(m_segments_h1 == NULL || m_segments_h4 == NULL || m_calculator == NULL)
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
   
   // 检查数组是否已初始化
   if(m_segments_h1 == NULL || m_segments_h4 == NULL || m_calculator == NULL)
      return false;
   
   // 获取H1时间周期的ZigZag极点数据
   CZigzagExtremumPoint h1_points[];
   int h1_point_count = m_calculator.GetExtremumPoints(h1_points, m_max_segments * 2);
   
   if(h1_point_count >= 2)
   {
      // 从H1极点生成线段
      result &= GenerateSegmentsFromPoints(m_segments_h1, h1_points, h1_point_count, PERIOD_H1);
   }
   
   // 获取H4时间周期的ZigZag极点数据
   CZigzagExtremumPoint h4_points[];
   int h4_point_count = m_calculator.GetExtremumPoints(h4_points, m_max_segments * 2);
   
   if(h4_point_count >= 2)
   {
      // 从H4极点生成线段
      result &= GenerateSegmentsFromPoints(m_segments_h4, h4_points, h4_point_count, PERIOD_H4);
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
      CZigzagSegment* segment = new CZigzagSegment(points[i+1], points[i]);
      
      // 添加到线段数组
      if(segment != NULL)
      {
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
//| 获取指定索引的H1线段                                              |
//+------------------------------------------------------------------+
CZigzagSegment* CZigzagSegmentManager::GetH1Segment(int index)
{
   if(m_segments_h1 == NULL || index < 0 || index >= m_segments_h1.Total())
      return NULL;
      
   CZigzagSegmentWrapper* wrapper = (CZigzagSegmentWrapper*)m_segments_h1.At(index);
   if(wrapper != NULL)
      return wrapper.GetSegment();
      
   return NULL;
}

//+------------------------------------------------------------------+
//| 获取指定索引的H4线段                                              |
//+------------------------------------------------------------------+
CZigzagSegment* CZigzagSegmentManager::GetH4Segment(int index)
{
   if(m_segments_h4 == NULL || index < 0 || index >= m_segments_h4.Total())
      return NULL;
      
   CZigzagSegmentWrapper* wrapper = (CZigzagSegmentWrapper*)m_segments_h4.At(index);
   if(wrapper != NULL)
      return wrapper.GetSegment();
      
   return NULL;
}

//+------------------------------------------------------------------+
//| 获取最近的N个H1线段                                               |
//+------------------------------------------------------------------+
bool CZigzagSegmentManager::GetRecentH1Segments(CZigzagSegment* &segments[], int count)
{
   if(m_segments_h1 == NULL)
      return false;
      
   int total = m_segments_h1.Total();
   
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
      segments[i] = GetH1Segment(i);
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| 获取最近的N个H4线段                                               |
//+------------------------------------------------------------------+
bool CZigzagSegmentManager::GetRecentH4Segments(CZigzagSegment* &segments[], int count)
{
   if(m_segments_h4 == NULL)
      return false;
      
   int total = m_segments_h4.Total();
   
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
      segments[i] = GetH4Segment(i);
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| 获取上涨趋势的H1线段                                              |
//+------------------------------------------------------------------+
bool CZigzagSegmentManager::GetUptrendH1Segments(CZigzagSegment* &segments[], int maxCount)
{
   if(m_segments_h1 == NULL)
      return false;
      
   int total = m_segments_h1.Total();
   
   // 检查参数有效性
   if(maxCount <= 0 || total == 0)
      return false;
   
   // 临时数组，用于存储上涨线段
   CZigzagSegment* tempSegments[];
   ArrayResize(tempSegments, total);
   
   // 找出所有上涨线段
   int count = 0;
   for(int i = 0; i < total && count < maxCount; i++)
   {
      CZigzagSegment* segment = GetH1Segment(i);
      if(segment != NULL && segment.IsUptrend())
      {
         tempSegments[count++] = segment;
      }
   }
   
   // 调整结果数组大小
   ArrayResize(segments, count);
   
   // 复制上涨线段
   for(int i = 0; i < count; i++)
   {
      segments[i] = tempSegments[i];
   }
   
   return count > 0;
}

//+------------------------------------------------------------------+
//| 获取下跌趋势的H1线段                                              |
//+------------------------------------------------------------------+
bool CZigzagSegmentManager::GetDowntrendH1Segments(CZigzagSegment* &segments[], int maxCount)
{
   if(m_segments_h1 == NULL)
      return false;
      
   int total = m_segments_h1.Total();
   
   // 检查参数有效性
   if(maxCount <= 0 || total == 0)
      return false;
   
   // 临时数组，用于存储下跌线段
   CZigzagSegment* tempSegments[];
   ArrayResize(tempSegments, total);
   
   // 找出所有下跌线段
   int count = 0;
   for(int i = 0; i < total && count < maxCount; i++)
   {
      CZigzagSegment* segment = GetH1Segment(i);
      if(segment != NULL && segment.IsDowntrend())
      {
         tempSegments[count++] = segment;
      }
   }
   
   // 调整结果数组大小
   ArrayResize(segments, count);
   
   // 复制下跌线段
   for(int i = 0; i < count; i++)
   {
      segments[i] = tempSegments[i];
   }
   
   return count > 0;
}

//+------------------------------------------------------------------+
//| 获取上涨趋势的H4线段                                              |
//+------------------------------------------------------------------+
bool CZigzagSegmentManager::GetUptrendH4Segments(CZigzagSegment* &segments[], int maxCount)
{
   if(m_segments_h4 == NULL)
      return false;
      
   int total = m_segments_h4.Total();
   
   // 检查参数有效性
   if(maxCount <= 0 || total == 0)
      return false;
   
   // 临时数组，用于存储上涨线段
   CZigzagSegment* tempSegments[];
   ArrayResize(tempSegments, total);
   
   // 找出所有上涨线段
   int count = 0;
   for(int i = 0; i < total && count < maxCount; i++)
   {
      CZigzagSegment* segment = GetH4Segment(i);
      if(segment != NULL && segment.IsUptrend())
      {
         tempSegments[count++] = segment;
      }
   }
   
   // 调整结果数组大小
   ArrayResize(segments, count);
   
   // 复制上涨线段
   for(int i = 0; i < count; i++)
   {
      segments[i] = tempSegments[i];
   }
   
   return count > 0;
}

//+------------------------------------------------------------------+
//| 获取下跌趋势的H4线段                                              |
//+------------------------------------------------------------------+
bool CZigzagSegmentManager::GetDowntrendH4Segments(CZigzagSegment* &segments[], int maxCount)
{
   if(m_segments_h4 == NULL)
      return false;
      
   int total = m_segments_h4.Total();
   
   // 检查参数有效性
   if(maxCount <= 0 || total == 0)
      return false;
   
   // 临时数组，用于存储下跌线段
   CZigzagSegment* tempSegments[];
   ArrayResize(tempSegments, total);
   
   // 找出所有下跌线段
   int count = 0;
   for(int i = 0; i < total && count < maxCount; i++)
   {
      CZigzagSegment* segment = GetH4Segment(i);
      if(segment != NULL && segment.IsDowntrend())
      {
         tempSegments[count++] = segment;
      }
   }
   
   // 调整结果数组大小
   ArrayResize(segments, count);
   
   // 复制下跌线段
   for(int i = 0; i < count; i++)
   {
      segments[i] = tempSegments[i];
   }
   
   return count > 0;
}

//+------------------------------------------------------------------+
//| 清除所有线段                                                      |
//+------------------------------------------------------------------+
void CZigzagSegmentManager::Clear()
{
   if(m_segments_h1 != NULL)
      m_segments_h1.Clear();
      
   if(m_segments_h4 != NULL)
      m_segments_h4.Clear();
}

//+------------------------------------------------------------------+
//| 打印H1线段信息（用于调试）                                        |
//+------------------------------------------------------------------+
void CZigzagSegmentManager::PrintH1Segments(int count)
{
   if(m_segments_h1 == NULL)
      return;
      
   int total = m_segments_h1.Total();
   
   // 调整count，不超过实际线段数量
   count = MathMin(count, total);
   
   Print("===== H1 ZigZag线段信息 =====");
   for(int i = 0; i < count; i++)
   {
      CZigzagSegment* segment = GetH1Segment(i);
      if(segment != NULL)
      {
         Print(i, ": ", segment.ToString());
      }
   }
   Print("=========================");
}

//+------------------------------------------------------------------+
//| 打印H4线段信息（用于调试）                                        |
//+------------------------------------------------------------------+
void CZigzagSegmentManager::PrintH4Segments(int count)
{
   if(m_segments_h4 == NULL)
      return;
      
   int total = m_segments_h4.Total();
   
   // 调整count，不超过实际线段数量
   count = MathMin(count, total);
   
   Print("===== H4 ZigZag线段信息 =====");
   for(int i = 0; i < count; i++)
   {
      CZigzagSegment* segment = GetH4Segment(i);
      if(segment != NULL)
      {
         Print(i, ": ", segment.ToString());
      }
   }
   Print("=========================");
}
//+------------------------------------------------------------------+