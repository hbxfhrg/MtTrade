//+------------------------------------------------------------------+
//|                                                TradeBasePoint.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

// 引入必要的头文件
#include "ZigzagSegment.mqh"
#include "ZigzagSegmentManager.mqh"
#include "CommonUtils.mqh"
#include "LogUtil.mqh"
#include "EnumDefinitions.mqh"
#include <Generic/HashMap.mqh>
#include "KeyValueStore.mqh"

//+------------------------------------------------------------------+
//| 动态交易点类 - 封装交易参考基准价格                                 |
//| 提供基于交易参考价格的线段查询和分析功能                            |
//+------------------------------------------------------------------+
class CTradeBasePoint:public CObject
{
private:
   // 交易参考基准价格和时间
   double            m_basePrice;        // 交易参考基准价格
   datetime          m_baseTime;         // 交易参考基准价格对应的时间
   int               m_barIndex;         // 交易参考基准价格在当前周期上的序号
   bool              m_isValid;          // 数据是否有效
   
   // 参考点类型
   ENUM_REFERENCE_POINT_TYPE m_referencePointType; // 参考点是高点还是低点
   
   // 当前线段对象引用
   CZigzagSegment*   m_currentSegment;   // 当前线段对象引用
   
  
   
   // 查找与基准价格匹配的K线序号
   int FindMatchingCandleIndex(double basePrice, ENUM_TIMEFRAMES timeframe);
   
   // 释放资源
   void ReleaseResources();
   


public:
   // 构造函数和析构函数
   CTradeBasePoint(double basePrice = 0.0);
   CTradeBasePoint(const CTradeBasePoint &other); // 拷贝构造函数
   ~CTradeBasePoint();
   KeyValueStore m_leftSegmentsStore;  // 左线段缓存
   KeyValueStore m_rightSegmentsStore; // 右线段缓存

  
   // 初始化方法
   bool Initialize(double basePrice);
   
   // 设置当前线段对象
   void SetCurrentSegment(CZigzagSegment* currentSegment) { m_currentSegment = currentSegment; }
   
   // 设置参考点类型
   void SetReferencePointType(ENUM_REFERENCE_POINT_TYPE refType) { m_referencePointType = refType; }
   
   // 获取基准价格和时间
   double GetBasePrice() const { return m_basePrice; }
   datetime GetBaseTime() const { return m_baseTime; }
   int GetBarIndex() const { return m_barIndex; }
   bool IsValid() const { return m_isValid; }
   
   // 获取参考点类型
   ENUM_REFERENCE_POINT_TYPE GetReferencePointType() const { return m_referencePointType; }
   
   // 通用方法：获取指定时间周期的左右线段
   bool GetTimeframeSegments(ENUM_TIMEFRAMES timeframe, CZigzagSegment* &leftSegments[], CZigzagSegment* &rightSegments[]);
   
   // 获取指定时间周期的缓存左右线段数组
   bool GetTimeframeCachedSegments(ENUM_TIMEFRAMES timeframe, CZigzagSegment* &leftSegments[], CZigzagSegment* &rightSegments[]);
   
   // 缓存指定时间周期的左右线段数组
   bool CacheSegmentsForTimeframe(ENUM_TIMEFRAMES timeframe);
   
   // 缓存所有时间周期的左右线段数组
   bool CacheAllSegments();
    
   // 获取基准价格描述
   string GetDescription() const;
};

//+------------------------------------------------------------------+
//| 构造函数                                                          |
//+------------------------------------------------------------------+
CTradeBasePoint::CTradeBasePoint(double basePrice)
{
   m_basePrice = 0.0;
   m_baseTime = 0;
   m_barIndex = -1;
   m_isValid = false;
   m_referencePointType = REFERENCE_POINT_HIGH; // 默认设置为高点
   m_currentSegment = NULL;  // 初始化当前线段对象
   
   // 重置KeyValueStore缓存
   m_leftSegmentsStore.Clear();
   m_rightSegmentsStore.Clear();
   
   if(basePrice > 0.0)
      Initialize(basePrice);
}

