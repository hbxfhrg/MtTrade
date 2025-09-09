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
public:
   ENUM_TIMEFRAMES   timeframe;    // 时间周期
   datetime          time;         // K线时间
   int               bar_index;    // K线序号
   double            value;        // 极点值
   ENUM_EXTREMUM_TYPE type;        // 极点类型
   int               h1_index;     // 1小时K线索引
   datetime          h1_time;      // 1小时K线时间

                     CZigzagExtremumPoint();
                     CZigzagExtremumPoint(ENUM_TIMEFRAMES timeframe, datetime atime, int bar_index, double value, ENUM_EXTREMUM_TYPE type);
                     CZigzagExtremumPoint(const CZigzagExtremumPoint &other);
                    ~CZigzagExtremumPoint();
   
  
   string            TypeAsString() const;
   string            ToString() const;
   bool              IsPeak() const { return type == EXTREMUM_PEAK; }
   bool              IsBottom() const { return type == EXTREMUM_BOTTOM; }
   bool              IsUndefined() const { return type == EXTREMUM_UNDEFINED; }
   
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
   timeframe = PERIOD_CURRENT;
   time = 0;
   bar_index = -1;
   value = 0.0;
   type = EXTREMUM_UNDEFINED;
   h1_index = -1;
   h1_time = 0;
}

//+------------------------------------------------------------------+
//| 参数化构造函数                                                     |
//+------------------------------------------------------------------+
CZigzagExtremumPoint::CZigzagExtremumPoint(const CZigzagExtremumPoint &other)
{
   this.timeframe = other.timeframe;
   this.time = other.time;
   this.bar_index = other.bar_index;
   this.value = other.value;
   this.type = other.type;
   this.h1_index = other.h1_index;
   this.h1_time = other.h1_time;
}

CZigzagExtremumPoint::CZigzagExtremumPoint(ENUM_TIMEFRAMES atimeframe, datetime atime, int bar_idx, double val, ENUM_EXTREMUM_TYPE typ)
{
   this.timeframe = atimeframe;
   this.time = atime;
   this.bar_index = bar_idx;
   this.value = val;
   this.type = typ;
   this.h1_index = FindTimeframeIndex(ENUM_TIMEFRAMES::PERIOD_H1);
   this.h1_time = 0;  // 初始化为0，需要时再计算
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
   switch(type)
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
   string timeframe_str = EnumToString(timeframe);
   string time_str = TimeToString(time);
   string value_str = DoubleToString(value, _Digits);
   string type_str = TypeAsString();
   
   return StringFormat("时间周期: %s, 时间: %s, 序号: %d, 值: %s, 类型: %s", 
                      timeframe_str, time_str, bar_index, value_str, type_str);
}

//+------------------------------------------------------------------+
//| 查找较小时间周期中的K线索引                                        |
//+------------------------------------------------------------------+
int CZigzagExtremumPoint::FindTimeframeIndex(ENUM_TIMEFRAMES smallerTimeframe)
{
   // 如果传入的时间周期与当前极值点的时间周期相同，直接返回当前的K线索引
   if (smallerTimeframe == timeframe)
   {
      return bar_index;
   }
   
   // 调用CommonUtils中的方法 FindBarIndexByPrice，根据峰谷值类型传值
   if (type == EXTREMUM_PEAK)
   {
      // 对于峰值，使用MODE_HIGH模式查找K线索引
      return ::FindBarIndexByPrice(value, MODE_HIGH, smallerTimeframe);
   }
   else if (type == EXTREMUM_BOTTOM)
   {
      // 对于谷值，使用MODE_LOW模式查找K线索引
      return ::FindBarIndexByPrice(value, MODE_LOW, smallerTimeframe);
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
   if (h1_time > 0)
   {
      return h1_time;
   }
   
   // 如果当前极值点就是1小时周期数据，直接返回其时间并存储
   if (timeframe == PERIOD_H1)
   {
      h1_time = time;
      return h1_time;
   }
   
   // 如果已计算过1小时K线索引，直接使用该索引获取时间
   if (h1_index >= 0)
   {
      h1_time = iTime(Symbol(), PERIOD_H1, h1_index);
      return h1_time;
   }
   
   // 否则计算1小时K线索引并获取时间
   int h1Index = FindTimeframeIndex(PERIOD_H1);
   if (h1Index >= 0)
   {
      h1_index = h1Index;
      h1_time = iTime(Symbol(), PERIOD_H1, h1Index);
      return h1_time;
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
   if(time > other.time) return -1;  // 当前对象时间更近，排在前面
   if(time < other.time) return 1;   // 当前对象时间更远，排在后面
   
   // 如果时间相同，按K线序号排序，最近的K线在前面
   if(bar_index < other.bar_index) return -1;  // 当前对象K线序号更小（更近），排在前面
   if(bar_index > other.bar_index) return 1;   // 当前对象K线序号更大（更远），排在后面
   
   // 如果时间和K线序号都相同，按价格排序
   if(value > other.value) return -1;  // 当前对象价格更高，排在前面
   if(value < other.value) return 1;   // 当前对象价格更低，排在后面
   
   // 完全相同
   return 0;
}

//+------------------------------------------------------------------+