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
   // 构造函数
   CDynamicSupportResistancePoints(double referencePrice = 0.0, 
                                  ENUM_SR_POINT_TYPE pointType = SR_SUPPORT)
     {
      m_referencePrice = referencePrice;
      m_isUpTrend = (pointType == SR_SUPPORT); // 根据点类型设置趋势方向
      
      // 如果提供了参考价格，自动在1小时K线上查找对应的时间
      if(referencePrice > 0.0)
        {
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
           {
            m_referenceTime = iTime(Symbol(), PERIOD_H1, priceShift);
            Print("在1小时K线上找到与价格 ", DoubleToString(referencePrice, _Digits), 
                  " 匹配的K线，序号: ", priceShift, ", 时间: ", TimeToString(m_referenceTime));
           }
         else
           {
            // 如果没有找到匹配的K线，使用当前时间
            m_referenceTime = TimeCurrent();
            Print("在1小时K线上未找到与价格 ", DoubleToString(referencePrice, _Digits), 
                  " 匹配的K线，使用当前时间: ", TimeToString(m_referenceTime));
           }
        }
      else
        {
         m_referenceTime = 0;
        }
      
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
      
      switch(pointType)
        {
         case SR_SUPPORT:
         case SR_SUPPORT_REBOUND:
            // 计算普通支撑位或反弹点支撑
            CalculateSupport(PERIOD_H1, m_pointH1);
            CalculateSupport(PERIOD_H4, m_pointH4);
            CalculateSupport(PERIOD_D1, m_pointD1);
            break;
            
         case SR_RESISTANCE:
         case SR_RESISTANCE_RETRACE:
            // 计算普通压力位或回撤点压力
            CalculateResistance(PERIOD_H1, m_pointH1);
            CalculateResistance(PERIOD_H4, m_pointH4);
            CalculateResistance(PERIOD_D1, m_pointD1);
            break;
            
         case SR_SUPPORT_RANGE_HIGH:
            // 计算区间高点支撑（上涨行情）
            CalculateRangeHighSupport(PERIOD_H1, m_pointH1);
            CalculateRangeHighSupport(PERIOD_H4, m_pointH4);
            CalculateRangeHighSupport(PERIOD_D1, m_pointD1);
            break;
            
         case SR_RESISTANCE_RANGE_LOW:
            // 计算区间低点压力（下跌行情）
            CalculateRangeLowResistance(PERIOD_H1, m_pointH1);
            CalculateRangeLowResistance(PERIOD_H4, m_pointH4);
            CalculateRangeLowResistance(PERIOD_D1, m_pointD1);
            break;
        }
     }
     
   // 计算指定时间周期的支撑位
   void CalculateSupport(ENUM_TIMEFRAMES timeframe, CSupportResistancePoint &supportPoint)
     {
      // 如果参考价格为0，则不计算支撑位
      if(m_referencePrice <= 0)
        {
         supportPoint.m_price = 0.0;
         return;
        }
      
      // 初始化支撑价格
      double supportPrice = 0.0;
      
      // 在当前周期的K线中查找与参考价格最接近的K线
      int bars = Bars(Symbol(), timeframe);
      int priceShift = -1;
      
      // 遍历K线，查找与参考价格匹配的K线
      for(int i = 0; i < bars; i++)
        {
         double high = iHigh(Symbol(), timeframe, i);
         
         // 如果找到与参考价格相等或非常接近的高点
         if(MathAbs(high - m_referencePrice) < Point() * 10)
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
       
      
      // 如果价格K线索引有效且至少有一根前面的K线
      if(priceShift >= 0 && priceShift + 1 < bars)
        {
         // 取前一根K线的最低价作为支撑位
         supportPrice = iLow(Symbol(), timeframe, priceShift + 1);
         
         // 获取支撑位对应的K线时间
         datetime supportTime = iTime(Symbol(), timeframe, priceShift + 1);
         
         // 更新支撑点对象
         supportPoint.m_price = supportPrice;
         supportPoint.m_time = supportTime;
         supportPoint.m_barIndex = priceShift + 1;
         supportPoint.m_timeframe = timeframe;
         supportPoint.SetType(SR_SUPPORT);
         
         // 记录日志
         Print("计算得到的", TimeframeToString(timeframe), "支撑位: ", DoubleToString(supportPrice, _Digits), 
               " (来自K线序号: ", priceShift + 1, ", 时间: ", TimeToString(supportTime), ")");
         
         // 如果是4小时或日线周期，尝试在1小时周期上查找匹配的K线
         if(timeframe == PERIOD_H4 || timeframe == PERIOD_D1)
           {
            int h1Bars = Bars(Symbol(), PERIOD_H1);
            int h1Shift = -1;
            
            // 遍历1小时K线，查找与支撑价格匹配的K线
            for(int i = 0; i < h1Bars; i++)
              {
               double h1Low = iLow(Symbol(), PERIOD_H1, i);
               
               // 如果找到与支撑价格相等或非常接近的低点
               if(MathAbs(h1Low - supportPrice) < Point() * 10)
                 {
                  h1Shift = i;
                  break;
                 }
              }
            
            // 如果找到了匹配的1小时K线
            if(h1Shift >= 0)
              {
               datetime h1Time = iTime(Symbol(), PERIOD_H1, h1Shift);
               supportPoint.m_time = h1Time;
               Print("计算得到的", TimeframeToString(timeframe), "支撑位: ", DoubleToString(supportPrice, _Digits), 
                     " (来自", TimeframeToString(timeframe), "K线序号: ", priceShift + 1, ", 时间: ", TimeToString(supportTime),
                     ", 在1H周期找到匹配K线序号: ", h1Shift, ", 时间: ", TimeToString(h1Time), ")");
              }
            else
              {
               // 如果没有找到匹配的K线，使用当前时间
               supportPoint.m_time = TimeCurrent();
               Print("计算得到的", TimeframeToString(timeframe), "支撑位: ", DoubleToString(supportPrice, _Digits), 
                     " (来自", TimeframeToString(timeframe), "K线序号: ", priceShift + 1, ", 时间: ", TimeToString(supportTime),
                     ", 在1H周期未找到匹配K线，使用当前时间)");
              }
           }
        }
      else if(priceShift >= 0)
        {
         // 如果无法获取前一根K线，使用当前K线的最低价
         supportPrice = iLow(Symbol(), timeframe, priceShift);
         
         // 获取支撑位对应的K线时间
         datetime supportTime = iTime(Symbol(), timeframe, priceShift);
         
         // 更新支撑点对象
         supportPoint.m_price = supportPrice;
         supportPoint.m_time = supportTime;
         supportPoint.m_barIndex = priceShift;
         supportPoint.m_timeframe = timeframe;
         supportPoint.SetType(SR_SUPPORT);
         
         // 记录日志
         Print("无法获取前一根K线，使用当前K线的最低价作为支撑位: ", 
               DoubleToString(supportPrice, _Digits), 
               " (来自K线序号: ", priceShift, ", 时间: ", TimeToString(supportTime), ")");
         
         // 如果是4小时或日线周期，尝试在1小时周期上查找匹配的K线
         if(timeframe == PERIOD_H4 || timeframe == PERIOD_D1)
           {
            int h1Bars = Bars(Symbol(), PERIOD_H1);
            int h1Shift = -1;
            
            // 遍历1小时K线，查找与支撑价格匹配的K线
            for(int i = 0; i < h1Bars; i++)
              {
               double h1Low = iLow(Symbol(), PERIOD_H1, i);
               
               // 如果找到与支撑价格相等或非常接近的低点
               if(MathAbs(h1Low - supportPrice) < Point() * 10)
                 {
                  h1Shift = i;
                  break;
                 }
              }
            
            // 如果找到了匹配的1小时K线
            if(h1Shift >= 0)
              {
               datetime h1Time = iTime(Symbol(), PERIOD_H1, h1Shift);
               supportPoint.m_time = h1Time;
               Print("计算得到的", TimeframeToString(timeframe), "支撑位: ", DoubleToString(supportPrice, _Digits), 
                     " (来自", TimeframeToString(timeframe), "K线序号: ", priceShift, ", 时间: ", TimeToString(supportTime),
                     ", 在1H周期找到匹配K线序号: ", h1Shift, ", 时间: ", TimeToString(h1Time), ")");
              }
            else
              {
               // 如果没有找到匹配的K线，使用当前时间
               supportPoint.m_time = TimeCurrent();
               Print("计算得到的", TimeframeToString(timeframe), "支撑位: ", DoubleToString(supportPrice, _Digits), 
                     " (来自", TimeframeToString(timeframe), "K线序号: ", priceShift, ", 时间: ", TimeToString(supportTime),
                     ", 在1H周期未找到匹配K线，使用当前时间)");
              }
           }
        }
     }
     
   // 计算指定时间周期的压力位
   void CalculateResistance(ENUM_TIMEFRAMES timeframe, CSupportResistancePoint &resistancePoint)
     {
      // 如果参考价格为0，则不计算压力位
      if(m_referencePrice <= 0)
        {
         resistancePoint.m_price = 0.0;
         return;
        }
      
      // 初始化压力价格
      double resistancePrice = 0.0;
      
      // 在当前周期的K线中查找与参考价格最接近的K线
      int bars = Bars(Symbol(), timeframe);
      int priceShift = -1;
      
      // 遍历K线，查找与参考价格匹配的K线
      for(int i = 0; i < bars; i++)
        {
         double low = iLow(Symbol(), timeframe, i);
         
         // 如果找到与参考价格相等或非常接近的低点
         if(MathAbs(low - m_referencePrice) < Point() * 10)
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
      
      // 如果价格K线索引有效且至少有一根前面的K线
      if(priceShift >= 0 && priceShift + 1 < bars)
        {
         // 取前一根K线的最高价作为压力位
         resistancePrice = iHigh(Symbol(), timeframe, priceShift + 1);
         
         // 获取压力位对应的K线时间
         datetime resistanceTime = iTime(Symbol(), timeframe, priceShift + 1);
         
         // 更新压力点对象
         resistancePoint.m_price = resistancePrice;
         resistancePoint.m_time = resistanceTime;
         resistancePoint.m_barIndex = priceShift + 1;
         resistancePoint.m_timeframe = timeframe;
         resistancePoint.SetType(SR_RESISTANCE);
         
         // 记录日志
         Print("计算得到的", TimeframeToString(timeframe), "压力位: ", DoubleToString(resistancePrice, _Digits), 
               " (来自K线序号: ", priceShift + 1, ", 时间: ", TimeToString(resistanceTime), ")");
         
         // 如果是4小时或日线周期，尝试在1小时周期上查找匹配的K线
         if(timeframe == PERIOD_H4 || timeframe == PERIOD_D1)
           {
            int h1Bars = Bars(Symbol(), PERIOD_H1);
            int h1Shift = -1;
            
            // 遍历1小时K线，查找与压力价格匹配的K线
            for(int i = 0; i < h1Bars; i++)
              {
               double h1High = iHigh(Symbol(), PERIOD_H1, i);
               
               // 如果找到与压力价格相等或非常接近的高点
               if(MathAbs(h1High - resistancePrice) < Point() * 10)
                 {
                  h1Shift = i;
                  break;
                 }
              }
            
            // 如果找到了匹配的1小时K线
            if(h1Shift >= 0)
              {
               datetime h1Time = iTime(Symbol(), PERIOD_H1, h1Shift);
               resistancePoint.m_time = h1Time;
               Print("计算得到的", TimeframeToString(timeframe), "压力位: ", DoubleToString(resistancePrice, _Digits), 
                     " (来自", TimeframeToString(timeframe), "K线序号: ", priceShift + 1, ", 时间: ", TimeToString(resistanceTime),
                     ", 在1H周期找到匹配K线序号: ", h1Shift, ", 时间: ", TimeToString(h1Time), ")");
              }
            else
              {
               // 如果没有找到匹配的K线，使用当前时间
               resistancePoint.m_time = TimeCurrent();
               Print("计算得到的", TimeframeToString(timeframe), "压力位: ", DoubleToString(resistancePrice, _Digits), 
                     " (来自", TimeframeToString(timeframe), "K线序号: ", priceShift + 1, ", 时间: ", TimeToString(resistanceTime),
                     ", 在1H周期未找到匹配K线，使用当前时间)");
              }
           }
        }
      else if(priceShift >= 0)
        {
         // 如果无法获取前一根K线，使用当前K线的最高价
         resistancePrice = iHigh(Symbol(), timeframe, priceShift);
         
         // 获取压力位对应的K线时间
         datetime resistanceTime = iTime(Symbol(), timeframe, priceShift);
         
         // 更新压力点对象
         resistancePoint.m_price = resistancePrice;
         resistancePoint.m_time = resistanceTime;
         resistancePoint.m_barIndex = priceShift;
         resistancePoint.m_timeframe = timeframe;
         resistancePoint.SetType(SR_RESISTANCE);
         
         // 记录日志
         Print("无法获取前一根K线，使用当前K线的最高价作为压力位: ", 
               DoubleToString(resistancePrice, _Digits), 
               " (来自K线序号: ", priceShift, ", 时间: ", TimeToString(resistanceTime), ")");
         
         // 如果是4小时或日线周期，尝试在1小时周期上查找匹配的K线
         if(timeframe == PERIOD_H4 || timeframe == PERIOD_D1)
           {
            int h1Bars = Bars(Symbol(), PERIOD_H1);
            int h1Shift = -1;
            
            // 遍历1小时K线，查找与压力价格匹配的K线
            for(int i = 0; i < h1Bars; i++)
              {
               double h1High = iHigh(Symbol(), PERIOD_H1, i);
               
               // 如果找到与压力价格相等或非常接近的高点
               if(MathAbs(h1High - resistancePrice) < Point() * 10)
                 {
                  h1Shift = i;
                  break;
                 }
              }
            
            // 如果找到了匹配的1小时K线
            if(h1Shift >= 0)
              {
               datetime h1Time = iTime(Symbol(), PERIOD_H1, h1Shift);
               resistancePoint.m_time = h1Time;
               Print("计算得到的", TimeframeToString(timeframe), "压力位: ", DoubleToString(resistancePrice, _Digits), 
                     " (来自", TimeframeToString(timeframe), "K线序号: ", priceShift, ", 时间: ", TimeToString(resistanceTime),
                     ", 在1H周期找到匹配K线序号: ", h1Shift, ", 时间: ", TimeToString(h1Time), ")");
              }
            else
              {
               // 如果没有找到匹配的K线，使用当前时间
               resistancePoint.m_time = TimeCurrent();
               Print("计算得到的", TimeframeToString(timeframe), "压力位: ", DoubleToString(resistancePrice, _Digits), 
                     " (来自", TimeframeToString(timeframe), "K线序号: ", priceShift, ", 时间: ", TimeToString(resistanceTime),
                     ", 在1H周期未找到匹配K线，使用当前时间)");
              }
           }
        }
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
      // 如果参考价格为0，则不计算支撑位
      if(m_referencePrice <= 0)
        {
         supportPoint.m_price = 0.0;
         return;
        }
      
      // 初始化支撑价格
      double supportPrice = 0.0;
      
      // 在当前周期的K线中查找与参考价格最接近的K线
      int bars = Bars(Symbol(), timeframe);
      int priceShift = -1;
      
      // 遍历K线，查找与参考价格匹配的K线
      for(int i = 0; i < bars; i++)
        {
         double high = iHigh(Symbol(), timeframe, i);
         
         // 如果找到与参考价格相等或非常接近的高点
         if(MathAbs(high - m_referencePrice) < Point() * 10)
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
      
      // 如果价格K线索引有效且至少有一根前面的K线
      if(priceShift >= 0 && priceShift + 1 < bars)
        {
         // 取前一根K线的最低价作为支撑位
         supportPrice = iLow(Symbol(), timeframe, priceShift + 1);
         
         // 获取支撑位对应的K线时间
         datetime supportTime = iTime(Symbol(), timeframe, priceShift + 1);
         
         // 更新支撑点对象
         supportPoint.m_price = supportPrice;
         supportPoint.m_time = supportTime;
         supportPoint.m_barIndex = priceShift + 1;
         supportPoint.m_timeframe = timeframe;
         supportPoint.SetType(SR_SUPPORT_RANGE_HIGH);
         
         // 记录日志
         Print("计算得到的区间高点", TimeframeToString(timeframe), "支撑位: ", DoubleToString(supportPrice, _Digits), 
               " (来自K线序号: ", priceShift + 1, ", 时间: ", TimeToString(supportTime), ")");
         
         // 如果是4小时或日线周期，尝试在1小时周期上查找匹配的K线
         if(timeframe == PERIOD_H4 || timeframe == PERIOD_D1)
           {
            int h1Bars = Bars(Symbol(), PERIOD_H1);
            int h1Shift = -1;
            
            // 遍历1小时K线，查找与支撑价格匹配的K线
            for(int i = 0; i < h1Bars; i++)
              {
               double h1Low = iLow(Symbol(), PERIOD_H1, i);
               
               // 如果找到与支撑价格相等或非常接近的低点
               if(MathAbs(h1Low - supportPrice) < Point() * 10)
                 {
                  h1Shift = i;
                  break;
                 }
              }
            
            // 如果找到了匹配的1小时K线
            if(h1Shift >= 0)
              {
               datetime h1Time = iTime(Symbol(), PERIOD_H1, h1Shift);
               supportPoint.m_time = h1Time;
               Print("计算得到的区间高点", TimeframeToString(timeframe), "支撑位: ", DoubleToString(supportPrice, _Digits), 
                     " (来自", TimeframeToString(timeframe), "K线序号: ", priceShift + 1, ", 时间: ", TimeToString(supportTime),
                     ", 在1H周期找到匹配K线序号: ", h1Shift, ", 时间: ", TimeToString(h1Time), ")");
              }
            else
              {
               // 如果没有找到匹配的K线，使用当前时间
               supportPoint.m_time = TimeCurrent();
               Print("计算得到的区间高点", TimeframeToString(timeframe), "支撑位: ", DoubleToString(supportPrice, _Digits), 
                     " (来自", TimeframeToString(timeframe), "K线序号: ", priceShift + 1, ", 时间: ", TimeToString(supportTime),
                     ", 在1H周期未找到匹配K线，使用当前时间)");
              }
           }
        }
      else if(priceShift >= 0)
        {
         // 如果无法获取前一根K线，使用当前K线的最低价
         supportPrice = iLow(Symbol(), timeframe, priceShift);
         
         // 获取支撑位对应的K线时间
         datetime supportTime = iTime(Symbol(), timeframe, priceShift);
         
         // 更新支撑点对象
         supportPoint.m_price = supportPrice;
         supportPoint.m_time = supportTime;
         supportPoint.m_barIndex = priceShift;
         supportPoint.m_timeframe = timeframe;
         supportPoint.SetType(SR_SUPPORT_RANGE_HIGH);
         
         // 记录日志
         Print("无法获取前一根K线，使用当前K线的最低价作为区间高点支撑位: ", 
               DoubleToString(supportPrice, _Digits), 
               " (来自K线序号: ", priceShift, ", 时间: ", TimeToString(supportTime), ")");
         
         // 如果是4小时或日线周期，尝试在1小时周期上查找匹配的K线
         if(timeframe == PERIOD_H4 || timeframe == PERIOD_D1)
           {
            int h1Bars = Bars(Symbol(), PERIOD_H1);
            int h1Shift = -1;
            
            // 遍历1小时K线，查找与支撑价格匹配的K线
            for(int i = 0; i < h1Bars; i++)
              {
               double h1Low = iLow(Symbol(), PERIOD_H1, i);
               
               // 如果找到与支撑价格相等或非常接近的低点
               if(MathAbs(h1Low - supportPrice) < Point() * 10)
                 {
                  h1Shift = i;
                  break;
                 }
              }
            
            // 如果找到了匹配的1小时K线
            if(h1Shift >= 0)
              {
               datetime h1Time = iTime(Symbol(), PERIOD_H1, h1Shift);
               supportPoint.m_time = h1Time;
               Print("计算得到的区间高点", TimeframeToString(timeframe), "支撑位: ", DoubleToString(supportPrice, _Digits), 
                     " (来自", TimeframeToString(timeframe), "K线序号: ", priceShift, ", 时间: ", TimeToString(supportTime),
                     ", 在1H周期找到匹配K线序号: ", h1Shift, ", 时间: ", TimeToString(h1Time), ")");
              }
            else
              {
               // 如果没有找到匹配的K线，使用当前时间
               supportPoint.m_time = TimeCurrent();
               Print("计算得到的区间高点", TimeframeToString(timeframe), "支撑位: ", DoubleToString(supportPrice, _Digits), 
                     " (来自", TimeframeToString(timeframe), "K线序号: ", priceShift, ", 时间: ", TimeToString(supportTime),
                     ", 在1H周期未找到匹配K线，使用当前时间)");
              }
           }
        }
     }
     
   // 计算区间低点压力（下跌行情）
   void CalculateRangeLowResistance(ENUM_TIMEFRAMES timeframe, CSupportResistancePoint &resistancePoint)
     {
      // 如果参考价格为0，则不计算压力位
      if(m_referencePrice <= 0)
        {
         resistancePoint.m_price = 0.0;
         return;
        }
      
      // 初始化压力价格
      double resistancePrice = 0.0;
      
      // 在当前周期的K线中查找与参考价格最接近的K线
      int bars = Bars(Symbol(), timeframe);
      int priceShift = -1;
      
      // 遍历K线，查找与参考价格匹配的K线
      for(int i = 0; i < bars; i++)
        {
         double low = iLow(Symbol(), timeframe, i);
         
         // 如果找到与参考价格相等或非常接近的低点
         if(MathAbs(low - m_referencePrice) < Point() * 10)
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
      
      // 如果价格K线索引有效且至少有一根前面的K线
      if(priceShift >= 0 && priceShift + 1 < bars)
        {
         // 取前一根K线的最高价作为压力位
         resistancePrice = iHigh(Symbol(), timeframe, priceShift + 1);
         
         // 获取压力位对应的K线时间
         datetime resistanceTime = iTime(Symbol(), timeframe, priceShift + 1);
         
         // 更新压力点对象
         resistancePoint.m_price = resistancePrice;
         resistancePoint.m_time = resistanceTime;
         resistancePoint.m_barIndex = priceShift + 1;
         resistancePoint.m_timeframe = timeframe;
         resistancePoint.SetType(SR_RESISTANCE_RANGE_LOW);
         
         // 记录日志
         Print("计算得到的区间低点", TimeframeToString(timeframe), "压力位: ", DoubleToString(resistancePrice, _Digits), 
               " (来自K线序号: ", priceShift + 1, ", 时间: ", TimeToString(resistanceTime), ")");
         
         // 如果是4小时或日线周期，尝试在1小时周期上查找匹配的K线
         if(timeframe == PERIOD_H4 || timeframe == PERIOD_D1)
           {
            int h1Bars = Bars(Symbol(), PERIOD_H1);
            int h1Shift = -1;
            
            // 遍历1小时K线，查找与压力价格匹配的K线
            for(int i = 0; i < h1Bars; i++)
              {
               double h1High = iHigh(Symbol(), PERIOD_H1, i);
               
               // 如果找到与压力价格相等或非常接近的高点
               if(MathAbs(h1High - resistancePrice) < Point() * 10)
                 {
                  h1Shift = i;
                  break;
                 }
              }
            
            // 如果找到了匹配的1小时K线
            if(h1Shift >= 0)
              {
               datetime h1Time = iTime(Symbol(), PERIOD_H1, h1Shift);
               resistancePoint.m_time = h1Time;
               Print("计算得到的区间低点", TimeframeToString(timeframe), "压力位: ", DoubleToString(resistancePrice, _Digits), 
                     " (来自", TimeframeToString(timeframe), "K线序号: ", priceShift + 1, ", 时间: ", TimeToString(resistanceTime),
                     ", 在1H周期找到匹配K线序号: ", h1Shift, ", 时间: ", TimeToString(h1Time), ")");
              }
            else
              {
               // 如果没有找到匹配的K线，使用当前时间
               resistancePoint.m_time = TimeCurrent();
               Print("计算得到的区间低点", TimeframeToString(timeframe), "压力位: ", DoubleToString(resistancePrice, _Digits), 
                     " (来自", TimeframeToString(timeframe), "K线序号: ", priceShift + 1, ", 时间: ", TimeToString(resistanceTime),
                     ", 在1H周期未找到匹配K线，使用当前时间)");
              }
           }
        }
      else if(priceShift >= 0)
        {
         // 如果无法获取前一根K线，使用当前K线的最高价
         resistancePrice = iHigh(Symbol(), timeframe, priceShift);
         
         // 获取压力位对应的K线时间
         datetime resistanceTime = iTime(Symbol(), timeframe, priceShift);
         
         // 更新压力点对象
         resistancePoint.m_price = resistancePrice;
         resistancePoint.m_time = resistanceTime;
         resistancePoint.m_barIndex = priceShift;
         resistancePoint.m_timeframe = timeframe;
         resistancePoint.SetType(SR_RESISTANCE_RANGE_LOW);
         
         // 记录日志
         Print("无法获取前一根K线，使用当前K线的最高价作为区间低点压力位: ", 
               DoubleToString(resistancePrice, _Digits), 
               " (来自K线序号: ", priceShift, ", 时间: ", TimeToString(resistanceTime), ")");
         
         // 如果是4小时或日线周期，尝试在1小时周期上查找匹配的K线
         if(timeframe == PERIOD_H4 || timeframe == PERIOD_D1)
           {
            int h1Bars = Bars(Symbol(), PERIOD_H1);
            int h1Shift = -1;
            
            // 遍历1小时K线，查找与压力价格匹配的K线
            for(int i = 0; i < h1Bars; i++)
              {
               double h1High = iHigh(Symbol(), PERIOD_H1, i);
               
               // 如果找到与压力价格相等或非常接近的高点
               if(MathAbs(h1High - resistancePrice) < Point() * 10)
                 {
                  h1Shift = i;
                  break;
                 }
              }
            
            // 如果找到了匹配的1小时K线
            if(h1Shift >= 0)
              {
               datetime h1Time = iTime(Symbol(), PERIOD_H1, h1Shift);
               resistancePoint.m_time = h1Time;
               Print("计算得到的区间低点", TimeframeToString(timeframe), "压力位: ", DoubleToString(resistancePrice, _Digits), 
                     " (来自", TimeframeToString(timeframe), "K线序号: ", priceShift, ", 时间: ", TimeToString(resistanceTime),
                     ", 在1H周期找到匹配K线序号: ", h1Shift, ", 时间: ", TimeToString(h1Time), ")");
              }
            else
              {
               // 如果没有找到匹配的K线，使用当前时间
               resistancePoint.m_time = TimeCurrent();
               Print("计算得到的区间低点", TimeframeToString(timeframe), "压力位: ", DoubleToString(resistancePrice, _Digits), 
                     " (来自", TimeframeToString(timeframe), "K线序号: ", priceShift, ", 时间: ", TimeToString(resistanceTime),
                     ", 在1H周期未找到匹配K线，使用当前时间)");
              }
           }
        }
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
      
      // 如果提供了参考价格，自动在1小时K线上查找对应的时间
      if(referencePrice > 0.0)
        {
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
           {
            m_referenceTime = iTime(Symbol(), PERIOD_H1, priceShift);
            Print("在1小时K线上找到与价格 ", DoubleToString(referencePrice, _Digits), 
                  " 匹配的K线，序号: ", priceShift, ", 时间: ", TimeToString(m_referenceTime));
           }
         else
           {
            // 如果没有找到匹配的K线，使用当前时间
            m_referenceTime = TimeCurrent();
            Print("在1小时K线上未找到与价格 ", DoubleToString(referencePrice, _Digits), 
                  " 匹配的K线，使用当前时间: ", TimeToString(m_referenceTime));
           }
        }
      
      SetPointType(pointType);
      Calculate();
     }
  };