//+------------------------------------------------------------------+
//| 拷贝构造函数                                                      |
//+------------------------------------------------------------------+
CTradeBasePoint::CTradeBasePoint(const CTradeBasePoint &other)
{
   m_basePrice = other.m_basePrice;
   m_baseTime = other.m_baseTime;
   m_barIndex = other.m_barIndex;
   m_isValid = other.m_isValid;
   m_referencePointType = other.m_referencePointType; // 复制参考点类型
   m_currentSegment = other.m_currentSegment;  // 复制当前线段对象引用
   
   // 注意：对于指针成员，我们只复制指针而不复制指向的对象
   // 这是因为线段管理器对象由其他部分管理
}

//+------------------------------------------------------------------+
//| 释放资源                                                          |
//+------------------------------------------------------------------+
void CTradeBasePoint::ReleaseResources()
{
   // 重置KeyValueStore缓存
   m_leftSegmentsStore.Clear();
   m_rightSegmentsStore.Clear();
}

//+------------------------------------------------------------------+
//| 初始化方法                                                        |
//+------------------------------------------------------------------+
bool CTradeBasePoint::Initialize(double basePrice)
{
   // 清理旧资源
   ReleaseResources();
   
   // 设置基准价格
   m_basePrice = basePrice;
   
   if(m_basePrice <= 0.0)
   {
      m_isValid = false;
      return false;
   }
   
   // 查找基准价格对应的K线序号
   m_barIndex = FindMatchingCandleIndex(m_basePrice, PERIOD_CURRENT);
   
   if(m_barIndex < 0)
   {
      m_isValid = false;
      return false;
   }
   
   // 获取基准价格对应的时间
   m_baseTime = iTime(Symbol(), PERIOD_CURRENT, m_barIndex);
   
      
   m_isValid = true; 
   
   
   return true;
}

//+------------------------------------------------------------------+
//| 查找与基准价格匹配的K线序号                                        |
//+------------------------------------------------------------------+
int CTradeBasePoint::FindMatchingCandleIndex(double basePrice, ENUM_TIMEFRAMES timeframe)
{
   if(basePrice <= 0.0)
      return -1;
      
   // 根据参考点类型直接决定使用高价还是低价查找
   if(m_referencePointType == REFERENCE_POINT_HIGH)
   {
      // 高点参考点，查找高价匹配
      return ::FindBarIndexByPrice(basePrice, MODE_HIGH, timeframe);
   }
   else if(m_referencePointType == REFERENCE_POINT_LOW)
   {
      // 低点参考点，查找低价匹配
      return ::FindBarIndexByPrice(basePrice, MODE_LOW, timeframe);
   }
   else
   {
      // 默认情况，返回-1表示未找到
      return -1;
   }
}


//+------------------------------------------------------------------+
//| 获取基准价格描述                                                  |
//+------------------------------------------------------------------+
string CTradeBasePoint::GetDescription() const
{
   if(!m_isValid)
      return "交易基准点: 无效";
      
   string priceText = DoubleToString(m_basePrice, _Digits);
   string timeText = TimeToString(m_baseTime);
   string barIndexText = IntegerToString(m_barIndex);
   
   return StringFormat("交易基准点: 价格=%s, 时间=%s, K线序号=%s", 
                      priceText, timeText, barIndexText);
}

//+------------------------------------------------------------------+
//| 析构函数                                                          |
//+------------------------------------------------------------------+
CTradeBasePoint::~CTradeBasePoint()
{
   ReleaseResources();
}

