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
   CZigzagSegment*      m_segments[];        // 线段数组，承接线段类中取小周期返回的线段
   CZigzagSegment*      m_main_segment;      // 主交易线段，离现在最近的一个线段
   int                  m_max_segments;      // 最大线段数量
   
public:
                     CZigzagSegmentManager(int maxSegments = 50);
                     CZigzagSegmentManager(CZigzagSegment* &segments[], int segmentCount, int maxSegments = 50);
                    ~CZigzagSegmentManager();
   
   // 获取线段数组
   bool              GetSegments(CZigzagSegment* &segments[], int maxCount);
   
   // 获取主交易线段
   CZigzagSegment*   GetMainSegment() const { return m_main_segment; }
   
   // 设置主交易线段
   void              SetMainSegment(CZigzagSegment* segment) { m_main_segment = segment; }
   
   // 获取特定类型的线段（上涨/下跌）
   bool              GetUptrendSegments(CZigzagSegment* &segments[], int maxCount);
   bool              GetDowntrendSegments(CZigzagSegment* &segments[], int maxCount);
   
   // 清除所有线段
   void              Clear();
};

//+------------------------------------------------------------------+
//| 构造函数                                                          |
//+------------------------------------------------------------------+
CZigzagSegmentManager::CZigzagSegmentManager(int maxSegments)
{
   m_max_segments = maxSegments;
   m_main_segment = NULL;
   ArrayResize(m_segments, 0);
}

//+------------------------------------------------------------------+
//| 从线段数组构造函数                                                |
//+------------------------------------------------------------------+
CZigzagSegmentManager::CZigzagSegmentManager(CZigzagSegment* &segments[], int segmentCount, int maxSegments)
{
   m_max_segments = MathMax(maxSegments, segmentCount);
   m_main_segment = NULL;
   
   // 复制线段数组
   int count = MathMin(segmentCount, m_max_segments);
   ArrayResize(m_segments, count);
   
   for(int i = 0; i < count; i++)
   {
      if(segments[i] != NULL)
      {
         m_segments[i] = new CZigzagSegment(*segments[i]);
         // 设置第一个线段为主交易线段（最近的线段）
         if(i == 0)
            m_main_segment = m_segments[i];
      }
   }
}

//+------------------------------------------------------------------+
//| 析构函数                                                          |
//+------------------------------------------------------------------+
CZigzagSegmentManager::~CZigzagSegmentManager()
{
   Clear();
}

//+------------------------------------------------------------------+
//| 清除所有线段                                                      |
//+------------------------------------------------------------------+
void CZigzagSegmentManager::Clear()
{
   // 释放线段数组中的所有线段
   for(int i = 0; i < ArraySize(m_segments); i++)
   {
      if(m_segments[i] != NULL)
      {
         delete m_segments[i];
         m_segments[i] = NULL;
      }
   }
   ArrayResize(m_segments, 0);
   
   // 释放主交易线段
   if(m_main_segment != NULL)
   {
      delete m_main_segment;
      m_main_segment = NULL;
   }
}

//+------------------------------------------------------------------+
//| 获取线段数组                                                      |
//+------------------------------------------------------------------+
bool CZigzagSegmentManager::GetSegments(CZigzagSegment* &segments[], int maxCount)
{
   // 检查参数有效性
   if(maxCount <= 0)
      return false;
      
   int total = ArraySize(m_segments);
   
   if(total == 0)
      return false;
   
   // 调整数组大小
   int count = MathMin(maxCount, total);
   ArrayResize(segments, count);
   
   // 复制线段
   for(int i = 0; i < count; i++)
   {
      segments[i] = new CZigzagSegment(*m_segments[i]);
   }
   
   return count > 0;
}

//+------------------------------------------------------------------+
//| 获取上涨趋势的线段                                                |
//+------------------------------------------------------------------+
bool CZigzagSegmentManager::GetUptrendSegments(CZigzagSegment* &segments[], int maxCount)
{
   int total = ArraySize(m_segments);
   
   // 检查参数有效性
   if(maxCount <= 0 || total == 0)
      return false;
   
   // 获取所有线段
   CZigzagSegment* allSegments[];
   ArrayResize(allSegments, total);
   
   for(int i = 0; i < total; i++)
   {
      allSegments[i] = new CZigzagSegment(*m_segments[i]);
   }
   
   // 使用CommonUtils中的静态方法筛选上涨线段
   bool result = FilterSegmentsByTrend(allSegments, segments, SEGMENT_TREND_UP, maxCount);
   
   // 释放临时数组中的线段
   for(int i = 0; i < total; i++)
   {
      if(allSegments[i] != NULL)
      {
         delete allSegments[i];
         allSegments[i] = NULL;
      }
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| 获取下跌趋势的线段                                                |
//+------------------------------------------------------------------+
bool CZigzagSegmentManager::GetDowntrendSegments(CZigzagSegment* &segments[], int maxCount)
{
   int total = ArraySize(m_segments);
   
   // 检查参数有效性
   if(maxCount <= 0 || total == 0)
      return false;
   
   // 获取所有线段
   CZigzagSegment* allSegments[];
   ArrayResize(allSegments, total);
   
   for(int i = 0; i < total; i++)
   {
      allSegments[i] = new CZigzagSegment(*m_segments[i]);
   }
   
   // 使用CommonUtils中的静态方法筛选下跌线段
   bool result = FilterSegmentsByTrend(allSegments, segments, SEGMENT_TREND_DOWN, maxCount);
   
   // 释放临时数组中的线段
   for(int i = 0; i < total; i++)
   {
      if(allSegments[i] != NULL)
      {
         delete allSegments[i];
         allSegments[i] = NULL;
      }
   }
   
   return result;
}
