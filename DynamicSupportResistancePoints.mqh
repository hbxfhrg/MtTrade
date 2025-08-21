//+------------------------------------------------------------------+
//|                                   DynamicSupportResistancePoints.mqh |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

#include "SupportResistancePoint.mqh"
#include "CommonUtils.mqh"
#include "LogUtil.mqh"
#include "EnumDefinitions.mqh"

//+------------------------------------------------------------------+
//| 动态支撑压力点类 - 用于动态计算和管理不同时间周期的支撑和压力点      |
//+------------------------------------------------------------------+
class CDynamicSupportResistancePoints
  {
private:
   // 参考价格和时间
   double            m_referencePrice;   // 参考价格（用于计算支撑或压力）
   datetime          m_referenceTime;    // 参考时间
   bool              m_isUpTrend;        // 当前趋势方向（true为上涨，false为下跌）
   
   // 不同时间周期的支撑或压力点
   CSupportResistancePoint m_pointH1;    // 1小时支撑或压力点
   CSupportResistancePoint m_pointH4;    // 4小时支撑或压力点
   CSupportResistancePoint m_pointD1;    // 日线支撑或压力点

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
   CDynamicSupportResistancePoints(double referencePrice = 0.0, 
                                  ENUM_SR_POINT_TYPE pointType = SR_SUPPORT)
     {
      m_referencePrice = referencePrice;
      m_isUpTrend = (pointType == SR_SUPPORT); // 根据点类型设置趋势方向
      
      // 如果提供了参考价格，自动查找对应的时间
      m_referenceTime = (referencePrice > 0.0) ? FindMatchingCandleTime(referencePrice) : 0;
      
      // 初始化支撑或压力点
      m_pointH1 = CSupportResistancePoint(0.0, 0, PERIOD_H1, -1, pointType);
      m_pointH4 = CSupportResistancePoint(0.0, 0, PERIOD_H4, -1, pointType);
      m_pointD1 = CSupportResistancePoint(0.0, 0, PERIOD_D1, -1, pointType);
      
      // 计算支撑或压力点
      Calculate();
     }
     
   // 计算所有时间周期的支撑或压力点
   void Calculate()
     {
      if(m_referencePrice <= 0.0 || m_referenceTime == 0)
         return;
         
      // 根据点类型决定计算支撑位还是压力位
      ENUM_SR_POINT_TYPE pointType = m_pointH1.GetType();
      
      // 定义需要计算的时间周期数组
      ENUM_TIMEFRAMES timeframes[] = {PERIOD_H1, PERIOD_H4, PERIOD_D1};
      CSupportResistancePoint* points[] = {&m_pointH1, &m_pointH4, &m_pointD1};
      
      // 对每个时间周期进行计算
      for(int i = 0; i < ArraySize(timeframes); i++)
        {
         switch(pointType)
           {
            case SR_SUPPORT:
            case SR_SUPPORT_REBOUND:
               // 计算普通支撑位或反弹点支撑
               CalculateSupport(timeframes[i], *points[i]);
               break;
               
            case SR_RESISTANCE:
            case SR_RESISTANCE_RETRACE:
               // 计算普通压力位或回撤点压力
               CalculateResistance(timeframes[i], *points[i]);
               break;
               
            case SR_SUPPORT_RANGE_HIGH:
               // 计算区间高点支撑（上涨行情）
               CalculateRangeHighSupport(timeframes[i], *points[i]);
               break;
               
            case SR_RESISTANCE_RANGE_LOW:
               // 计算区间低点压力（下跌行情）
               CalculateRangeLowResistance(timeframes[i], *points[i]);
               break;
           }
        }
     }
     
   // 通用方法：计算指定时间周期的支撑或压力位
   void CalculateSupportResistanceLevel(ENUM_TIMEFRAMES timeframe, CSupportResistancePoint &point, 
                                       bool isSupport, ENUM_SR_POINT_TYPE pointType)
     {
      // 如果参考价格为0，则不计算
      if(m_referencePrice <= 0)
        {
         point.m_price = 0.0;
         return;
        }
      
      // 初始化价格
      double price = 0.0;
      
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
         point.m_price = price;
         point.m_time = priceTime;
         point.m_barIndex = targetShift;
         point.m_timeframe = timeframe;
         point.SetType(pointType);
         
         // 如果是4小时或日线周期，尝试在1小时周期上查找匹配的K线
         if(timeframe == PERIOD_H4 || timeframe == PERIOD_D1)
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
              {
               datetime h1Time = iTime(Symbol(), PERIOD_H1, h1Shift);
               point.m_time = h1Time;
              }
            else
              {
               // 如果没有找到匹配的K线，使用当前时间
               point.m_time = TimeCurrent();
              }
           }
        }
     }
     
   // 计算指定时间周期的支撑位
   void CalculateSupport(ENUM_TIMEFRAMES timeframe, CSupportResistancePoint &supportPoint)
     {
      CalculateSupportResistanceLevel(timeframe, supportPoint, true, SR_SUPPORT);
     }
     
   // 计算指定时间周期的压力位
   void CalculateResistance(ENUM_TIMEFRAMES timeframe, CSupportResistancePoint &resistancePoint)
     {
      CalculateSupportResistanceLevel(timeframe, resistancePoint, false, SR_RESISTANCE);
     }
     
   // 获取1小时支撑或压力点
   CSupportResistancePoint* GetPointH1()
     {
      return &m_pointH1;
     }
     
   // 获取4小时支撑或压力点
   CSupportResistancePoint* GetPointH4()
     {
      return &m_pointH4;
     }
     
   // 获取日线支撑或压力点
   CSupportResistancePoint* GetPointD1()
     {
      return &m_pointD1;
     }
     
   // 获取1小时支撑或压力价格
   double GetPriceH1()
     {
      return m_pointH1.m_price;
     }
     
   // 获取4小时支撑或压力价格
   double GetPriceH4()
     {
      return m_pointH4.m_price;
     }
     
   // 获取日线支撑或压力价格
   double GetPriceD1()
     {
      return m_pointD1.m_price;
     }
     
   // 获取1小时支撑或压力时间
   datetime GetTimeH1()
     {
      return m_pointH1.m_time;
     }
     
   // 获取4小时支撑或压力时间
   datetime GetTimeH4()
     {
      return m_pointH4.m_time;
     }
     
   // 获取日线支撑或压力时间
   datetime GetTimeD1()
     {
      return m_pointD1.m_time;
     }
     
   // 计算区间高点支撑（上涨行情）
   void CalculateRangeHighSupport(ENUM_TIMEFRAMES timeframe, CSupportResistancePoint &supportPoint)
     {
      CalculateSupportResistanceLevel(timeframe, supportPoint, true, SR_SUPPORT_RANGE_HIGH);
     }
     
   // 计算区间低点压力（下跌行情）
   void CalculateRangeLowResistance(ENUM_TIMEFRAMES timeframe, CSupportResistancePoint &resistancePoint)
     {
      CalculateSupportResistanceLevel(timeframe, resistancePoint, false, SR_RESISTANCE_RANGE_LOW);
     }
     
   // 获取支撑或压力类型描述
   string GetTypeDescription()
     {
      ENUM_SR_POINT_TYPE pointType = m_pointH1.GetType();
      
      switch(pointType)
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
     
   // 获取1小时支撑或压力描述
   string GetDescriptionH1(int digits = 5)
     {
      return m_pointH1.GetDescription(digits);
     }
     
   // 获取4小时支撑或压力描述
   string GetDescriptionH4(int digits = 5)
     {
      return m_pointH4.GetDescription(digits);
     }
     
   // 获取日线支撑或压力描述
   string GetDescriptionD1(int digits = 5)
     {
      return m_pointD1.GetDescription(digits);
     }
     
   // 获取所有支撑或压力点的完整描述
   string GetFullDescription(int digits = 5)
     {
      string typeDesc = GetTypeDescription();
      string h1Desc = DoubleToString(m_pointH1.m_price, digits);
      string h4Desc = DoubleToString(m_pointH4.m_price, digits);
      string d1Desc = DoubleToString(m_pointD1.m_price, digits);
      
      return StringFormat("%s: H1=%s, H4=%s, D1=%s", 
                         typeDesc, h1Desc, h4Desc, d1Desc);
     }
     
   // 是否为上涨趋势
   bool IsUpTrend()
     {
      return m_isUpTrend;
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
      m_isUpTrend = (pointType == SR_SUPPORT);
      
      // 更新支撑或压力点类型
      m_pointH1.SetType(pointType);
      m_pointH4.SetType(pointType);
      m_pointD1.SetType(pointType);
     }
     
   // 重新计算所有支撑或压力点
   void Recalculate(double referencePrice, ENUM_SR_POINT_TYPE pointType = SR_SUPPORT)
     {
      m_referencePrice = referencePrice;
      
      // 如果提供了参考价格，自动查找对应的时间
      m_referenceTime = (referencePrice > 0.0) ? FindMatchingCandleTime(referencePrice) : 0;
      
      SetPointType(pointType);
      Calculate();
     }
  };