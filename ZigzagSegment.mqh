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

//+------------------------------------------------------------------+
//| ZigZag线段类，包含两个极值点（峰值和谷值）                           |
//+------------------------------------------------------------------+
class CZigzagSegment：public CObject
{
private:
  
   
   CZigzagSegmentManager* m_manager;     // 线段管理器引用
  

public:
                     CZigzagSegment();
                     CZigzagSegment(const CZigzagExtremumPoint &start, const CZigzagExtremumPoint &end);
                     CZigzagSegment(const CZigzagExtremumPoint &start, const CZigzagExtremumPoint &end, ENUM_TIMEFRAMES timeframe);
                     CZigzagSegment(const CZigzagSegment &other);
                    ~CZigzagSegment();
   
   CZigzagExtremumPoint m_start_point;   // 起始点（可能是峰值或谷值）
   CZigzagExtremumPoint m_end_point;     // 结束点（可能是谷值或峰值）
   ENUM_TIMEFRAMES      timeframe;     // 当前线段的时间周期
   double               m_price_diff;    // 价格差（绝对值）
   double               m_price_diff_pct; // 价格差百分比
   // 设置线段管理器
   void                 SetManager(CZigzagSegmentManager* manager) { m_manager = manager; }
   

   
   // 获取更小周期的线段
   CZigzagSegmentManager* GetSmallerTimeframeSegments(ENUM_TIMEFRAMES smallerTimeframe, bool fromStartorEnd = true);
   

   
   // 计算价格差和百分比
   void                 CalculatePriceDiff();
   
   // 获取线段方向（上升/下降）
   bool                 IsUptrend() const { return m_end_point.value > m_start_point.value; }
   bool                 IsDowntrend() const { return m_end_point.value < m_start_point.value; }
   
   // 获取线段长度（K线数量）
   int                  BarCount() const { return MathAbs(m_end_point.bar_index - m_start_point.bar_index); }
   
   // 获取价格长度（点数）
   double               PriceLengthInPips() const;
   
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
   timeframe = PERIOD_CURRENT;
}

//+------------------------------------------------------------------+
//| 参数化构造函数                                                     |
//+------------------------------------------------------------------+
CZigzagSegment::CZigzagSegment(const CZigzagExtremumPoint &start, const CZigzagExtremumPoint &end)
{
   m_start_point = start;
   m_end_point = end;
   m_manager = NULL;
   timeframe = start.timeframe;
   CalculatePriceDiff();
}

//+------------------------------------------------------------------+
//| 带时间周期的参数化构造函数                                          |
//+------------------------------------------------------------------+
CZigzagSegment::CZigzagSegment(const CZigzagExtremumPoint &start, const CZigzagExtremumPoint &end, ENUM_TIMEFRAMES tf)
{
   m_start_point = start;
   m_end_point = end;
   m_manager = NULL;
   timeframe = tf;
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
   timeframe = other.timeframe;
}

//+------------------------------------------------------------------+
//| 析构函数                                                           |
//+------------------------------------------------------------------+
CZigzagSegment::~CZigzagSegment()
{
   // 清理资源（如果有的话）
}


//+------------------------------------------------------------------+
//| 计算价格差和百分比                                                 |
//+------------------------------------------------------------------+
void CZigzagSegment::CalculatePriceDiff()
{
   if(m_start_point.value == 0 || m_end_point.value == 0)
   {
      m_price_diff = 0.0;
      m_price_diff_pct = 0.0;
      return;
   }
   
   // 计算价格差的绝对值
   m_price_diff = MathAbs(m_end_point.value - m_start_point.value);
   
   // 计算价格差的百分比
   if(m_start_point.value != 0)
      m_price_diff_pct = (m_price_diff / m_start_point.value) * 100.0;
   else
      m_price_diff_pct = 0.0;
}

