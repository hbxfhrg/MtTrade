//+------------------------------------------------------------------+
//|                                                ZigzagSegment.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

// 引入必要的头文件
#include "ZigzagExtremumPoint.mqh"
#include <Arrays\\ArrayObj.mqh>  // 添加CArrayObj的头文件

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

public:
                     CZigzagSegment();
                     CZigzagSegment(const CZigzagExtremumPoint &start, const CZigzagExtremumPoint &end);
                     CZigzagSegment(const CZigzagSegment &other);
                    ~CZigzagSegment();
   
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
   
   double               PriceDiff() const { return m_price_diff; }
   double               PriceDiffPercent() const { return m_price_diff_pct; }
   
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
}

//+------------------------------------------------------------------+
//| 参数化构造函数                                                     |
//+------------------------------------------------------------------+
CZigzagSegment::CZigzagSegment(const CZigzagExtremumPoint &start, const CZigzagExtremumPoint &end)
{
   m_start_point = start;
   m_end_point = end;
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
   
   return StringFormat("线段: %s, 起点时间: %s, 终点时间: %s, 价格差: %s (%s%%)", 
                      direction, start_time, end_time, price_diff_str, price_diff_pct_str);
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