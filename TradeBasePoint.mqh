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
   
   // 获取基准价格和时间
   double GetBasePrice() const { return m_basePrice; }
   datetime GetBaseTime() const { return m_baseTime; }
   int GetBarIndex() const { return m_barIndex; }
   bool IsValid() const { return m_isValid; }
   
   // 获取基于基准价格的线段
   bool GetM5Segments(CZigzagSegment* &leftSegments[], CZigzagSegment* &rightSegments[]); // 同时获取左右M5线段
   bool GetLeftH1Segments(CZigzagSegment* &segments[]);   // 获取基准价格左侧的H1线段
   bool GetRightH1Segments(CZigzagSegment* &segments[]);  // 获取基准价格右侧的H1线段
 
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
      
   // 获取当前品种的K线数量
   int bars = Bars(Symbol(), timeframe);
   int priceShift = -1;
   
   // 遍历K线，查找与基准价格匹配的K线
   for(int i = 0; i < bars && i < 500; i++) // 限制搜索范围，避免过度消耗资源
   {
      double high = iHigh(Symbol(), timeframe, i);
      double low = iLow(Symbol(), timeframe, i);
      
      // 如果价格在当前K线的范围内或非常接近
      if((basePrice <= high && basePrice >= low) || 
         MathAbs(high - basePrice) < Point() * 10 || 
         MathAbs(low - basePrice) < Point() * 10)
      {
         priceShift = i;
         break;
      }
   }
   
   return priceShift;
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
//| 获取基准价格左侧的H1线段                                           |
//+------------------------------------------------------------------+
bool CTradeBasePoint::GetLeftH1Segments(CZigzagSegment* &segments[])
{
   if(!m_isValid || m_currentSegment == NULL)
      return false;
      
   // 直接使用当前线段对象获取H1周期的线段管理器
   CZigzagSegmentManager* h1SegmentManager = m_currentSegment.GetSmallerTimeframeSegments(PERIOD_H1, true);
   if(h1SegmentManager == NULL)
      return false;
      
   // 获取所有H1线段
   CZigzagSegment* allH1Segments[];
   if(!h1SegmentManager.GetSegments(allH1Segments))
   {
      delete h1SegmentManager;
      return false;
   }
      
   int totalSegments = ArraySize(allH1Segments);
   if(totalSegments == 0)
   {
      // 释放资源
      for(int i = 0; i < ArraySize(allH1Segments); i++)
      {
         if(allH1Segments[i] != NULL)
         {
            delete allH1Segments[i];
            allH1Segments[i] = NULL;
         }
      }
      ArrayResize(allH1Segments, 0);
      delete h1SegmentManager;
      return false;
   }
      
   // 筛选出基准价格左侧的线段（结束时间早于基准价格时间）
   CZigzagSegment* leftSegments[];
   int leftCount = 0;
   
   for(int i = 0; i < totalSegments; i++)
   {
      if(allH1Segments[i] != NULL && allH1Segments[i].EndTime() <= m_baseTime)
      {
         ArrayResize(leftSegments, leftCount + 1);
         leftSegments[leftCount++] = allH1Segments[i];
      }
      else if(allH1Segments[i] != NULL)
      {
         // 释放不在筛选范围内的线段
         delete allH1Segments[i];
         allH1Segments[i] = NULL;
      }
   }
   
   // 按时间排序（最近的在前）
   ::SortSegmentsByTime(leftSegments, false, true);
   
   // 复制结果
   ArrayResize(segments, leftCount);
   for(int i = 0; i < leftCount; i++)
   {
      segments[i] = new CZigzagSegment(*leftSegments[i]);
   }
   
   // 释放临时数组
   for(int i = 0; i < ArraySize(allH1Segments); i++)
   {
      if(allH1Segments[i] != NULL)
      {
         delete allH1Segments[i];
         allH1Segments[i] = NULL;
      }
   }
   ArrayResize(allH1Segments, 0);
   
   for(int i = 0; i < leftCount; i++)
   {
      if(leftSegments[i] != NULL)
      {
         delete leftSegments[i];
         leftSegments[i] = NULL;
      }
   }
   ArrayResize(leftSegments, 0);
   
   // 释放线段管理器
   delete h1SegmentManager;
   
   return leftCount > 0;
}

