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