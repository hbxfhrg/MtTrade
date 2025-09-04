//+------------------------------------------------------------------+
//|                                              DynamicPricePoint.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

#include "SupportResistancePoint.mqh"
#include "CommonUtils.mqh"
#include "LogUtil.mqh"
#include "EnumDefinitions.mqh"

//+------------------------------------------------------------------+
//| 动态价格点类 - 统一处理回撤点、反弹点和区间高低点                   |
//| 这些点都是基于参考价格计算的，只是类型和用途不同                    |
//+------------------------------------------------------------------+
class CDynamicPricePoint
  {
private:
   // 参考价格和时间
   double            m_referencePrice;   // 参考价格（用于计算支撑或压力）
   datetime          m_referenceTime;    // 参考时间
   bool              m_isUpTrend;        // 当前趋势方向（true为上涨，false为下跌）
   
   // 不同时间周期的价格点
   CSupportResistancePoint m_pointH1;    // 1小时价格点
   CSupportResistancePoint m_pointH4;    // 4小时价格点
   CSupportResistancePoint m_pointD1;    // 日线价格点
   
   // 点类型
   ENUM_SR_POINT_TYPE m_pointType;       // 点类型（支撑、压力、回撤点等）

public:
   // 查找与参考价格匹配的K线时间
   datetime FindMatchingCandleTime(double referencePrice)
     {
      if(referencePrice <= 0.0)
         return 0;
         
      // 在1小时K线上查找与参考价格匹配的K线
      int bars = Bars(Symbol(), PERIOD_H1);
      int priceShift = -1;
      
      // 遍历K线，查找与参考价格匹配的K线
      for(int i = 0; i < bars && i < 100; i++) // 限制搜索范围，避免过度消耗资源
        {
         double high = iHigh(Symbol(), PERIOD_H1, i);
         double low = iLow(Symbol(), PERIOD_H1, i);
         
         // 如果价格在当前K线的范围内或非常接近
         if((referencePrice <= high && referencePrice >= low) || 
            MathAbs(high - referencePrice) < Point() * 10 || 
            MathAbs(low - referencePrice) < Point() * 10)
           {
            priceShift = i;
            break;
           }
        }
      
      // 如果找到了匹配的K线，获取其时间
      if(priceShift >= 0)
         return iTime(Symbol(), PERIOD_H1, priceShift);
      else
         return TimeCurrent(); // 如果没有找到匹配的K线，使用当前时间
     }

   // 构造函数
   CDynamicPricePoint(double referencePrice = 0.0, 
                     ENUM_SR_POINT_TYPE pointType = SR_SUPPORT)
     {
      m_referencePrice = referencePrice;
      m_pointType = pointType;
      m_isUpTrend = IsPointTypeSupport(pointType); // 根据点类型设置趋势方向
      
      // 如果提供了参考价格，自动查找对应的时间
      m_referenceTime = (referencePrice > 0.0) ? FindMatchingCandleTime(referencePrice) : 0;
      
      // 初始化价格点
      m_pointH1 = CSupportResistancePoint(0.0, 0, PERIOD_H1, -1, pointType);
      m_pointH4 = CSupportResistancePoint(0.0, 0, PERIOD_H4, -1, pointType);
      m_pointD1 = CSupportResistancePoint(0.0, 0, PERIOD_D1, -1, pointType);
      
      // 计算价格点
      Calculate();
     }
     
   // 判断点类型是否为支撑类型
   bool IsPointTypeSupport(ENUM_SR_POINT_TYPE pointType)
     {
      return (pointType == SR_SUPPORT || 
              pointType == SR_SUPPORT_RANGE_HIGH || 
              pointType == SR_SUPPORT_REBOUND);
     }
     
   // 计算所有时间周期的价格点
   void Calculate()
     {
      if(m_referencePrice <= 0.0 || m_referenceTime == 0)
         return;
         
      // 定义需要计算的时间周期数组
      ENUM_TIMEFRAMES timeframes[] = {PERIOD_H1, PERIOD_H4, PERIOD_D1};
      CSupportResistancePoint* points[] = {&m_pointH1, &m_pointH4, &m_pointD1};
      
      // 对每个时间周期进行计算
      for(int i = 0; i < ArraySize(timeframes); i++)
        {
         CalculatePricePoint(timeframes[i], *points[i]);
        }
     }
     
   // 设置价格点的属性
   void SetPointProperties(CSupportResistancePoint &point, double price, datetime time, 
                          int barIndex, ENUM_TIMEFRAMES timeframe)
     {
      point.price = price;
      point.time = time;
      point.bar_index = barIndex;
      point.timeframe = timeframe;
      point.type = m_pointType;
     }
   
   // 在1小时周期上查找匹配的K线时间
   datetime FindMatchingH1Time(double price, bool isSupport)
     {
      int h1Bars = Bars(Symbol(), PERIOD_H1);
      int h1Shift = -1;
      
      // 遍历1小时K线，查找与价格匹配的K线
      for(int i = 0; i < h1Bars; i++)
        {
         // 根据是支撑还是压力选择比较的价格
         double h1Price = isSupport ? iLow(Symbol(), PERIOD_H1, i) : iHigh(Symbol(), PERIOD_H1, i);
         
         // 如果找到与价格相等或非常接近的点
         if(MathAbs(h1Price - price) < Point() * 10)
           {
            h1Shift = i;
            break;
           }
        }
      
      // 如果找到了匹配的1小时K线
      if(h1Shift >= 0)
         return iTime(Symbol(), PERIOD_H1, h1Shift);
      else
         return TimeCurrent(); // 如果没有找到匹配的K线，使用当前时间
     }

   // 计算指定时间周期的价格点
   void CalculatePricePoint(ENUM_TIMEFRAMES timeframe, CSupportResistancePoint &point)
     {
      // 如果参考价格为0，则不计算
      if(m_referencePrice <= 0)
        {
         point.price = 0.0;
         return;
        }
      
      // 初始化价格
      double price = 0.0;
      bool isSupport = IsPointTypeSupport(m_pointType);
      
      // 在当前周期的K线中查找与参考价格最接近的K线
      int bars = Bars(Symbol(), timeframe);
      int priceShift = -1;
      
      // 遍历K线，查找与参考价格匹配的K线
      for(int i = 0; i < bars; i++)
        {
         // 根据是支撑还是压力选择比较的价格
         double comparePrice = isSupport ? iHigh(Symbol(), timeframe, i) : iLow(Symbol(), timeframe, i);
         
         // 如果找到与参考价格相等或非常接近的点
         if(MathAbs(comparePrice - m_referencePrice) < Point() * 10)
           {
            priceShift = i;
            break;
           }
        }
      
      // 如果找不到匹配的K线，使用时间查找
      if(priceShift < 0)
        {
         priceShift = iBarShift(Symbol(), timeframe, m_referenceTime);
        }
      
      // 如果价格K线索引有效
      if(priceShift >= 0)
        {
         int targetShift = (priceShift + 1 < bars) ? priceShift + 1 : priceShift;
         
         // 根据是支撑还是压力选择价格
         price = isSupport ? iLow(Symbol(), timeframe, targetShift) : iHigh(Symbol(), timeframe, targetShift);
         
         // 获取对应的K线时间
         datetime priceTime = iTime(Symbol(), timeframe, targetShift);
         
         // 更新点对象
         datetime finalTime = priceTime;
         
         // 如果是4小时或日线周期，尝试在1小时周期上查找匹配的K线
         if(timeframe == PERIOD_H4 || timeframe == PERIOD_D1)
           {
            finalTime = FindMatchingH1Time(price, isSupport);
           }
           
         // 设置点的所有属性
         SetPointProperties(point, price, finalTime, targetShift, timeframe);
        }
     }
     
   // 根据时间周期获取价格点
   CSupportResistancePoint* GetPoint(ENUM_TIMEFRAMES timeframe)
     {
      switch(timeframe)
        {
         case PERIOD_H1: return &m_pointH1;
         case PERIOD_H4: return &m_pointH4;
         case PERIOD_D1: return &m_pointD1;
         default: return NULL;
        }
     }
     
   // 根据时间周期获取价格
   double GetPrice(ENUM_TIMEFRAMES timeframe)
     {
      CSupportResistancePoint* point = GetPoint(timeframe);
      return point != NULL ? point.price : 0.0;
     }
     
   // 根据时间周期获取时间
   datetime GetTime(ENUM_TIMEFRAMES timeframe)
     {
      CSupportResistancePoint* point = GetPoint(timeframe);
      return point != NULL ? point.time : 0;
     }
     
   // 获取价格点类型描述
   string GetTypeDescription()
     {
      switch(m_pointType)
        {
         case SR_SUPPORT:
            return "支撑";
         case SR_RESISTANCE:
            return "压力";
         case SR_SUPPORT_RANGE_HIGH:
            return "区间高点支撑";
         case SR_RESISTANCE_RETRACE:
            return "回撤点压力";
         case SR_RESISTANCE_RANGE_LOW:
            return "区间低点压力";
         case SR_SUPPORT_REBOUND:
            return "反弹点支撑";
         default:
            return m_isUpTrend ? "支撑" : "压力";
        }
     }
     
   // 根据时间周期获取价格点描述
   string GetDescription(ENUM_TIMEFRAMES timeframe, int digits = 5)
     {
      CSupportResistancePoint* point = GetPoint(timeframe);
      return point != NULL ? point.GetDescription(digits) : "";
     }
     
   // 获取所有价格点的完整描述
   string GetFullDescription(int digits = 5)
     {
      string typeDesc = GetTypeDescription();
      
      // 创建一个包含所有时间周期的数组
      ENUM_TIMEFRAMES timeframes[] = {PERIOD_H1, PERIOD_H4, PERIOD_D1};
      string timeframeNames[] = {"H1", "H4", "D1"};
      string result = typeDesc + ": ";
      
      // 遍历所有时间周期，添加到描述中
      for(int i = 0; i < ArraySize(timeframes); i++)
        {
         double price = GetPrice(timeframes[i]);
         string priceStr = DoubleToString(price, digits);
         result += timeframeNames[i] + "=" + priceStr;
         
         // 如果不是最后一个元素，添加分隔符
         if(i < ArraySize(timeframes) - 1)
            result += ", ";
        }
      
      return result;
     }
     
   // 是否为上涨趋势
   bool IsUpTrend()
     {
      return m_isUpTrend;
     }
     
   // 获取点类型
   ENUM_SR_POINT_TYPE GetPointType()
     {
      return m_pointType;
     }
     
   // 设置参考价格
   void SetReferencePrice(double price)
     {
      m_referencePrice = price;
     }
     
   // 获取参考价格
   double GetReferencePrice()
     {
      return m_referencePrice;
     }
     
   // 设置参考时间
   void SetReferenceTime(datetime time)
     {
      m_referenceTime = time;
     }
     
   // 获取参考时间
   datetime GetReferenceTime()
     {
      return m_referenceTime;
     }
     
   // 设置点类型
   void SetPointType(ENUM_SR_POINT_TYPE pointType)
     {
      m_pointType = pointType;
      m_isUpTrend = IsPointTypeSupport(pointType);
      
      // 更新价格点类型
      m_pointH1.type = pointType;
      m_pointH4.type = pointType;
      m_pointD1.type = pointType;
     }
     
   // 重新计算所有价格点
   void Recalculate(double referencePrice, ENUM_SR_POINT_TYPE pointType = SR_SUPPORT)
     {
      m_referencePrice = referencePrice;
      
      // 如果提供了参考价格，自动查找对应的时间
      m_referenceTime = (referencePrice > 0.0) ? FindMatchingCandleTime(referencePrice) : 0;
      
      SetPointType(pointType);
      Calculate();
     }
     
   // 检查价格是否穿越了任何价格点
   void CheckPenetration(double price)
     {
      // 检查各个时间周期的价格点是否被穿越
      m_pointH1.CheckPenetration(price);
      m_pointH4.CheckPenetration(price);
      m_pointD1.CheckPenetration(price);
     }
     
   // 检查特定时间周期的价格点是否被穿越
   bool IsPenetrated(ENUM_TIMEFRAMES timeframe)
     {
      CSupportResistancePoint* point = GetPoint(timeframe);
      return point != NULL ? point.is_penetrated : false;
     }
  };