//+------------------------------------------------------------------+
//| 获取基准价格右侧的H1线段                                           |
//+------------------------------------------------------------------+
bool CTradeBasePoint::GetRightH1Segments(CZigzagSegment* &segments[])
{
   if(!m_isValid || m_currentSegment == NULL)
      return false;
      
   // 直接使用当前线段对象获取H1周期的线段管理器
   CZigzagSegmentManager* h1SegmentManager = m_currentSegment.GetSmallerTimeframeSegments(PERIOD_H1, true);
   if(h1SegmentManager == NULL)
      return false;
      
   // 获取所有H1线段
   CZigzagSegment* allH1Segments[];
   if(!h1SegmentManager.GetSegments(allH1Segments))
   {
      delete h1SegmentManager;
      return false;
   }
      
   int totalSegments = ArraySize(allH1Segments);
   if(totalSegments == 0)
   {
      // 释放资源
      for(int i = 0; i < ArraySize(allH1Segments); i++)
      {
         if(allH1Segments[i] != NULL)
         {
            delete allH1Segments[i];
            allH1Segments[i] = NULL;
         }
      }
      ArrayResize(allH1Segments, 0);
      delete h1SegmentManager;
      return false;
   }
      
   // 筛选出基准价格右侧的线段（开始时间晚于基准价格时间）
   CZigzagSegment* rightSegments[];
   int rightCount = 0;
   
   for(int i = 0; i < totalSegments; i++)
   {
      if(allH1Segments[i] != NULL && allH1Segments[i].StartTime() >= m_baseTime)
      {
         ArrayResize(rightSegments, rightCount + 1);
         rightSegments[rightCount++] = allH1Segments[i];
      }
      else if(allH1Segments[i] != NULL)
      {
         // 释放不在筛选范围内的线段
         delete allH1Segments[i];
         allH1Segments[i] = NULL;
      }
   }
   
   // 按时间排序（最近的在前）
   ::SortSegmentsByTime(rightSegments, false, true);
   
   // 复制结果
   ArrayResize(segments, rightCount);
   for(int i = 0; i < rightCount; i++)
   {
      segments[i] = new CZigzagSegment(*rightSegments[i]);
   }
   
   // 释放临时数组
   for(int i = 0; i < ArraySize(allH1Segments); i++)
   {
      if(allH1Segments[i] != NULL)
      {
         delete allH1Segments[i];
         allH1Segments[i] = NULL;
      }
   }
   ArrayResize(allH1Segments, 0);
   
   for(int i = 0; i < rightCount; i++)
   {
      if(rightSegments[i] != NULL)
      {
         delete rightSegments[i];
         rightSegments[i] = NULL;
      }
   }
   ArrayResize(rightSegments, 0);
   
   // 释放线段管理器
   delete h1SegmentManager;
   
   return rightCount > 0;
}


//+------------------------------------------------------------------+
//| 获取基准点左右的M5线段                                             |
//+------------------------------------------------------------------+
bool CTradeBasePoint::GetM5Segments(CZigzagSegment* &leftSegments[], CZigzagSegment* &rightSegments[])
{
   if(!m_isValid || m_currentSegment == NULL)
      return false;
      
   CZigzagSegmentManager* m5SegmentManager = m_currentSegment.GetSmallerTimeframeSegments(PERIOD_M5, true);
   if(m5SegmentManager == NULL)
      return false;
      
   CZigzagSegment* totalSegments[];
   if(!m5SegmentManager.GetSegments(totalSegments))
   {
      delete m5SegmentManager;
      return false;
   }    
   

   // 查找关键分隔线段（比较价格）
   int pivotIndex = -1;
   int segmentCount = ArraySize(totalSegments);
   for(int i = 0; i < segmentCount; i++)
   {
      if(totalSegments[i] != NULL)
      {
         // 匹配开始点或结束点
         if(totalSegments[i].StartPrice() == m_basePrice)
         {
            pivotIndex = i;
            break;
         }
      }
   }

   // 处理左侧线段（关键线段之前的所有线段）
   int leftCount = 0;
   if(pivotIndex >= 0)
   {
      leftCount = pivotIndex + 1; // 包括关键线段本身
      ArrayResize(leftSegments, leftCount);
      for(int i = 0; i <= pivotIndex; i++)
      {
         leftSegments[i] = new CZigzagSegment(*totalSegments[i]);
      }
   } 

   // 处理右侧线段（关键线段之后的所有线段）
   int rightCount = 0;
   if(pivotIndex >= 0)
   {
      rightCount = segmentCount - pivotIndex - 1; // 不包括关键线段
      ArrayResize(rightSegments, rightCount);
      for(int i = pivotIndex + 1; i < segmentCount; i++)
      {
         rightSegments[i - pivotIndex - 1] = new CZigzagSegment(*totalSegments[i]);
      }
   }
  

   delete m5SegmentManager;
   
   return (leftCount > 0 || rightCount > 0);
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
