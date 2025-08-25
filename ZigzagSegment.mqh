//+------------------------------------------------------------------+
//|                                                ZigzagSegment.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

// 引入必要的头文件
#include "ZigzagCommon.mqh"      // 包含公共定义和前向声明
#include "ZigzagExtremumPoint.mqh"
#include "ZigzagCalculator.mqh"  // 包含CZigzagCalculator类定义
#include "CommonUtils.mqh"       // 包含通用工具函数
#include <Arrays\\ArrayObj.mqh>  // 添加CArrayObj的头文件

// 前向声明ZigzagSegmentManager的CalculateSegments方法
class CZigzagSegmentManager;

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
   bool                 GetSmallerTimeframeSegments(CZigzagSegment* &segments[], ENUM_TIMEFRAMES smallerTimeframe, int maxCount = 10);
   
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
bool CZigzagSegment::GetSmallerTimeframeSegments(CZigzagSegment* &segments[], ENUM_TIMEFRAMES smallerTimeframe, int maxCount)
{
   // 检查参数有效性
   if(m_manager == NULL || maxCount <= 0)
      return false;
      
   // 检查时间周期是否合理
   if(smallerTimeframe >= m_timeframe)
   {
      Print("错误: 指定的时间周期 ", TimeframeToString(smallerTimeframe), " 大于或等于当前线段的时间周期 ", TimeframeToString(m_timeframe));
      return false;
   }
   
   // 获取线段的时间范围
   datetime startTime = m_start_point.Time();
   datetime endTime = m_end_point.Time();
   
   // 创建一个临时的ZigZag计算器
   CZigzagCalculator zigzagCalc(12, 5, 3, 1000, smallerTimeframe);
   
   // 获取当前时间周期的ZigZag极点数据
   CZigzagExtremumPoint points[];
   
   // 先为指定的时间周期计算ZigZag值
   if(!calculator.CalculateForSymbol(Symbol(), smallerTimeframe, 1000))
      return false;
      
   // 然后获取极值点
   if(!calculator.GetExtremumPoints(points, maxCount * 2))
      return false;
      
   int point_count = ArraySize(points);
   
   if(point_count < 2)
      return false;
      
   // 生成线段
   CZigzagSegment* allSegments[];
   ArrayResize(allSegments, point_count - 1);
   
   for(int i = 0; i < point_count - 1; i++)
   {
      // 设置时间周期
      points[i].Timeframe(smallerTimeframe);
      points[i+1].Timeframe(smallerTimeframe);
      
      // 创建新线段
      allSegments[i] = new CZigzagSegment(points[i+1], points[i], smallerTimeframe);
      
      // 设置线段管理器引用
      if(allSegments[i] != NULL)
         allSegments[i].SetManager(m_manager);
   }
   
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
