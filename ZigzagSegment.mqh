//+------------------------------------------------------------------+
//|                                                ZigzagSegment.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

// 引入必要的头文件
#include "ZigzagExtremumPoint.mqh"
#include <Arrays\ArrayObj.mqh>  // 修复路径分隔符

// 前向声明
class CZigzagSegmentManager;
class CZigzagCalculator;
string TimeframeToString(ENUM_TIMEFRAMES timeframe); // 从CommonUtils.mqh中引用的函数

//+------------------------------------------------------------------+
//| ZigZag线段类，包含两个极值点（峰值和谷值）                           |
//+------------------------------------------------------------------+
class CZigzagSegment
{
private:
   CZigzagExtremumPoint m_start_point;   // 起始点（可能是峰值或谷值）
   CZigzagExtremumPoint m_end_point;     // 结束点（可能是谷值或峰值）
   double               m_price_diff;    // 价格差（绝对值）
   double               m_price_diff_pct; // 价格差百分比
   CZigzagSegmentManager* m_manager;     // 线段管理器引用
   ENUM_TIMEFRAMES      m_timeframe;     // 当前线段的时间周期

public:
                     CZigzagSegment();
                     CZigzagSegment(const CZigzagExtremumPoint &start, const CZigzagExtremumPoint &end);
                     CZigzagSegment(const CZigzagExtremumPoint &start, const CZigzagExtremumPoint &end, ENUM_TIMEFRAMES timeframe);
                     CZigzagSegment(const CZigzagSegment &other);
                    ~CZigzagSegment();
   
   // 设置线段管理器
   void                 SetManager(CZigzagSegmentManager* manager) { m_manager = manager; }
   
   // 获取时间周期
   ENUM_TIMEFRAMES      Timeframe() const { return m_timeframe; }
   void                 Timeframe(ENUM_TIMEFRAMES value) { m_timeframe = value; }
   
   // 获取更小周期的线段
   CZigzagSegmentManager* GetSmallerTimeframeSegments(ENUM_TIMEFRAMES smallerTimeframe);
   
   // 获取/设置属性
   CZigzagExtremumPoint StartPoint() const { return m_start_point; }
   void                 StartPoint(const CZigzagExtremumPoint &value);
   
   CZigzagExtremumPoint EndPoint() const { return m_end_point; }
   void                 EndPoint(const CZigzagExtremumPoint &value);
   
   // 获取起始点和结束点的价格和时间
   double               StartPrice() const { return m_start_point.Value(); }
   double               EndPrice() const { return m_end_point.Value(); }
   datetime             StartTime() const { return m_start_point.Time(); }
   datetime             EndTime() const { return m_end_point.Time(); }
   
   // 获取价格差相关信息
   double               PriceDiff() const { return m_price_diff; }           // 价格差（绝对值）
   double               PriceDiffPercent() const { return m_price_diff_pct; } // 价格差百分比
   double               PriceLength() const { return m_price_diff; }         // 价格长度（与PriceDiff相同，更直观的命名）
   double               PriceLengthInPips() const { return m_price_diff * MathPow(10, _Digits); } // 价格长度（以点数表示）
   
   // 计算价格差和百分比
   void                 CalculatePriceDiff();
   
   // 获取线段方向（上升/下降）
   bool                 IsUptrend() const { return m_end_point.Value() > m_start_point.Value(); }
   bool                 IsDowntrend() const { return m_end_point.Value() < m_start_point.Value(); }
   
   // 获取线段长度（K线数量）
   int                  BarCount() const { return MathAbs(m_end_point.BarIndex() - m_start_point.BarIndex()); }
   
   // 辅助方法
   string               ToString() const;
};

//+------------------------------------------------------------------+
//| 默认构造函数                                                       |
//+------------------------------------------------------------------+
CZigzagSegment::CZigzagSegment()
{
   m_price_diff = 0.0;
   m_price_diff_pct = 0.0;
   m_manager = NULL;
   m_timeframe = PERIOD_CURRENT;
}

//+------------------------------------------------------------------+
//| 参数化构造函数                                                     |
//+------------------------------------------------------------------+
CZigzagSegment::CZigzagSegment(const CZigzagExtremumPoint &start, const CZigzagExtremumPoint &end)
{
   m_start_point = start;
   m_end_point = end;
   m_manager = NULL;
   m_timeframe = start.Timeframe();
   CalculatePriceDiff();
}

//+------------------------------------------------------------------+
//| 带时间周期的参数化构造函数                                          |
//+------------------------------------------------------------------+
CZigzagSegment::CZigzagSegment(const CZigzagExtremumPoint &start, const CZigzagExtremumPoint &end, ENUM_TIMEFRAMES timeframe)
{
   m_start_point = start;
   m_end_point = end;
   m_manager = NULL;
   m_timeframe = timeframe;
   CalculatePriceDiff();
}

//+------------------------------------------------------------------+
//| 复制构造函数                                                       |
//+------------------------------------------------------------------+
CZigzagSegment::CZigzagSegment(const CZigzagSegment &other)
{
   m_start_point = other.m_start_point;
   m_end_point = other.m_end_point;
   m_price_diff = other.m_price_diff;
   m_price_diff_pct = other.m_price_diff_pct;
   m_manager = other.m_manager;
   m_timeframe = other.m_timeframe;
}