//+------------------------------------------------------------------+
//| 将对象转换为字符串                                                 |
//+------------------------------------------------------------------+
string CZigzagSegment::ToString() const
{
   string direction = IsUptrend() ? "上升" : "下降";
   string start_time = TimeToString(m_start_point.time);
   string end_time = TimeToString(m_end_point.time);
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
CZigzagSegmentManager* CZigzagSegment::GetSmallerTimeframeSegments(ENUM_TIMEFRAMES smallerTimeframe,bool fromStartorEnd = true)
{
   // 参数有效性检查
   if(smallerTimeframe >= timeframe)
      return NULL;
   
   // 获取主线段时间范围
   datetime startTime = m_start_point.time;
   datetime endTime = m_end_point.time;
   
   // 确保startTime是较早的时间，endTime是较晚的时间
   if(startTime > endTime)
   {
      datetime temp = startTime;
      startTime = endTime;
      endTime = temp;
   }
   
   // 根据区间开始时间确定K线数量
   // 找到区间开始时间在指定周期上的K线序号，然后加上30作为barsCount
   int startBarIndex = iBarShift(Symbol(), smallerTimeframe, startTime);
   
   // 调试日志：输出startBarIndex的值和时间信息
   string timeframeName = EnumToString(smallerTimeframe);
   Print("GetSmallerTimeframeSegments: 周期 ", timeframeName, " - startBarIndex = ", startBarIndex, ", startTime = ", TimeToString(startTime));
   
   // 如果iBarShift返回-1，尝试使用iTime验证时间有效性
   if(startBarIndex < 0)
   {
      // 检查startTime是否在图表时间范围内
      datetime firstBarTime = iTime(Symbol(), smallerTimeframe, 0);
      datetime lastBarTime = iTime(Symbol(), smallerTimeframe, Bars(Symbol(), smallerTimeframe) - 1);
      
      Print("GetSmallerTimeframeSegments: 周期 ", timeframeName, " - 时间范围: ", TimeToString(firstBarTime), " 到 ", TimeToString(lastBarTime));
      Print("GetSmallerTimeframeSegments: 周期 ", timeframeName, " - 请求时间 ", TimeToString(startTime), " 不在图表时间范围内");
      return NULL; // 无法找到区间开始时间对应的K线，返回NULL
   }
   
   int barsCount = startBarIndex + 30;
   
   // 确保barsCount在合理范围内（30-2000）
   if(barsCount < 30)
      barsCount = 30;
   
   // 如果周期小于30分钟，根据不同的周期调整barsCount
   if(smallerTimeframe < PERIOD_M30)
   {
      // 取结束时间的定位
      int endBarIndex = iBarShift(Symbol(), smallerTimeframe, endTime);
      
      // 根据不同周期增加不同的值
      if(smallerTimeframe == PERIOD_M5)
         barsCount = endBarIndex + 400;      // 5分钟周期加400
      else if(smallerTimeframe == PERIOD_M1) 
         barsCount = endBarIndex + 1500;     // 1分钟周期加1500
      else if(smallerTimeframe == PERIOD_M15)
         barsCount = endBarIndex + 200;      // 15分钟周期加200
      else
         barsCount = endBarIndex + 300;      // 其他小于30分钟的周期默认加300
      
      // 确保barsCount在合理范围内（30-2000）
      if(barsCount < 30)
         barsCount = 30;
      else if(barsCount > 2000)
         barsCount = 2000;
   }
   
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
      points[i].timeframe = smallerTimeframe;
      points[i+1].timeframe = smallerTimeframe;
      
      // 创建新线段
      CZigzagSegment* newSegment = new CZigzagSegment(points[i+1], points[i], smallerTimeframe);
      
      if(newSegment != NULL)
      {
         datetime segStartTime = newSegment.m_start_point.time;
         datetime segEndTime = newSegment.m_end_point.time;
         
         // 检查线段是否在主线段时间范围内
         // 线段的开始时间必须在主线段区间内才是有效的
         if (fromStartorEnd)
         {
         if(segStartTime >= startTime)
         {
            allSegments[segmentCount++] = newSegment;
         }
       
      }
      else
      {
         if(segStartTime >= endTime)
         {
            allSegments[segmentCount++] = newSegment;
         }
        
      }

      }
   }
   
   // 调整数组大小
   ArrayResize(allSegments, segmentCount);
   
   // 创建并返回线段管理器
   CZigzagSegmentManager* segmentManager = new CZigzagSegmentManager(allSegments, segmentCount);
   return segmentManager;
}

//+------------------------------------------------------------------+
//| 获取价格长度（点数）                                              |
//+------------------------------------------------------------------+
double CZigzagSegment::PriceLengthInPips() const
{
   if(m_start_point.value == 0 || m_end_point.value == 0)
      return 0.0;
   
   double priceDiff = MathAbs(m_end_point.value - m_start_point.value);
   return priceDiff / Point();
}