//+------------------------------------------------------------------+
//| 通用方法：获取指定时间周期的左右线段                              |
//+------------------------------------------------------------------+
bool CTradeBasePoint::GetTimeframeSegments(ENUM_TIMEFRAMES timeframe, CZigzagSegment* &leftSegments[], CZigzagSegment* &rightSegments[])
{
   if(!m_isValid || m_currentSegment == NULL)
      return false;
      
   // 调试日志：记录当前处理的时间周期
   string timeframeName = EnumToString(timeframe);
   Print("GetTimeframeSegments: 开始处理周期 ", timeframeName);
      
   // 获取指定时间周期的线段管理器
   CZigzagSegmentManager* segmentManager = m_currentSegment.GetSmallerTimeframeSegments(timeframe, true);
   if(segmentManager == NULL)
   {
      Print("GetTimeframeSegments: 周期 ", timeframeName, " - 获取线段管理器失败");
      return false;
   }
      
   CZigzagSegment* totalSegments[];
   if(!segmentManager.GetSegments(totalSegments))
   {
      Print("GetTimeframeSegments: 周期 ", timeframeName, " - 获取线段数组失败");
      
      return false;
   }    
   
   // 调试日志：记录获取到的线段数量
   int segmentCount = ArraySize(totalSegments);
   Print("GetTimeframeSegments: 周期 ", timeframeName, " - 获取到 ", segmentCount, " 条线段");
   
   // 查找关键分隔线段（比较价格）
   int pivotIndex = -1;
   for(int i = 0; i < segmentCount; i++)
   {
      if(totalSegments[i] != NULL)
      {
         // 调试日志：检查每个线段的指针有效性
         if(!CheckPointer(totalSegments[i]))
         {
            Print("GetTimeframeSegments: 周期 ", timeframeName, " - 第 ", i, " 条线段指针无效");
            continue;
         }
         
         // 匹配开始点
         if(totalSegments[i].m_end_point.value == m_basePrice)
         {
            pivotIndex = i;
            Print("GetTimeframeSegments: 周期 ", timeframeName, " - 找到匹配的关键线段，索引: ", pivotIndex);
            break;
         }
      }
      else
      {
         Print("GetTimeframeSegments: 周期 ", timeframeName, " - 第 ", i, " 条线段为NULL");
      }
   }

   // 处理左侧线段（关键线段之后的所有线段，含关键线段本身）
   int leftCount = 0;
   if(pivotIndex >= 0)
   {
      leftCount = segmentCount - pivotIndex; 
      Print("GetTimeframeSegments: 周期 ", timeframeName, " - 左侧线段数量: ", leftCount, ", pivotIndex: ", pivotIndex);
      ArrayResize(leftSegments, leftCount);
      for(int i = pivotIndex; i < segmentCount; i++)
      {
         // 调试日志：记录每个左侧线段的处理
         int targetIndex = i - pivotIndex;
         if(totalSegments[i] != NULL && CheckPointer(totalSegments[i]))
         {
            leftSegments[targetIndex] = new CZigzagSegment(*totalSegments[i]);
            Print("GetTimeframeSegments: 周期 ", timeframeName, " - 创建左侧线段 ", targetIndex, ", 源索引: ", i);
         }
         else
         {
            Print("GetTimeframeSegments: 周期 ", timeframeName, " - 左侧线段源索引 ", i, " 指针无效");
            leftSegments[targetIndex] = NULL;
         }
      }
   } 

   // 处理右侧线段（关键线段之前的所有线段，不包括关键线段本身）
   int rightCount = 0;
   if(pivotIndex >= 0)
   {
      rightCount = pivotIndex; 
      Print("GetTimeframeSegments: 周期 ", timeframeName, " - 右侧线段数量: ", rightCount, ", pivotIndex: ", pivotIndex);
      ArrayResize(rightSegments, rightCount);
      for(int i = 0; i < pivotIndex; i++)
      {
         if(totalSegments[i] != NULL && CheckPointer(totalSegments[i]))
         {
            rightSegments[i] = new CZigzagSegment(*totalSegments[i]);
            Print("GetTimeframeSegments: 周期 ", timeframeName, " - 创建右侧线段 ", i);
         }
         else
         {
            Print("GetTimeframeSegments: 周期 ", timeframeName, " - 右侧线段源索引 ", i, " 指针无效");
            rightSegments[i] = NULL;
         }
      }
   }
  
   // 注意：totalSegments数组由segmentManager.GetSegments()创建
   // segmentManager会在函数结束时自动释放，totalSegments数组也会随之自动释放
   // 不需要手动删除数组元素
   
   
   // 对左右线段按时间顺序排序
   if(leftCount > 0)
   {
      ::SortSegmentsByTime(leftSegments, false, false); // 反序，使用开始时间（从晚到早）
   }
   
   if(rightCount > 0)
   {
      ::SortSegmentsByTime(rightSegments, true, false); // 正序，使用开始时间（从早到晚）
   }
   
   return (leftCount > 0 || rightCount > 0);
}

