//+------------------------------------------------------------------+
//|                                                   CommonUtils.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

//+------------------------------------------------------------------+
//| 通用工具类 - 提供项目中使用的各种通用方法                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 将时间周期转换为简写形式                                           |
//+------------------------------------------------------------------+
string TimeframeToString(ENUM_TIMEFRAMES timeframe)
  {
   switch(timeframe)
     {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN";
      default:         return EnumToString(timeframe);
     }
  }

//+------------------------------------------------------------------+
//| 获取时间周期的分钟数                                              |
//+------------------------------------------------------------------+
int TimeframeMinutes(ENUM_TIMEFRAMES timeframe)
  {
   switch(timeframe)
     {
      case PERIOD_M1:  return 1;
      case PERIOD_M5:  return 5;
      case PERIOD_M15: return 15;
      case PERIOD_M30: return 30;
      case PERIOD_H1:  return 60;
      case PERIOD_H4:  return 240;
      case PERIOD_D1:  return 1440;
      case PERIOD_W1:  return 10080;
      case PERIOD_MN1: return 43200;
      default:         return (int)timeframe;
     }
  }

//+------------------------------------------------------------------+
//| 获取当前图表的时间周期                                            |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetCurrentTimeframe()
  {
   return (ENUM_TIMEFRAMES)Period();
  }

//+------------------------------------------------------------------+
//| 获取当前图表的时间周期简写形式                                     |
//+------------------------------------------------------------------+
string GetCurrentTimeframeString()
  {
   return TimeframeToString(GetCurrentTimeframe());
  }

//+------------------------------------------------------------------+
//| 格式化价格，根据品种小数位数                                       |
//+------------------------------------------------------------------+
string FormatPrice(double price, int digits = -1)
  {
   if(digits < 0)
      digits = _Digits;
      
   return DoubleToString(price, digits);
  }

//+------------------------------------------------------------------+
//| 格式化日期时间                                                    |
//+------------------------------------------------------------------+
string FormatDateTime(datetime time, bool includeSeconds = true)
  {
   if(includeSeconds)
      return TimeToString(time, TIME_DATE | TIME_MINUTES | TIME_SECONDS);
   else
      return TimeToString(time, TIME_DATE | TIME_MINUTES);
  }

//+------------------------------------------------------------------+
//| 计算两个价格之间的点数差异                                         |
//+------------------------------------------------------------------+
int PriceDifferenceInPoints(double price1, double price2)
  {
   return (int)MathRound(MathAbs(price1 - price2) / _Point);
  }

//+------------------------------------------------------------------+
//| 计算两个价格之间的百分比差异                                       |
//+------------------------------------------------------------------+
double PriceDifferenceInPercent(double price1, double price2)
  {
   if(price2 == 0)
      return 0;
      
   return (price1 - price2) / price2 * 100.0;
  }

