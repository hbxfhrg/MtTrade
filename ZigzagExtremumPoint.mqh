//+------------------------------------------------------------------+
//|                                           ZigzagExtremumPoint.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

//+------------------------------------------------------------------+
//| 极值点类型枚举                                                     |
//+------------------------------------------------------------------+
enum ENUM_EXTREMUM_TYPE
{
   EXTREMUM_UNDEFINED = 0,  // 未定义/待定
   EXTREMUM_PEAK     = 1,   // 峰值
   EXTREMUM_BOTTOM   = 2    // 谷值
};

//+------------------------------------------------------------------+
//| 极值点对象类                                                       |
//+------------------------------------------------------------------+
class CZigzagExtremumPoint
{
private:
   ENUM_TIMEFRAMES   m_timeframe;    // 时间周期
   datetime          m_time;         // K线时间
   int               m_bar_index;    // K线序号
   double            m_value;        // 极点值
   ENUM_EXTREMUM_TYPE m_type;        // 极点类型

public:
                     CZigzagExtremumPoint();
                     CZigzagExtremumPoint(ENUM_TIMEFRAMES timeframe, datetime time, int bar_index, double value, ENUM_EXTREMUM_TYPE type);
                     CZigzagExtremumPoint(const CZigzagExtremumPoint &other);
                    ~CZigzagExtremumPoint();
   
   // 获取/设置属性
   ENUM_TIMEFRAMES   Timeframe() const { return m_timeframe; }
   void              Timeframe(ENUM_TIMEFRAMES value) { m_timeframe = value; }
   
   datetime          Time() const { return m_time; }
   void              Time(datetime value) { m_time = value; }
   
   int               BarIndex() const { return m_bar_index; }
   void              BarIndex(int value) { m_bar_index = value; }
   
   double            Value() const { return m_value; }
   void              Value(double value) { m_value = value; }
   
   ENUM_EXTREMUM_TYPE Type() const { return m_type; }
   void              Type(ENUM_EXTREMUM_TYPE value) { m_type = value; }
   
   // 辅助方法
   string            TypeAsString() const;
   string            ToString() const;
   bool              IsPeak() const { return m_type == EXTREMUM_PEAK; }
   bool              IsBottom() const { return m_type == EXTREMUM_BOTTOM; }
   bool              IsUndefined() const { return m_type == EXTREMUM_UNDEFINED; }
};

//+------------------------------------------------------------------+
//| 默认构造函数                                                       |
//+------------------------------------------------------------------+
CZigzagExtremumPoint::CZigzagExtremumPoint()
{
   m_timeframe = PERIOD_CURRENT;
   m_time = 0;
   m_bar_index = -1;
   m_value = 0.0;
   m_type = EXTREMUM_UNDEFINED;
}

//+------------------------------------------------------------------+
//| 参数化构造函数                                                     |
//+------------------------------------------------------------------+
CZigzagExtremumPoint::CZigzagExtremumPoint(const CZigzagExtremumPoint &other)
{
   m_timeframe = other.m_timeframe;
   m_time = other.m_time;
   m_bar_index = other.m_bar_index;
   m_value = other.m_value;
   m_type = other.m_type;
}

CZigzagExtremumPoint::CZigzagExtremumPoint(ENUM_TIMEFRAMES timeframe, datetime time, int bar_index, double value, ENUM_EXTREMUM_TYPE type)
{
   m_timeframe = timeframe;
   m_time = time;
   m_bar_index = bar_index;
   m_value = value;
   m_type = type;
}

//+------------------------------------------------------------------+
//| 析构函数                                                           |
//+------------------------------------------------------------------+
CZigzagExtremumPoint::~CZigzagExtremumPoint()
{
   // 清理资源（如果有的话）
}

//+------------------------------------------------------------------+
//| 将类型转换为字符串                                                 |
//+------------------------------------------------------------------+
string CZigzagExtremumPoint::TypeAsString() const
{
   switch(m_type)
   {
      case EXTREMUM_PEAK:    return "峰值";
      case EXTREMUM_BOTTOM:  return "谷值";
      default:               return "待定";
   }
}

//+------------------------------------------------------------------+
//| 将对象转换为字符串                                                 |
//+------------------------------------------------------------------+
string CZigzagExtremumPoint::ToString() const
{
   string timeframe_str = EnumToString(m_timeframe);
   string time_str = TimeToString(m_time);
   string value_str = DoubleToString(m_value, _Digits);
   string type_str = TypeAsString();
   
   return StringFormat("时间周期: %s, 时间: %s, 序号: %d, 值: %s, 类型: %s", 
                      timeframe_str, time_str, m_bar_index, value_str, type_str);
}

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
//+------------------------------------------------------------------+