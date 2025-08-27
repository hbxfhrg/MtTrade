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
   int               m_h1_index;     // 1小时K线索引
   datetime          m_h1_time;      // 1小时K线时间

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
   
   int               H1Index() const { return m_h1_index; }
   void              H1Index(int value) { m_h1_index = value; }
   
   datetime          H1Time() const { return m_h1_time; }
   void              H1Time(datetime value) { m_h1_time = value; }
   
   // 辅助方法
   string            TypeAsString() const;
   string            ToString() const;
   bool              IsPeak() const { return m_type == EXTREMUM_PEAK; }
   bool              IsBottom() const { return m_type == EXTREMUM_BOTTOM; }
   bool              IsUndefined() const { return m_type == EXTREMUM_UNDEFINED; }
   
   // 比较运算符，用于排序
   int               Compare(const CZigzagExtremumPoint &other) const;
   
   // 查找较小时间周期中的K线索引
   int               FindTimeframeIndex(ENUM_TIMEFRAMES smallerTimeframe);
   
   // 获取1小时周期K线时间
   datetime          GetH1Time();
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
   m_h1_index = -1;
   m_h1_time = 0;
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
   m_h1_index = FindTimeframeIndex(ENUM_TIMEFRAMES::PERIOD_H1);
   m_h1_time = 0;  // 初始化为0，需要时再计算
}

CZigzagExtremumPoint::CZigzagExtremumPoint(ENUM_TIMEFRAMES timeframe, datetime time, int bar_index, double value, ENUM_EXTREMUM_TYPE type)
{
   m_timeframe = timeframe;
   m_time = time;
   m_bar_index = bar_index;
   m_value = value;
   m_type = type;
   m_h1_index = FindTimeframeIndex(ENUM_TIMEFRAMES::PERIOD_H1);
   m_h1_time = 0;  // 初始化为0，需要时再计算
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
//| 查找较小时间周期中的K线索引                                        |
//+------------------------------------------------------------------+
int CZigzagExtremumPoint::FindTimeframeIndex(ENUM_TIMEFRAMES smallerTimeframe)
{
   // 如果传入的时间周期与当前极值点的时间周期相同，直接返回当前的K线索引
   if (smallerTimeframe == m_timeframe)
   {
      return m_bar_index;
   }
   
   // 调用CommonUtils中的方法 FindBarIndexByPrice，根据峰谷值类型传值
   if (m_type == EXTREMUM_PEAK)
   {
      // 对于峰值，使用MODE_HIGH模式查找K线索引
      return ::FindBarIndexByPrice(m_value, MODE_HIGH, smallerTimeframe);
   }
   else if (m_type == EXTREMUM_BOTTOM)
   {
      // 对于谷值，使用MODE_LOW模式查找K线索引
      return ::FindBarIndexByPrice(m_value, MODE_LOW, smallerTimeframe);
   }
   else
   {
      // 对于未定义类型，返回-1
      return -1;
   }
}

//+------------------------------------------------------------------+
//| 获取1小时周期K线时间                                             |
//+------------------------------------------------------------------+
datetime CZigzagExtremumPoint::GetH1Time()
{
   // 如果已经计算过1小时K线时间，直接返回
   if (m_h1_time > 0)
   {
      return m_h1_time;
   }
   
   // 如果当前极值点就是1小时周期数据，直接返回其时间并存储
   if (m_timeframe == PERIOD_H1)
   {
      m_h1_time = m_time;
      return m_h1_time;
   }
   
   // 如果已计算过1小时K线索引，直接使用该索引获取时间
   if (m_h1_index >= 0)
   {
      m_h1_time = iTime(Symbol(), PERIOD_H1, m_h1_index);
      return m_h1_time;
   }
   
   // 否则计算1小时K线索引并获取时间
   int h1Index = FindTimeframeIndex(PERIOD_H1);
   if (h1Index >= 0)
   {
      m_h1_index = h1Index;
      m_h1_time = iTime(Symbol(), PERIOD_H1, h1Index);
      return m_h1_time;
   }
   
   // 如果无法找到，返回0
   return 0;
}

//+------------------------------------------------------------------+
//| 比较两个极点，用于排序                                             |
//+------------------------------------------------------------------+
int CZigzagExtremumPoint::Compare(const CZigzagExtremumPoint &other) const
{
   // 按时间排序，最近的时间在前面
   if(m_time > other.m_time) return -1;  // 当前对象时间更近，排在前面
   if(m_time < other.m_time) return 1;   // 当前对象时间更远，排在后面
   
   // 如果时间相同，按K线序号排序，最近的K线在前面
   if(m_bar_index < other.m_bar_index) return -1;  // 当前对象K线序号更小（更近），排在前面
   if(m_bar_index > other.m_bar_index) return 1;   // 当前对象K线序号更大（更远），排在后面
   
   // 如果时间和K线序号都相同，按价格排序
   if(m_value > other.m_value) return -1;  // 当前对象价格更高，排在前面
   if(m_value < other.m_value) return 1;   // 当前对象价格更低，排在后面
   
   // 完全相同
   return 0;
}

//+------------------------------------------------------------------+