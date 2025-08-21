//+------------------------------------------------------------------+
//|                                                     LogUtil.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

//+------------------------------------------------------------------+
//| 日志工具类 - 用于集中管理日志输出                                  |
//+------------------------------------------------------------------+
class CLogUtil
  {
public:
   // 通用日志方法
   static void Log(string message)
     {
      Print("[DEBUG] " + message);
     }
     
   // 支撑位日志
   static void LogSupport(ENUM_TIMEFRAMES timeframe, double supportPrice, int priceShift, datetime supportTime)
     {
      string timeframeStr = TimeframeToString(timeframe);
      Print("计算得到的", timeframeStr, "支撑位: ", DoubleToString(supportPrice, _Digits), 
            " (来自K线序号: ", priceShift + 1, ", 时间: ", TimeToString(supportTime), ")");
     }
     
   // 无法获取前一根K线的支撑位日志
   static void LogSupportFallback(ENUM_TIMEFRAMES timeframe, double supportPrice, int priceShift, datetime supportTime)
     {
      string timeframeStr = TimeframeToString(timeframe);
      Print("无法获取前一根K线，使用当前K线的最低价作为支撑位: ", 
            DoubleToString(supportPrice, _Digits), 
            " (来自K线序号: ", priceShift, ", 时间: ", TimeToString(supportTime), ")");
     }
     
   // 在1小时周期找到匹配K线的支撑位日志
   static void LogSupportMatchFound(ENUM_TIMEFRAMES timeframe, double supportPrice, int priceShift, 
                                   datetime supportTime, int h1Shift, datetime h1Time)
     {
      string timeframeStr = TimeframeToString(timeframe);
      Print("计算得到的", timeframeStr, "支撑位: ", DoubleToString(supportPrice, _Digits), 
            " (来自", timeframeStr, " K线序号: ", priceShift + 1, ", 时间: ", TimeToString(supportTime),
            ", 在1H周期找到匹配K线序号: ", h1Shift, ", 时间: ", TimeToString(h1Time), ")");
     }
     
   // 在1小时周期未找到匹配K线的支撑位日志
   static void LogSupportMatchNotFound(ENUM_TIMEFRAMES timeframe, double supportPrice, int priceShift, datetime supportTime)
     {
      string timeframeStr = TimeframeToString(timeframe);
      Print("计算得到的", timeframeStr, "支撑位: ", DoubleToString(supportPrice, _Digits), 
            " (来自", timeframeStr, " K线序号: ", priceShift + 1, ", 时间: ", TimeToString(supportTime),
            ", 在1H周期未找到匹配K线，使用当前时间)");
     }
     
   // 压力位日志
   static void LogResistance(ENUM_TIMEFRAMES timeframe, double resistancePrice, int priceShift, datetime resistanceTime)
     {
      string timeframeStr = TimeframeToString(timeframe);
      Print("计算得到的", timeframeStr, "压力位: ", DoubleToString(resistancePrice, _Digits), 
            " (来自K线序号: ", priceShift + 1, ", 时间: ", TimeToString(resistanceTime), ")");
     }
     
   // 无法获取前一根K线的压力位日志
   static void LogResistanceFallback(ENUM_TIMEFRAMES timeframe, double resistancePrice, int priceShift, datetime resistanceTime)
     {
      string timeframeStr = TimeframeToString(timeframe);
      Print("无法获取前一根K线，使用当前K线的最高价作为压力位: ", 
            DoubleToString(resistancePrice, _Digits), 
            " (来自K线序号: ", priceShift, ", 时间: ", TimeToString(resistanceTime), ")");
     }
     
   // 在1小时周期找到匹配K线的压力位日志
   static void LogResistanceMatchFound(ENUM_TIMEFRAMES timeframe, double resistancePrice, int priceShift, 
                                      datetime resistanceTime, int h1Shift, datetime h1Time)
     {
      string timeframeStr = TimeframeToString(timeframe);
      Print("计算得到的", timeframeStr, "压力位: ", DoubleToString(resistancePrice, _Digits), 
            " (来自", timeframeStr, " K线序号: ", priceShift + 1, ", 时间: ", TimeToString(resistanceTime),
            ", 在1H周期找到匹配K线序号: ", h1Shift, ", 时间: ", TimeToString(h1Time), ")");
     }
     
   // 在1小时周期未找到匹配K线的压力位日志
   static void LogResistanceMatchNotFound(ENUM_TIMEFRAMES timeframe, double resistancePrice, int priceShift, datetime resistanceTime)
     {
      string timeframeStr = TimeframeToString(timeframe);
      Print("计算得到的", timeframeStr, "压力位: ", DoubleToString(resistancePrice, _Digits), 
            " (来自", timeframeStr, " K线序号: ", priceShift + 1, ", 时间: ", TimeToString(resistanceTime),
            ", 在1H周期未找到匹配K线，使用当前时间)");
     }
     
   // 获取日线压力值日志
   static void LogGetResistanceD1(double resistanceD1, datetime resistanceD1Time)
     {
      Print("获取日线压力值: ", DoubleToString(resistanceD1, _Digits), ", 时间: ", TimeToString(resistanceD1Time));
     }
     
   // 最低点K线日志
   static void LogLowestBar(int lowestBarIndex, datetime lowestTime)
     {
      Print("最低点出现在序号为", lowestBarIndex, "的K线上，时间为", TimeToString(lowestTime));
     }
     
private:
   // 将时间周期转换为字符串
   static string TimeframeToString(ENUM_TIMEFRAMES timeframe)
     {
      switch(timeframe)
        {
         case PERIOD_M1:  return "1分钟";
         case PERIOD_M5:  return "5分钟";
         case PERIOD_M15: return "15分钟";
         case PERIOD_M30: return "30分钟";
         case PERIOD_H1:  return "1小时";
         case PERIOD_H4:  return "4小时";
         case PERIOD_D1:  return "日线";
         case PERIOD_W1:  return "周线";
         case PERIOD_MN1: return "月线";
         default:         return "未知";
        }
     }
  };