//+------------------------------------------------------------------+
//| 析构函数                                                           |
//+------------------------------------------------------------------+
CZigzagSegment::~CZigzagSegment()
{
   // 清理资源（如果有的话）
}

//+------------------------------------------------------------------+
//| 设置起始点                                                         |
//+------------------------------------------------------------------+
void CZigzagSegment::StartPoint(const CZigzagExtremumPoint &value)
{
   m_start_point = value;
   CalculatePriceDiff();
}

//+------------------------------------------------------------------+
//| 设置结束点                                                         |
//+------------------------------------------------------------------+
void CZigzagSegment::EndPoint(const CZigzagExtremumPoint &value)
{
   m_end_point = value;
   CalculatePriceDiff();
}

//+------------------------------------------------------------------+
//| 计算价格差和百分比                                                 |
//+------------------------------------------------------------------+
void CZigzagSegment::CalculatePriceDiff()
{
   if(m_start_point.Value() == 0 || m_end_point.Value() == 0)
   {
      m_price_diff = 0.0;
      m_price_diff_pct = 0.0;
      return;
   }
   
   // 计算价格差的绝对值
   m_price_diff = MathAbs(m_end_point.Value() - m_start_point.Value());
   
   // 计算价格差的百分比
   if(m_start_point.Value() != 0)
      m_price_diff_pct = (m_price_diff / m_start_point.Value()) * 100.0;
   else
      m_price_diff_pct = 0.0;
}

//+------------------------------------------------------------------+
//| 将对象转换为字符串                                                 |
//+------------------------------------------------------------------+
string CZigzagSegment::ToString() const
{
   string direction = IsUptrend() ? "上升" : "下降";
   string start_time = TimeToString(m_start_point.Time());
   string end_time = TimeToString(m_end_point.Time());
   string price_diff_str = DoubleToString(m_price_diff, _Digits);
   string price_diff_pct_str = DoubleToString(m_price_diff_pct, 2);
   string price_length_pips_str = DoubleToString(PriceLengthInPips(), 1);
   
   return StringFormat("线段: %s, 起点时间: %s, 终点时间: %s, 价格长度: %s (%s点, %s%%)", 
                      direction, start_time, end_time, price_diff_str, price_length_pips_str, price_diff_pct_str);
}

// 定义一个包装类，使CZigzagSegment可以存储在CArrayObj中
class CZigzagSegmentWrapper : public CObject
{
private:
   CZigzagSegment* m_segment;

public:
   CZigzagSegmentWrapper(CZigzagSegment* segment) : m_segment(segment) {}
   ~CZigzagSegmentWrapper() { if(m_segment != NULL) delete m_segment; }
   
   CZigzagSegment* GetSegment() const { return m_segment; }
};

//+------------------------------------------------------------------+
//| 获取更小周期的线段                                                |
//+------------------------------------------------------------------+
CZigzagSegmentManager* CZigzagSegment::GetSmallerTimeframeSegments(ENUM_TIMEFRAMES smallerTimeframe)
{
   // 参数有效性检查
   if(smallerTimeframe >= m_timeframe)
      return NULL;
   
   // 获取主线段时间范围
   datetime startTime = m_start_point.Time();
   datetime endTime = m_end_point.Time();
   
   // 确保startTime是较早的时间，endTime是较晚的时间
   if(startTime > endTime)
   {
      datetime temp = startTime;
      startTime = endTime;
      endTime = temp;
   }
   
   // 根据K线搜索策略确定K线数量
   int barsCount;
   if(smallerTimeframe <= PERIOD_M5)
      barsCount = 2000;
   else if(smallerTimeframe <= PERIOD_H1) 
      barsCount = 2000;
   else 
      barsCount = 500;
   
   // 创建ZigZag计算器并计算极值点
   CZigzagCalculator zigzagCalc(12, 5, 3, barsCount, smallerTimeframe);
   
   if(!zigzagCalc.CalculateForSymbol(Symbol(), smallerTimeframe, barsCount))
      return NULL;
   
   CZigzagExtremumPoint points[];
   if(!zigzagCalc.GetExtremumPoints(points) || ArraySize(points) < 2)
      return NULL;
      
   // 生成所有线段
   int point_count = ArraySize(points);
   CZigzagSegment* allSegments[];
   ArrayResize(allSegments, point_count - 1);
   
   int segmentCount = 0;
   for(int i = 0; i < point_count - 1; i++)
   {
      points[i].Timeframe(smallerTimeframe);
      points[i+1].Timeframe(smallerTimeframe);
      
      // 创建新线段
      CZigzagSegment* newSegment = new CZigzagSegment(points[i+1], points[i], smallerTimeframe);
      
      if(newSegment != NULL)
      {
         datetime segStartTime = newSegment.StartTime();
         datetime segEndTime = newSegment.EndTime();
         
         // 检查线段是否在主线段时间范围内
         // 线段的开始时间必须在主线段区间内才是有效的
         if(segStartTime >= startTime)
         {
            allSegments[segmentCount++] = newSegment;
         }
         else
         {
            // 释放不在时间范围内的线段
            delete newSegment;
         }
      }
   }
   
   // 调整数组大小
   ArrayResize(allSegments, segmentCount);
   
   // 创建并返回线段管理器
   CZigzagSegmentManager* segmentManager = new CZigzagSegmentManager(allSegments, segmentCount);
   return segmentManager;
}
