//+------------------------------------------------------------------+
//|                                                 TradeAnalyzer.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

// 引入极值点类定义和线段类定义
#include "ZigzagExtremumPoint.mqh"
#include "ZigzagSegment.mqh"
#include "CommonUtils.mqh"
#include "LogUtil.mqh"
#include "SupportResistancePoint.mqh"
#include "DynamicPricePoint.mqh"
#include "EnumDefinitions.mqh"
#include "ConfigManager.mqh"

//+------------------------------------------------------------------+
//| 交易分析类 - 用于分析价格区间和趋势方向                            |
//+------------------------------------------------------------------+
class CTradeAnalyzer
  {
private:
   // ZigZag参数
   int       m_zigzagDepth;     // ZigZag深度参数
   int       m_zigzagDeviation; // ZigZag偏差参数
   int       m_zigzagBackstep;  // ZigZag回溯步数参数
   
   // 主交易线段 - 使用线段数组来管理多个区间线段
   CZigzagSegment* m_mainTradingSegments[];  // 主交易线段数组（当前为4小时周期，将来可能是其他周期）
   CZigzagSegment* m_currentSegment;         // 当前线段（指向m_mainTradingSegments[0]，简化访问）
   bool      m_isValid;         // 数据是否有效
   
   // 回撤和反弹相关变量
   double    m_retracePrice;    // 回撤最低点或反弹最高点
   datetime  m_retraceTime;     // 回撤或反弹点的时间
   double    m_retracePercent;  // 回撤或反弹的百分比
   double    m_retraceDiff;     // 回撤或反弹的绝对值差距
   
   // 动态价格点
   CDynamicPricePoint m_supportPoints;    // 支撑点集合
   CDynamicPricePoint m_resistancePoints; // 压力点集合
   
   // 品种名称
   string    m_symbol;          // 交易品种名称

public:
   // 构造函数
   CTradeAnalyzer(string symbol = NULL)
     {
      // 初始化主交易线段数组
      ArrayResize(m_mainTradingSegments, 0);
      m_currentSegment = NULL;  // 初始化为空指针
      m_isValid = false;
      m_retracePrice = 0.0;
      m_retraceTime = 0;
      m_retracePercent = 0.0;
      m_retraceDiff = 0.0;
      
      // 初始化动态价格点
      m_supportPoints = CDynamicPricePoint(0.0, SR_SUPPORT);
      m_resistancePoints = CDynamicPricePoint(0.0, SR_RESISTANCE);
      
      // 初始化ZigZag参数
      m_zigzagDepth = 12;
      m_zigzagDeviation = 5;
      m_zigzagBackstep = 3;
      
      // 初始化品种名称
      m_symbol = (symbol == NULL) ? Symbol() : symbol;
     }
     
   // 初始化方法
   void Init()
     {
      // 初始化主交易线段数组
      // 释放已存在的线段对象
      for(int i = 0; i < ArraySize(m_mainTradingSegments); i++)
        {
         if(m_mainTradingSegments[i] != NULL)
           {
            delete m_mainTradingSegments[i];
            m_mainTradingSegments[i] = NULL;
           }
        }
      ArrayResize(m_mainTradingSegments, 0);
      m_currentSegment = NULL;  // 重置为空指针
      m_isValid = false;
      m_retracePrice = 0.0;
      m_retraceTime = 0;
      m_retracePercent = 0.0;
      m_retraceDiff = 0.0;
      
      // 初始化动态价格点
      m_supportPoints = CDynamicPricePoint(0.0, SR_SUPPORT);
      m_resistancePoints = CDynamicPricePoint(0.0, SR_RESISTANCE);
     }
     
   // 从极点数组中分析区间，创建多个主交易线段
   bool AnalyzeRange(CZigzagExtremumPoint &points[], int minPoints = 2)
     {
      // 检查数据有效性
      if(ArraySize(points) < minPoints)
        {
         m_isValid = false;
         return false;
        }
        
      // 清理旧的主交易线段
      for(int i = 0; i < ArraySize(m_mainTradingSegments); i++)
        {
         if(m_mainTradingSegments[i] != NULL)
           {
            delete m_mainTradingSegments[i];
            m_mainTradingSegments[i] = NULL;
           }
        }
      
      // 根据极值点数量创建多个线段
      int segmentCount = ArraySize(points) - 1; // n个极值点可以创建(n-1)个线段
      ArrayResize(m_mainTradingSegments, segmentCount);
      
      // 创建所有可能的线段
      for(int i = 0; i < segmentCount; i++)
        {
         // 使用相邻的两个极值点创建线段
         m_mainTradingSegments[i] = new CZigzagSegment(points[i+1], points[i]);
        }
      
      // 按时间排序，最近的线段排在前面（自动更新当前线段指针）
      SortSegmentsByTimeDesc();
      
      m_isValid = true;
      
      // 分析完区间后立即计算回撤或反弹（使用最近的线段）
      CalculateRetracement();
      
      // 计算多时间周期支撑和压力
      CalculateSupportResistance();
      
      return true;
     }
     

   // 获取指定时间周期的交易线段
   CZigzagSegment GetTradingSegmentByTimeframe(ENUM_TIMEFRAMES timeframe)
     {
      // 目前只支持4小时周期，其他周期应在需要时通过线段对象的GetSmallerTimeframeSegments方法获取
      if(timeframe == PERIOD_H4)
        {
         // 返回当前线段
         if(m_currentSegment != NULL)
            return *m_currentSegment;
         else
            return CZigzagSegment(); // 返回空线段
        }
      else
        {
         // 默认返回当前线段
         if(m_currentSegment != NULL)
            return *m_currentSegment;
         else
            return CZigzagSegment();
        }
     }
     

     
   // 计算回撤或反弹
   void CalculateRetracement()
     {
      if(!m_isValid || m_currentSegment == NULL)
         return;
         
      double currentPrice = GetCurrentPrice();
      
      // 使用当前线段来计算回撤或反弹
      CZigzagSegment* latestSegment = m_currentSegment;
      
      // 根据线段方向计算回撤或反弹
      if((*latestSegment).IsUptrend())
        {
         // 上涨趋势，计算回撤（从最高点到当前的最低点）
         // 使用通用函数查找高点之后的最低价格
         double rangeHigh = GetRangeHigh();
         double rangeLow = GetRangeLow();
         datetime rangeHighTime = GetRangeHighTime();
         
         m_retracePrice = FindLowestPriceAfterHighPrice(rangeHigh, m_retraceTime, PERIOD_CURRENT, PERIOD_M1, rangeHighTime);
         
         // 计算回撤绝对值
         m_retraceDiff = rangeHigh - m_retracePrice;
           
         // 计算回撤百分比 - 使用区间高低点差值作为分母
         double rangeDiff = rangeHigh - rangeLow;
         if(rangeDiff > 0)
            m_retracePercent = m_retraceDiff / rangeDiff * 100.0;
            
         // 检查回撤点是否穿越了支撑点
         if(m_retracePrice > 0)
           {
            // 检查各个时间周期的支撑点是否被穿越
            // 对于支撑点，如果回撤价格低于支撑价格，则支撑点被穿越
            double supportH1 = m_supportPoints.GetPrice(PERIOD_H1);
            double supportH4 = m_supportPoints.GetPrice(PERIOD_H4);
            double supportD1 = m_supportPoints.GetPrice(PERIOD_D1);
            
            if(supportH1 > 0 && m_retracePrice < supportH1)
              {
               CSupportResistancePoint* pointH1 = m_supportPoints.GetPoint(PERIOD_H1);
               if(pointH1 != NULL) 
                 {
                  pointH1.SetPenetrated(true);
                 }
              }
              
            if(supportH4 > 0 && m_retracePrice < supportH4)
              {
               CSupportResistancePoint* pointH4 = m_supportPoints.GetPoint(PERIOD_H4);
               if(pointH4 != NULL) 
                 {
                  pointH4.SetPenetrated(true);
                 }
              }
              
            if(supportD1 > 0 && m_retracePrice < supportD1)
              {
               CSupportResistancePoint* pointD1 = m_supportPoints.GetPoint(PERIOD_D1);
               if(pointD1 != NULL) 
                 {
                  pointD1.SetPenetrated(true);
                 }
              }
           }
        }
      else
        {
         // 下跌趋势，计算反弹（从最低点到当前的最高点）
         // 使用通用函数查找低点之后的最高价格
         double rangeLow = GetRangeLow();
         double rangeHigh = GetRangeHigh();
         datetime rangeLowTime = GetRangeLowTime();
         
         m_retracePrice = FindHighestPriceAfterLowPrice(rangeLow, m_retraceTime, PERIOD_CURRENT, PERIOD_M1, rangeLowTime);
         
         // 计算反弹绝对值
         m_retraceDiff = m_retracePrice - rangeLow;
           
         // 计算反弹百分比 - 使用区间高低点差值作为分母
         double rangeDiff = rangeHigh - rangeLow;
         if(rangeDiff > 0)
            m_retracePercent = m_retraceDiff / rangeDiff * 100.0;
            
         // 检查反弹点是否穿越了压力点
         if(m_retracePrice > 0)
           {
            // 检查各个时间周期的压力点是否被穿越
            // 对于压力点，如果反弹价格高于压力价格，则压力点被穿越
            double resistanceH1 = m_resistancePoints.GetPrice(PERIOD_H1);
            double resistanceH4 = m_resistancePoints.GetPrice(PERIOD_H4);
            double resistanceD1 = m_resistancePoints.GetPrice(PERIOD_D1);
            
            if(resistanceH1 > 0 && m_retracePrice > resistanceH1)
              {
               CSupportResistancePoint* pointH1 = m_resistancePoints.GetPoint(PERIOD_H1);
               if(pointH1 != NULL) pointH1.SetPenetrated(true);
              }
              
            if(resistanceH4 > 0 && m_retracePrice > resistanceH4)
              {
               CSupportResistancePoint* pointH4 = m_resistancePoints.GetPoint(PERIOD_H4);
               if(pointH4 != NULL) pointH4.SetPenetrated(true);
              }
              
            if(resistanceD1 > 0 && m_retracePrice > resistanceD1)
              {
               CSupportResistancePoint* pointD1 = m_resistancePoints.GetPoint(PERIOD_D1);
               if(pointD1 != NULL) pointD1.SetPenetrated(true);
              }
           }
        }
     }
     
     
   // 计算多时间周期的支撑和压力
   void CalculateSupportResistance()
     {
      if(!m_isValid || m_currentSegment == NULL)
         return;
         
      // 使用当前线段
      CZigzagSegment* latestSegment = m_currentSegment;
      
      // 根据线段方向计算支撑或压力
      if((*latestSegment).IsUptrend())
        {
         // 上涨趋势
         // 1. 计算区间高点的支撑
         m_supportPoints.Recalculate(GetRangeHigh(), SR_SUPPORT_RANGE_HIGH);
         
         // 2. 如果有回撤点，计算回撤点的压力
         if(m_retracePrice > 0.0)
           {
            m_resistancePoints.Recalculate(m_retracePrice, SR_RESISTANCE_RETRACE);
            
            // 检查各个时间周期的支撑点是否被穿越
            double supportH1 = m_supportPoints.GetPrice(PERIOD_H1);
            double supportH4 = m_supportPoints.GetPrice(PERIOD_H4);
            double supportD1 = m_supportPoints.GetPrice(PERIOD_D1);
            
            if(supportH1 > 0 && m_retracePrice < supportH1)
              {
               CSupportResistancePoint* pointH1 = m_supportPoints.GetPoint(PERIOD_H1);
               if(pointH1 != NULL) 
                 {
                  pointH1.SetPenetrated(true);
                 }
              }
              
            if(supportH4 > 0 && m_retracePrice < supportH4)
              {
               CSupportResistancePoint* pointH4 = m_supportPoints.GetPoint(PERIOD_H4);
               if(pointH4 != NULL) 
                 {
                  pointH4.SetPenetrated(true);
                 }
              }
              
            if(supportD1 > 0 && m_retracePrice < supportD1)
              {
               CSupportResistancePoint* pointD1 = m_supportPoints.GetPoint(PERIOD_D1);
               if(pointD1 != NULL) 
                 {
                  pointD1.SetPenetrated(true);
                 }
              }
           }
        }
      else
        {
         // 下跌趋势
         // 1. 计算区间低点的压力
         m_resistancePoints.Recalculate(GetRangeLow(), SR_RESISTANCE_RANGE_LOW);
         
         // 2. 如果有反弹点，计算反弹点的支撑
         if(m_retracePrice > 0.0)
           {
            m_supportPoints.Recalculate(m_retracePrice, SR_SUPPORT_REBOUND);
            
            // 检查各个时间周期的压力点是否被穿越
            double resistanceH1 = m_resistancePoints.GetPrice(PERIOD_H1);
            double resistanceH4 = m_resistancePoints.GetPrice(PERIOD_H4);
            double resistanceD1 = m_resistancePoints.GetPrice(PERIOD_D1);
            
            if(resistanceH1 > 0 && m_retracePrice > resistanceH1)
              {
               CSupportResistancePoint* pointH1 = m_resistancePoints.GetPoint(PERIOD_H1);
               if(pointH1 != NULL) 
                 {
                  pointH1.SetPenetrated(true);
                 }
              }
              
            if(resistanceH4 > 0 && m_retracePrice > resistanceH4)
              {
               CSupportResistancePoint* pointH4 = m_resistancePoints.GetPoint(PERIOD_H4);
               if(pointH4 != NULL) 
                 {
                  pointH4.SetPenetrated(true);
                 }
              }
              
            if(resistanceD1 > 0 && m_retracePrice > resistanceD1)
              {
               CSupportResistancePoint* pointD1 = m_resistancePoints.GetPoint(PERIOD_D1);
               if(pointD1 != NULL) 
                 {
                  pointD1.SetPenetrated(true);
                 }
              }
           }
        }
     }
     
   // 获取指定时间周期的支撑
   double GetSupportPrice(ENUM_TIMEFRAMES timeframe)
     {
      return m_supportPoints.GetPrice(timeframe);
     }
     
   // 获取指定时间周期的压力
   double GetResistancePrice(ENUM_TIMEFRAMES timeframe)
     {
      return m_resistancePoints.GetPrice(timeframe);
     }
     
   // 获取指定时间周期的支撑时间
   datetime GetSupportTime(ENUM_TIMEFRAMES timeframe)
     {
      return m_supportPoints.GetTime(timeframe);
     }
     
   // 获取指定时间周期的压力时间
   datetime GetResistanceTime(ENUM_TIMEFRAMES timeframe)
     {
      return m_resistancePoints.GetTime(timeframe);
     }
     
   // 获取支撑点对象
   CDynamicPricePoint* GetSupportPointsObject()
     {
      return &m_supportPoints;
     }
     
   // 获取压力点对象
   CDynamicPricePoint* GetResistancePointsObject()
     {
      return &m_resistancePoints;
     }
     
   // 获取当前线段（直接访问，不需要数组检查）
   CZigzagSegment* GetCurrentSegment()
     {
      return m_currentSegment;
     }
     
   // 获取主交易线段数组（通过索引访问）
   CZigzagSegment* GetMainTradingSegment(int index)
     {
      if(index >= 0 && index < ArraySize(m_mainTradingSegments))
         return m_mainTradingSegments[index];
      return NULL;
     }
     
   // 获取主交易线段数组大小
   int GetMainTradingSegmentsCount()
     {
      return ArraySize(m_mainTradingSegments);
     }
     
   // 获取最新的主交易线段
   CZigzagSegment* GetLatestMainTradingSegment()
     {
      if(ArraySize(m_mainTradingSegments) > 0)
         return m_mainTradingSegments[0];
      return NULL;
     }
     
   // 公共方法：按结束时间降序排列线段（最近的在前）
   void SortSegmentsByTimeDesc()
     {
      // 直接调用统一的排序方法：使用结束时间，降序排列
      ::SortSegmentsByTime(m_mainTradingSegments, false, true);
      
      // 排序后更新当前线段指针
      int segmentCount = ArraySize(m_mainTradingSegments);
      m_currentSegment = (segmentCount > 0) ? m_mainTradingSegments[0] : NULL;
     }
     
   // 从4H周期极值点数组初始化主交易线段
   bool InitializeMainSegmentsFromPoints(CZigzagExtremumPoint &points[])
     {
      if(ArraySize(points) < 2)
         return false;
      
      // 清理旧的线段
      for(int i = 0; i < ArraySize(m_mainTradingSegments); i++)
        {
         if(m_mainTradingSegments[i] != NULL)
           {
            delete m_mainTradingSegments[i];
            m_mainTradingSegments[i] = NULL;
           }
        }
   
   // 根据极值点数量创建多个线段
   int segmentCount = ArraySize(points) - 1;
   ArrayResize(m_mainTradingSegments, segmentCount);
   
   // 创建所有可能的线段
   for(int i = 0; i < segmentCount; i++)
     {
      // 确保线段的时间顺序正确：起点时间应该早于终点时间
      CZigzagExtremumPoint startPoint, endPoint;
      
      if(points[i].Time() < points[i+1].Time())
        {
         // points[i]时间更早，作为起点
         startPoint = points[i];
         endPoint = points[i+1];
        }
      else
        {
         // points[i+1]时间更早，作为起点
         startPoint = points[i+1];
         endPoint = points[i];
        }
      
      m_mainTradingSegments[i] = new CZigzagSegment(startPoint, endPoint);
     }
   
   // 按时间排序，最近的线段排在前面（自动更新当前线段指针）
   SortSegmentsByTimeDesc();
   
   m_isValid = true;
   return true;
  }
     
   // 获取指定时间周期的支撑/压力描述
   string GetSupportResistanceDescription(ENUM_TIMEFRAMES timeframe = PERIOD_H1, string prefix = "")
     {
      if(!m_isValid || m_currentSegment == NULL)
         return "";
         
      if((*m_currentSegment).IsUptrend())
        {
         // 上涨趋势，显示支撑位
         string supportText = DoubleToString(m_supportPoints.GetPrice(timeframe), _Digits);
         if(timeframe == PERIOD_H1 && prefix == "")
           {
            string referenceText = DoubleToString(GetRangeHigh(), _Digits);
            return "支撑：参考点" + referenceText;
           }
         else
           {
            string tfName = (timeframe == PERIOD_H1) ? "H1" : 
                           (timeframe == PERIOD_H4) ? "4H" : 
                           (timeframe == PERIOD_D1) ? "D1" : "未知";
            return prefix + tfName + "=" + supportText;
           }
        }
      else
        {
         // 下跌趋势，显示压力位
         string resistanceText = DoubleToString(m_resistancePoints.GetPrice(timeframe), _Digits);
         if(timeframe == PERIOD_H1 && prefix == "")
           {
            string referenceText = DoubleToString(GetRangeLow(), _Digits);
            return "压力：参考点" + referenceText;
           }
         else
           {
            string tfName = (timeframe == PERIOD_H1) ? "H1" : 
                           (timeframe == PERIOD_H4) ? "4H" : 
                           (timeframe == PERIOD_D1) ? "D1" : "未知";
            return prefix + tfName + "=" + resistanceText;
           }
        }
     }
     
   // 以下方法保留以兼容现有代码
   string GetSupportResistance4HDescription()
     {
      return GetSupportResistanceDescription(PERIOD_H4);
     }
     
   string GetSupportResistanceD1Description()
     {
      return GetSupportResistanceDescription(PERIOD_D1);
     }
     
   // 获取回撤或反弹价格
   double GetRetracePrice()
     {
      return m_retracePrice;
     }
     
   // 获取回撤或反弹时间
   datetime GetRetraceTime()
     {
      return m_retraceTime;
     }
     
   // 获取回撤或反弹百分比
   double GetRetracePercent()
     {
      return m_retracePercent;
     }
     
   // 获取回撤或反弹绝对值差距
   double GetRetraceDiff()
     {
      return m_retraceDiff;
     }
     
   // 获取回撤或反弹描述
   string GetRetraceDescription()
     {
      if(!m_isValid || m_currentSegment == NULL)
         return "";
         
      string retraceType = (*m_currentSegment).IsUptrend() ? "回撤" : "反弹";
      string priceText = DoubleToString(m_retracePrice, _Digits);
      string diffText = DoubleToString(m_retraceDiff, _Digits);
      string percentText = DoubleToString(m_retracePercent, 2);
      
      return StringFormat("%s: %s (%s点, %s%%)", 
                         retraceType, priceText, diffText, percentText);
     }
     
   // 获取主交易线段（最新的）
   CZigzagSegment GetMainTradingSegment()
     {
      if(m_currentSegment != NULL)
         return *m_currentSegment;
      else
         return CZigzagSegment(); // 返回空线段
     }
     
   // 获取区间高点
   double GetRangeHigh()
     {
      if(m_currentSegment != NULL)
        {
         return (*m_currentSegment).IsUptrend() ? (*m_currentSegment).EndPrice() : (*m_currentSegment).StartPrice();
        }
      return 0.0;
     }
     
   // 获取区间低点
   double GetRangeLow()
     {
      if(m_currentSegment != NULL)
        {
         return (*m_currentSegment).IsUptrend() ? (*m_currentSegment).StartPrice() : (*m_currentSegment).EndPrice();
        }
      return 0.0;
     }
     
   // 获取区间高点时间
   datetime GetRangeHighTime()
     {
      if(m_currentSegment != NULL)
        {
         return (*m_currentSegment).IsUptrend() ? (*m_currentSegment).EndTime() : (*m_currentSegment).StartTime();
        }
      return 0;
     }
     
   // 获取区间低点时间
   datetime GetRangeLowTime()
     {
      if(m_currentSegment != NULL)
        {
         return (*m_currentSegment).IsUptrend() ? (*m_currentSegment).StartTime() : (*m_currentSegment).EndTime();
        }
      return 0;
     }
     
   // 获取趋势方向
   bool IsUpTrend()
     {
      if(m_currentSegment != NULL)
         return (*m_currentSegment).IsUptrend();
      return false;
     }
     
   // 获取趋势方向描述
   string GetTrendDirection()
     {
      if(m_currentSegment != NULL)
         return (*m_currentSegment).IsUptrend() ? "上涨" : "下跌";
      return "未知";
     }
     
   // 检查数据是否有效
   bool IsValid()
     {
      return m_isValid;
     }
     
   // 获取区间分析结果的文本描述
   string GetRangeAnalysisText(double currentPrice)
     {
      if(!m_isValid || m_currentSegment == NULL)
         return "区间数据无效";
         
      string direction = GetTrendDirection();
      string highText = DoubleToString(GetRangeHigh(), _Digits);
      string lowText = DoubleToString(GetRangeLow(), _Digits);
      
      // 根据趋势方向调整显示顺序
      if((*m_currentSegment).IsUptrend())
        {
         // 上涨趋势，显示从低到高
         return StringFormat("区间: %s - %s (%s)", 
                           lowText, highText, direction);
        }
      else
        {
         // 下跌趋势，显示从高到低
         return StringFormat("区间: %s - %s (%s)", 
                           highText, lowText, direction);
        }
     }
     
   // 获取当前价格
   double GetCurrentPrice()
     {
      double price = 0.0;
      
      // 获取当前品种的最新价格
      MqlTick last_tick;
      if(SymbolInfoTick(Symbol(), last_tick))
        {
         // 使用最后成交价作为当前价格
         price = last_tick.last;
         
         // 如果最后成交价为0，则使用买卖价的中间价
         if(price == 0)
           {
            price = (last_tick.bid + last_tick.ask) / 2.0;
           }
        }
      
      return price;
     }
     
   // 在1分钟K线上查找反弹高点 - 使用CommonUtils中的通用函数
   double FindReboundHighOnM1(int lowestBarIndex, datetime &highTime)
     {
      // 检查参数
      if(lowestBarIndex < 0)
        {
         highTime = 0;
         return 0.0;
        }
        
      // 获取当前周期的最低点时间
      datetime lowestTime = iTime(Symbol(), Period(), lowestBarIndex);
      
      // 获取1分钟周期上的最低价
      double lowestPrice = iLow(Symbol(), PERIOD_M1, iBarShift(Symbol(), PERIOD_M1, lowestTime));
      
      // 使用通用函数查找最高价格
      return FindHighestPriceAfterLowPrice(lowestPrice, highTime, PERIOD_CURRENT, PERIOD_M1, lowestTime);
     }
  };

