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
//| 极值点结构体                                                       |
//+------------------------------------------------------------------+
struct SZigzagExtremumPoint
{
   ENUM_TIMEFRAMES   timeframe;    // 时间周期
   datetime          time;         // K线时间
   int               bar_index;    // K线序号
   double            value;        // 极点值
   ENUM_EXTREMUM_TYPE type;        // 极点类型
   int               h1_index;     // 1小时K线索引
   datetime          h1_time;      // 1小时K线时间
};

//+------------------------------------------------------------------+
//| 初始化极值点结构体函数                                              |
//+------------------------------------------------------------------+
void InitZigzagExtremumPoint(SZigzagExtremumPoint &point, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT, datetime time = 0, 
                           int bar_index = -1, double value = 0.0, ENUM_EXTREMUM_TYPE type = EXTREMUM_UNDEFINED)
{
   point.timeframe = timeframe;
   point.time = time;
   point.bar_index = bar_index;
   point.value = value;
   point.type = type;
   point.h1_index = -1;
   point.h1_time = 0;
}

//+------------------------------------------------------------------+
//| 将类型转换为字符串                                                 |
//+------------------------------------------------------------------+
string TypeAsString(const SZigzagExtremumPoint &point)
{
   switch(point.type)
   {
      case EXTREMUM_PEAK:    return "峰值";
      case EXTREMUM_BOTTOM:  return "谷值";
      default:               return "待定";
   }
}

//+------------------------------------------------------------------+
//| 将结构体转换为字符串                                               |
//+------------------------------------------------------------------+
string ToString(const SZigzagExtremumPoint &point)
{
   string timeframe_str = EnumToString(point.timeframe);
   string time_str = TimeToString(point.time);
   string value_str = DoubleToString(point.value, _Digits);
   string type_str = TypeAsString(point);
   
   return StringFormat("时间周期: %s, 时间: %s, 序号: %d, 值: %s, 类型: %s", 
                      timeframe_str, time_str, point.bar_index, value_str, type_str);
}

//+------------------------------------------------------------------+
//| 判断是否为峰值                                                     |
//+------------------------------------------------------------------+
bool IsPeak(const SZigzagExtremumPoint &point)
{
   return point.type == EXTREMUM_PEAK;
}

//+------------------------------------------------------------------+
//| 判断是否为谷值                                                     |
//+------------------------------------------------------------------+
bool IsBottom(const SZigzagExtremumPoint &point)
{
   return point.type == EXTREMUM_BOTTOM;
}

//+------------------------------------------------------------------+
//| 判断是否为未定义类型                                               |
//+------------------------------------------------------------------+
bool IsUndefined(const SZigzagExtremumPoint &point)
{
   return point.type == EXTREMUM_UNDEFINED;
}

//+------------------------------------------------------------------+
//| 查找较小时间周期中的K线索引                                        |
//+------------------------------------------------------------------+
int FindTimeframeIndex(const SZigzagExtremumPoint &point, ENUM_TIMEFRAMES smallerTimeframe)
{
   // 如果传入的时间周期与当前极值点的时间周期相同，直接返回当前的K线索引
   if (smallerTimeframe == point.timeframe)
   {
      return point.bar_index;
   }
   
   // 调用CommonUtils中的方法 FindBarIndexByPrice，根据峰谷值类型传值
   if (point.type == EXTREMUM_PEAK)
   {
      // 对于峰值，使用MODE_HIGH模式查找K线索引
      return ::FindBarIndexByPrice(point.value, MODE_HIGH, smallerTimeframe);
   }
   else if (point.type == EXTREMUM_BOTTOM)
   {
      // 对于谷值，使用MODE_LOW模式查找K线索引
      return ::FindBarIndexByPrice(point.value, MODE_LOW, smallerTimeframe);
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
datetime GetH1Time(SZigzagExtremumPoint &point)
{
   // 如果已经计算过1小时K线时间，直接返回
   if (point.h1_time > 0)
   {
      return point.h1_time;
   }
   
   // 如果当前极值点就是1小时周期数据，直接返回其时间并存储
   if (point.timeframe == PERIOD_H1)
   {
      point.h1_time = point.time;
      return point.h1_time;
   }
   
   // 如果已计算过1小时K线索引，直接使用该索引获取时间
   if (point.h1_index >= 0)
   {
      point.h1_time = iTime(Symbol(), PERIOD_H1, point.h1_index);
      return point.h1_time;
   }
   
   // 否则计算1小时K线索引并获取时间
   int h1Index = FindTimeframeIndex(point, PERIOD_H1);
   if (h1Index >= 0)
   {
      point.h1_index = h1Index;
      point.h1_time = iTime(Symbol(), PERIOD_H1, h1Index);
      return point.h1_time;
   }
   
   // 如果无法找到，返回0
   return 0;
}

//+------------------------------------------------------------------+
//| 比较两个极点，用于排序                                             |
//+------------------------------------------------------------------+
int CompareExtremumPoints(const SZigzagExtremumPoint &a, const SZigzagExtremumPoint &b)
{
   // 按时间排序，最近的时间在前面
   if(a.time > b.time) return -1;  // a时间更近，排在前面
   if(a.time < b.time) return 1;   // a时间更远，排在后面
   
   // 如果时间相同，按K线序号排序，最近的K线在前面
   if(a.bar_index < b.bar_index) return -1;  // a K线序号更小（更近），排在前面
   if(a.bar_index > b.bar_index) return 1;   // a K线序号更大（更远），排在后面
   
   // 如果时间和K线序号都相同，按价格排序
   if(a.value > b.value) return -1;  // a价格更高，排在前面
   if(a.value < b.value) return 1;   // a价格更低，排在后面
   
   // 完全相同
   return 0;
}

//+------------------------------------------------------------------+