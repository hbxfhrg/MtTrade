//+------------------------------------------------------------------+
//|                                         SupportResistancePoint.mqh |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

#include "EnumDefinitions.mqh"

//+------------------------------------------------------------------+
//| 支撑压力点类 - 用于存储支撑和压力点的信息                          |
//+------------------------------------------------------------------+
class CSupportResistancePoint：public CObject
  {
public:
   // 公共属性
   double            price;           // 价格
   datetime          time;            // 时间
   ENUM_TIMEFRAMES   timeframe;       // 时间周期
   int               bar_index;        // K线序号
   ENUM_SR_POINT_TYPE type;           // 点类型（支撑或压力）
   bool              is_penetrated;    // 是否被穿越（支撑点被向下穿越或压力点被向上穿越）
   
   // 构造函数
   CSupportResistancePoint(double price_val = 0.0, 
                          datetime time_val = 0, 
                          ENUM_TIMEFRAMES tf = PERIOD_CURRENT, 
                          int barIndex = -1, 
                          bool isSupport = true)
     {
      this.price = price_val;
      this.time = time_val;
      this.timeframe = tf;
      this.bar_index = barIndex;
      this.type = isSupport ? SR_SUPPORT : SR_RESISTANCE;
      this.is_penetrated = false;
     }
     
   // 重载构造函数，直接使用枚举类型
   CSupportResistancePoint(double price_val, 
                          datetime time_val, 
                          ENUM_TIMEFRAMES tf, 
                          int barIndex, 
                          ENUM_SR_POINT_TYPE point_type)
     {
      this.price = price_val;
      this.time = time_val;
      this.timeframe = tf;
      this.bar_index = barIndex;
      this.type = point_type;
      this.is_penetrated = false;
     }
     


     


     
   // 获取时间周期描述
   string GetTimeframeDescription() const
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
         default:         return "未知";
        }
     }
     
   // 获取完整描述
   string GetDescription(int digits = 5) const
     {
      string priceText = DoubleToString(price, digits);
      string typeText = type == SR_SUPPORT ? "支撑" : "压力";
      string timeframeText = GetTimeframeDescription();
      string penetratedText = is_penetrated ? " (已穿越)" : "";
      
      return StringFormat("%s(%s): %s%s", typeText, timeframeText, priceText, penetratedText);
     }
     
   // 检查价格是否穿越了此点
   bool CheckPenetration(double price)
     {
      // 如果是支撑点，则价格低于支撑点表示被穿越
      if(type == SR_SUPPORT && price < this.price)
        {
         is_penetrated = true;
         return true;
        }
      
      // 如果是压力点，则价格高于压力点表示被穿越
      if(type == SR_RESISTANCE && price > this.price)
        {
         is_penetrated = true;
         return true;
        }
      
      return false;
     }
  };