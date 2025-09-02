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

//+------------------------------------------------------------------+
//| 动态交易点类 - 封装交易参考基准价格                                 |
//| 提供基于交易参考价格的线段查询和分析功能                            |
//+------------------------------------------------------------------+
class CTradeBasePoint
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
 
   // 计算基准价格在不同周期上的位置
   void CalculatePositionInTimeframes();
   
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
   
   // 计算基准价格在不同周期上的位置
   CalculatePositionInTimeframes();
   
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
//| 计算基准价格在不同周期上的位置                                     |
//+------------------------------------------------------------------+
void CTradeBasePoint::CalculatePositionInTimeframes()
{
   if(m_basePrice <= 0.0 || m_baseTime == 0)
      return;
   
   // 如果有当前线段对象，则使用GetSmallerTimeframeSegments方法获取更小周期的线段
   if(m_currentSegment != NULL)
   {
      // 我们不再需要保存线段管理器，直接使用GetSmallerTimeframeSegments方法获取线段
      // 这样可以避免不必要的内存占用
   }
   else
   {
      // 如果没有当前线段对象，则使用原有的计算方法
      // 创建H1周期的ZigZag计算器
      int h1BarsCount = 500;
      CZigzagCalculator h1ZigzagCalc(12, 5, 3, h1BarsCount, PERIOD_H1);
      
      if(h1ZigzagCalc.CalculateForSymbol(Symbol(), PERIOD_H1, h1BarsCount))
      {
         CZigzagExtremumPoint h1Points[];
         if(h1ZigzagCalc.GetExtremumPoints(h1Points) && ArraySize(h1Points) >= 2)
         {
            // 生成H1线段
            int h1PointCount = ArraySize(h1Points);
            CZigzagSegment* h1Segments[];
            ArrayResize(h1Segments, h1PointCount - 1);
            
            for(int i = 0; i < h1PointCount - 1; i++)
            {
               h1Points[i].Timeframe(PERIOD_H1);
               h1Points[i+1].Timeframe(PERIOD_H1);
               
               h1Segments[i] = new CZigzagSegment(h1Points[i+1], h1Points[i], PERIOD_H1);
            }
            
            // 释放H1线段数组中的对象
            for(int i = 0; i < ArraySize(h1Segments); i++)
            {
               if(h1Segments[i] != NULL)
               {
                  delete h1Segments[i];
                  h1Segments[i] = NULL;
               }
            }
            ArrayResize(h1Segments, 0);
         }
      }
      
      // 创建M5周期的ZigZag计算器
      int m5BarsCount = 2000;
      CZigzagCalculator m5ZigzagCalc(12, 5, 3, m5BarsCount, PERIOD_M5);
      
      if(m5ZigzagCalc.CalculateForSymbol(Symbol(), PERIOD_M5, m5BarsCount))
      {
         CZigzagExtremumPoint m5Points[];
         if(m5ZigzagCalc.GetExtremumPoints(m5Points) && ArraySize(m5Points) >= 2)
         {
            // 生成M5线段
            int m5PointCount = ArraySize(m5Points);
            CZigzagSegment* m5Segments[];
            ArrayResize(m5Segments, m5PointCount - 1);
            
            for(int i = 0; i < m5PointCount - 1; i++)
            {
               m5Points[i].Timeframe(PERIOD_M5);
               m5Points[i+1].Timeframe(PERIOD_M5);
               
               m5Segments[i] = new CZigzagSegment(m5Points[i+1], m5Points[i], PERIOD_M5);
            }
            
            // 释放M5线段数组中的对象
            for(int i = 0; i < ArraySize(m5Segments); i++)
            {
               if(m5Segments[i] != NULL)
               {
                  delete m5Segments[i];
                  m5Segments[i] = NULL;
               }
            }
            ArrayResize(m5Segments, 0);
         }
      }
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
      
   // 获取指定时间周期的线段管理器
   CZigzagSegmentManager* segmentManager = m_currentSegment.GetSmallerTimeframeSegments(timeframe, true);
   if(segmentManager == NULL)
      return false;
      
   CZigzagSegment* totalSegments[];
   if(!segmentManager.GetSegments(totalSegments))
   {
      delete segmentManager;
      return false;
   }    
   
   // 查找关键分隔线段（比较价格）
   int pivotIndex = -1;
   int segmentCount = ArraySize(totalSegments);
   for(int i = 0; i < segmentCount; i++)
   {
      if(totalSegments[i] != NULL)
      {
         // 匹配开始点
         if(totalSegments[i].StartPrice() == m_basePrice)
         {
            pivotIndex = i;
            break;
         }
      }
   }

   // 处理左侧线段（关键线段之后的所有线段）
   int leftCount = 0;
   if(pivotIndex >= 0)
   {
      leftCount = segmentCount - pivotIndex - 1; // 不包括关键线段
      ArrayResize(leftSegments, leftCount);
      for(int i = pivotIndex + 1; i < segmentCount; i++)
      {
         leftSegments[i - pivotIndex - 1] = new CZigzagSegment(*totalSegments[i]);
      }
   } 

   // 处理右侧线段（关键线段之前的所有线段，包括关键线段本身）
   int rightCount = 0;
   if(pivotIndex >= 0)
   {
      rightCount = pivotIndex + 1; // 包括关键线段本身
      ArrayResize(rightSegments, rightCount);
      for(int i = 0; i <= pivotIndex; i++)
      {
         rightSegments[i] = new CZigzagSegment(*totalSegments[i]);
      }
   }
  
   delete segmentManager;
   
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