//+------------------------------------------------------------------+
//| 查找并缓存指定时间周期的左右线段数组                              |
//+------------------------------------------------------------------+
bool CTradeBasePoint::CacheSegmentsForTimeframe(ENUM_TIMEFRAMES timeframe)
{
   if(!m_isValid || m_currentSegment == NULL)
      return false;
      

   
   // 获取指定时间周期的所有线段
   CZigzagSegment* leftSegments[];
   CZigzagSegment* rightSegments[];
   
   if(!GetTimeframeSegments(timeframe, leftSegments, rightSegments))
   {
      return false;
   }
      
   int timeframeIndex = -1;
   switch(timeframe)
   {
      case PERIOD_M5:  timeframeIndex = 0; break;
      case PERIOD_M15: timeframeIndex = 1; break;
      case PERIOD_M30: timeframeIndex = 2; break;
      case PERIOD_H1:  timeframeIndex = 3; break;
      default: 
         return false;
   }
   
   // 使用KeyValueStore存储线段数组
   if(ArraySize(leftSegments) > 0)
   {
      m_leftSegmentsStore.SetArray(timeframeIndex, leftSegments);
   }
   
   if(ArraySize(rightSegments) > 0)
   {
      m_rightSegmentsStore.SetArray(timeframeIndex, rightSegments);
   }
      
   bool hasLeft = (ArraySize(leftSegments) > 0);
   bool hasRight = (ArraySize(rightSegments) > 0);
   return (hasLeft || hasRight);
}

//+------------------------------------------------------------------+
//| 缓存所有时间周期的左右线段数组                                    |
//+------------------------------------------------------------------+
bool CTradeBasePoint::CacheAllSegments()
{
   if(!m_isValid || m_currentSegment == NULL)
      return false;
      
   // 移除1分钟周期，避免堆栈溢出和性能问题
   ENUM_TIMEFRAMES timeframes[] = {PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1};
   bool success = true;
   
   for(int i = 0; i < ArraySize(timeframes); i++)
   {
      if(!CacheSegmentsForTimeframe(timeframes[i]))
      {
         success = false;
      }
   }
   
   return success;
}

//+------------------------------------------------------------------+
//| 获取指定时间周期的左右线段数组（带缓存）                          |
//+------------------------------------------------------------------+
bool CTradeBasePoint::GetTimeframeCachedSegments(ENUM_TIMEFRAMES timeframe, CZigzagSegment* &leftSegments[], CZigzagSegment* &rightSegments[])
{
   if(!m_isValid)
      return false;
      

   

   
   // 从KeyValueStore获取缓存
   int timeframeIndex = -1;
   switch(timeframe)
   {
      case PERIOD_M5:  timeframeIndex = 0; break;
      case PERIOD_M15: timeframeIndex = 1; break;
      case PERIOD_M30: timeframeIndex = 2; break;
      case PERIOD_H1:  timeframeIndex = 3; break;
      default: 
         return false;
   }
   
   bool hasLeft = false;
   bool hasRight = false;
   
   CZigzagSegment* leftSeg = NULL;
   if(m_leftSegmentsStore.Get(timeframeIndex, leftSeg) && leftSeg != NULL)
   {
      ArrayResize(leftSegments, 1);
      leftSegments[0] = leftSeg;
      hasLeft = true;
   }
   
   CZigzagSegment* rightSeg = NULL;
   if(m_rightSegmentsStore.Get(timeframeIndex, rightSeg) && rightSeg != NULL)
   {
      ArrayResize(rightSegments, 1);
      rightSegments[0] = rightSeg;
      hasRight = true;
   }
   
   // 如果缓存中不存在，尝试查找并缓存
   if(!hasLeft && !hasRight)
   {
      if(CacheSegmentsForTimeframe(timeframe))
      {
         return GetTimeframeCachedSegments(timeframe, leftSegments, rightSegments);
      }
      return false;
   }
   
   return (hasLeft || hasRight);
}
