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
class CSupportResistancePoint
  {
public:
   // 公共属性
   double            m_price;           // 价格
   datetime          m_time;            // 时间
   ENUM_TIMEFRAMES   m_timeframe;       // 时间周期
   int               m_barIndex;        // K线序号
   ENUM_SR_POINT_TYPE m_type;           // 点类型（支撑或压力）
   bool              m_isPenetrated;    // 是否被穿越（支撑点被向下穿越或压力点被向上穿越）
   
   // 构造函数
   CSupportResistancePoint(double price = 0.0, 
                          datetime time = 0, 
                          ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT, 
                          int barIndex = -1, 
                          bool isSupport = true)
     {
      m_price = price;
      m_time = time;
      m_timeframe = timeframe;
      m_barIndex = barIndex;
      m_type = isSupport ? SR_SUPPORT : SR_RESISTANCE;
      m_isPenetrated = false;
     }
     
   // 重载构造函数，直接使用枚举类型
   CSupportResistancePoint(double price, 
                          datetime time, 
                          ENUM_TIMEFRAMES timeframe, 
                          int barIndex, 
                          ENUM_SR_POINT_TYPE type)
     {
      m_price = price;
      m_time = time;
      m_timeframe = timeframe;
      m_barIndex = barIndex;
      m_type = type;
      m_isPenetrated = false;
     }
     
   // 获取价格
   double Price() const
     {
      return m_price;
     }
     
   // 设置价格
   void Price(double price)
     {
      m_price = price;
     }
     
   // 获取时间
   datetime Time() const
     {
      return m_time;
     }
     
   // 设置时间
   void Time(datetime time)
     {
      m_time = time;
     }
     
   // 获取时间周期
   ENUM_TIMEFRAMES Timeframe() const
     {
      return m_timeframe;
     }
     
   // 设置时间周期
   void Timeframe(ENUM_TIMEFRAMES timeframe)
     {
      m_timeframe = timeframe;
     }
     
   // 获取K线序号
   int BarIndex() const
     {
      return m_barIndex;
     }
     
   // 设置K线序号
   void BarIndex(int barIndex)
     {
      m_barIndex = barIndex;
     }
     
   // 是否为支撑点
   bool IsSupport() const
     {
      return m_type == SR_SUPPORT;
     }
     
   // 设置是否为支撑点
   void IsSupport(bool isSupport)
     {
      m_type = isSupport ? SR_SUPPORT : SR_RESISTANCE;
     }
     
   // 获取点类型
   ENUM_SR_POINT_TYPE GetType() const
     {
      return m_type;
     }
     
   // 设置点类型
   void SetType(ENUM_SR_POINT_TYPE type)
     {
      m_type = type;
     }
     
   // 获取类型描述
   string GetTypeDescription() const
     {
      return m_type == SR_SUPPORT ? "支撑" : "压力";
     }
     
   // 获取时间周期描述
   string GetTimeframeDescription() const
     {
      switch(m_timeframe)
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
      string priceText = DoubleToString(m_price, digits);
      string typeText = GetTypeDescription();
      string timeframeText = GetTimeframeDescription();
      string penetratedText = m_isPenetrated ? " (已穿越)" : "";
      
      return StringFormat("%s(%s): %s%s", typeText, timeframeText, priceText, penetratedText);
     }
     
   // 设置是否被穿越
   void SetPenetrated(bool isPenetrated)
     {
      m_isPenetrated = isPenetrated;
     }
     
   // 获取是否被穿越
   bool IsPenetrated() const
     {
      return m_isPenetrated;
     }
     
   // 检查价格是否穿越了此点
   bool CheckPenetration(double price)
     {
      // 如果是支撑点，则价格低于支撑点表示被穿越
      if(IsSupport() && price < m_price)
        {
         m_isPenetrated = true;
         return true;
        }
      
      // 如果是压力点，则价格高于压力点表示被穿越
      if(!IsSupport() && price > m_price)
        {
         m_isPenetrated = true;
         return true;
        }
      
      return false;
     }
  };