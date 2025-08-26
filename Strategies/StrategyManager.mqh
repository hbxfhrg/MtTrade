//+------------------------------------------------------------------+
//|                                             StrategyManager.mqh |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023"
#property link      ""

#include "HighPositionStrategy.mqh"
#include "MidPositionStrategy.mqh"
#include "LowPositionStrategy.mqh"
#include "../EnumDefinitions.mqh"
#include "../ZigzagExtremumPoint.mqh"
#include "../ZigzagSegment.mqh"

//+------------------------------------------------------------------+
//| 策略管理器类 - 用于统一管理不同位置的交易策略                      |
//+------------------------------------------------------------------+
class CStrategyManager
  {
private:
   // 策略对象
   CHighPositionStrategy *m_highStrategy;  // 高位策略
   CMidPositionStrategy  *m_midStrategy;   // 中位策略
   CLowPositionStrategy  *m_lowStrategy;   // 低位策略
   
   // 当前活跃策略
   ENUM_MARKET_POSITION m_activePositionType;  // 当前活跃的位置类型
   
public:
   // 构造函数
                     CStrategyManager();
   // 析构函数
                    ~CStrategyManager();
   
   // 初始化策略
   bool              Init(double highStopLoss = 100.0, double highTakeProfit = 200.0,
                          double midStopLoss = 80.0, double midTakeProfit = 160.0,
                          double lowStopLoss = 120.0, double lowTakeProfit = 240.0,
                          int maxBars = 200);
   
   // 分析市场位置
   ENUM_MARKET_POSITION AnalyzeMarketPosition(CZigzagExtremumPoint &points[], int pointCount);
   
   // 检查进场条件
   bool              CheckEntryCondition(CZigzagExtremumPoint &points[], int pointCount);
   
   // 开始监控进场价格
   bool              StartEntryPriceMonitoring(double entryPrice, ENUM_TRADE_TYPE tradeType);
   
   // 停止监控进场价格
   void              StopEntryPriceMonitoring();
   
   // 检查是否达到进场价格
   bool              CheckEntryPriceReached(double currentPrice);
   
   // 开始监控出场价格
   bool              StartExitPriceMonitoring(double exitPrice);
   
   // 停止监控出场价格
   void              StopExitPriceMonitoring();
   
   // 检查是否达到出场价格(止盈/止损)
   bool              CheckExitPriceReached(double currentPrice);
   
   // 获取当前活跃的位置类型
   ENUM_MARKET_POSITION GetActivePositionType() const { return m_activePositionType; }
   
   // 获取当前交易状态
   bool              IsMonitoring() const;
   double            GetEntryPrice() const;
   double            GetExitPrice() const;
   ENUM_TRADE_TYPE   GetTradeType() const;
   
   // 获取当前策略描述
   string            GetPositionTypeDescription() const;
   string            GetStrategyDescription() const;
   
   // 静态方法 - 用于InfoPanel显示
   static string     GetPositionTypeDescription();
   static string     GetStrategyDescription();
  };

//+------------------------------------------------------------------+
//| 构造函数                                                          |
//+------------------------------------------------------------------+
CStrategyManager::CStrategyManager()
  {
   m_highStrategy = NULL;
   m_midStrategy = NULL;
   m_lowStrategy = NULL;
   m_activePositionType = POSITION_TYPE_NONE;
  }

//+------------------------------------------------------------------+
//| 析构函数                                                          |
//+------------------------------------------------------------------+
CStrategyManager::~CStrategyManager()
  {
   // 释放策略对象
   if(m_highStrategy != NULL)
     {
      delete m_highStrategy;
      m_highStrategy = NULL;
     }
     
   if(m_midStrategy != NULL)
     {
      delete m_midStrategy;
      m_midStrategy = NULL;
     }
     
   if(m_lowStrategy != NULL)
     {
      delete m_lowStrategy;
      m_lowStrategy = NULL;
     }
  }

//+------------------------------------------------------------------+
//| 初始化策略                                                        |
//+------------------------------------------------------------------+
bool CStrategyManager::Init(double highStopLoss = 100.0, double highTakeProfit = 200.0,
                          double midStopLoss = 80.0, double midTakeProfit = 160.0,
                          double lowStopLoss = 120.0, double lowTakeProfit = 240.0,
                          int maxBars = 200)
  {
   // 创建策略对象
   m_highStrategy = new CHighPositionStrategy(highStopLoss, highTakeProfit, maxBars);
   m_midStrategy = new CMidPositionStrategy(midStopLoss, midTakeProfit, maxBars);
   m_lowStrategy = new CLowPositionStrategy(lowStopLoss, lowTakeProfit, maxBars);
   
   // 检查是否创建成功
   if(m_highStrategy == NULL || m_midStrategy == NULL || m_lowStrategy == NULL)
     {
      // 释放已创建的对象
      if(m_highStrategy != NULL)
        {
         delete m_highStrategy;
         m_highStrategy = NULL;
        }
        
      if(m_midStrategy != NULL)
        {
         delete m_midStrategy;
         m_midStrategy = NULL;
        }
        
      if(m_lowStrategy != NULL)
        {
         delete m_lowStrategy;
         m_lowStrategy = NULL;
        }
        
      return false;
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| 分析市场位置                                                      |
//+------------------------------------------------------------------+
ENUM_MARKET_POSITION CStrategyManager::AnalyzeMarketPosition(CZigzagExtremumPoint &points[], int pointCount)
  {
   // 首先使用TradeAnalyzer分析市场区间和趋势
   if(!g_tradeAnalyzer.AnalyzeRange(points, pointCount))
      return POSITION_TYPE_NONE;
      
   // 获取回撤或反弹百分比
   double retracePercent = g_tradeAnalyzer.GetRetracePercent();
   
   // 根据回撤或反弹百分比确定市场位置
   if(retracePercent >= 0.0 && retracePercent <= 33.3)
      return POSITION_TYPE_HIGH;
   else if(retracePercent > 33.3 && retracePercent <= 66.6)
      return POSITION_TYPE_MID;
   else if(retracePercent > 66.6 && retracePercent <= 100.0)
      return POSITION_TYPE_LOW;
   else
      return POSITION_TYPE_NONE;
  }

//+------------------------------------------------------------------+
//| 检查进场条件                                                      |
//+------------------------------------------------------------------+
bool CStrategyManager::CheckEntryCondition(CZigzagExtremumPoint &points[], int pointCount)
  {
   // 首先分析市场位置
   m_activePositionType = AnalyzeMarketPosition(points, pointCount);
   
   // 根据市场位置选择对应的策略
   switch(m_activePositionType)
     {
      case POSITION_TYPE_HIGH:
         return m_highStrategy != NULL ? m_highStrategy.CheckEntryCondition(points, pointCount) : false;
         
      case POSITION_TYPE_MID:
         return m_midStrategy != NULL ? m_midStrategy.CheckEntryCondition(points, pointCount) : false;
         
      case POSITION_TYPE_LOW:
         return m_lowStrategy != NULL ? m_lowStrategy.CheckEntryCondition(points, pointCount) : false;
         
      default:
         return false;
     }
  }

//+------------------------------------------------------------------+
//| 开始监控进场价格                                                  |
//+------------------------------------------------------------------+
bool CStrategyManager::StartEntryPriceMonitoring(double entryPrice, ENUM_TRADE_TYPE tradeType)
  {
   // 根据市场位置选择对应的策略
   switch(m_activePositionType)
     {
      case POSITION_TYPE_HIGH:
         return m_highStrategy != NULL ? m_highStrategy.StartEntryPriceMonitoring(entryPrice, tradeType) : false;
         
      case POSITION_TYPE_MID:
         return m_midStrategy != NULL ? m_midStrategy.StartEntryPriceMonitoring(entryPrice, tradeType) : false;
         
      case POSITION_TYPE_LOW:
         return m_lowStrategy != NULL ? m_lowStrategy.StartEntryPriceMonitoring(entryPrice, tradeType) : false;
         
      default:
         return false;
     }
  }

//+------------------------------------------------------------------+
//| 停止监控进场价格                                                  |
//+------------------------------------------------------------------+
void CStrategyManager::StopEntryPriceMonitoring()
  {
   // 根据市场位置选择对应的策略
   switch(m_activePositionType)
     {
      case POSITION_TYPE_HIGH:
         if(m_highStrategy != NULL) m_highStrategy.StopEntryPriceMonitoring();
         break;
         
      case POSITION_TYPE_MID:
         if(m_midStrategy != NULL) m_midStrategy.StopEntryPriceMonitoring();
         break;
         
      case POSITION_TYPE_LOW:
         if(m_lowStrategy != NULL) m_lowStrategy.StopEntryPriceMonitoring();
         break;
     }
  }

//+------------------------------------------------------------------+
//| 检查是否达到进场价格                                              |
//+------------------------------------------------------------------+
bool CStrategyManager::CheckEntryPriceReached(double currentPrice)
  {
   // 根据市场位置选择对应的策略
   switch(m_activePositionType)
     {
      case POSITION_TYPE_HIGH:
         return m_highStrategy != NULL ? m_highStrategy.CheckEntryPriceReached(currentPrice) : false;
         
      case POSITION_TYPE_MID:
         return m_midStrategy != NULL ? m_midStrategy.CheckEntryPriceReached(currentPrice) : false;
         
      case POSITION_TYPE_LOW:
         return m_lowStrategy != NULL ? m_lowStrategy.CheckEntryPriceReached(currentPrice) : false;
         
      default:
         return false;
     }
  }

//+------------------------------------------------------------------+
//| 开始监控出场价格                                                  |
//+------------------------------------------------------------------+
bool CStrategyManager::StartExitPriceMonitoring(double exitPrice)
  {
   // 根据市场位置选择对应的策略
   switch(m_activePositionType)
     {
      case POSITION_TYPE_HIGH:
         return m_highStrategy != NULL ? m_highStrategy.StartExitPriceMonitoring(exitPrice) : false;
         
      case POSITION_TYPE_MID:
         return m_midStrategy != NULL ? m_midStrategy.StartExitPriceMonitoring(exitPrice) : false;
         
      case POSITION_TYPE_LOW:
         return m_lowStrategy != NULL ? m_lowStrategy.StartExitPriceMonitoring(exitPrice) : false;
         
      default:
         return false;
     }
  }

//+------------------------------------------------------------------+
//| 停止监控出场价格                                                  |
//+------------------------------------------------------------------+
void CStrategyManager::StopExitPriceMonitoring()
  {
   // 根据市场位置选择对应的策略
   switch(m_activePositionType)
     {
      case POSITION_TYPE_HIGH:
         if(m_highStrategy != NULL) m_highStrategy.StopExitPriceMonitoring();
         break;
         
      case POSITION_TYPE_MID:
         if(m_midStrategy != NULL) m_midStrategy.StopExitPriceMonitoring();
         break;
         
      case POSITION_TYPE_LOW:
         if(m_lowStrategy != NULL) m_lowStrategy.StopExitPriceMonitoring();
         break;
     }
  }

//+------------------------------------------------------------------+
//| 检查是否达到出场价格(止盈/止损)                                   |
//+------------------------------------------------------------------+
bool CStrategyManager::CheckExitPriceReached(double currentPrice)
  {
   // 根据市场位置选择对应的策略
   switch(m_activePositionType)
     {
      case POSITION_TYPE_HIGH:
         return m_highStrategy != NULL ? m_highStrategy.CheckExitPriceReached(currentPrice) : false;
         
      case POSITION_TYPE_MID:
         return m_midStrategy != NULL ? m_midStrategy.CheckExitPriceReached(currentPrice) : false;
         
      case POSITION_TYPE_LOW:
         return m_lowStrategy != NULL ? m_lowStrategy.CheckExitPriceReached(currentPrice) : false;
         
      default:
         return false;
     }
  }

//+------------------------------------------------------------------+
//| 获取当前是否正在监控价格                                          |
//+------------------------------------------------------------------+
bool CStrategyManager::IsMonitoring() const
  {
   // 根据市场位置选择对应的策略
   switch(m_activePositionType)
     {
      case POSITION_TYPE_HIGH:
         return m_highStrategy != NULL ? m_highStrategy.IsMonitoring() : false;
         
      case POSITION_TYPE_MID:
         return m_midStrategy != NULL ? m_midStrategy.IsMonitoring() : false;
         
      case POSITION_TYPE_LOW:
         return m_lowStrategy != NULL ? m_lowStrategy.IsMonitoring() : false;
         
      default:
         return false;
     }
  }

//+------------------------------------------------------------------+
//| 获取当前进场价格                                                  |
//+------------------------------------------------------------------+
double CStrategyManager::GetEntryPrice() const
  {
   // 根据市场位置选择对应的策略
   switch(m_activePositionType)
     {
      case POSITION_TYPE_HIGH:
         return m_highStrategy != NULL ? m_highStrategy.GetEntryPrice() : 0.0;
         
      case POSITION_TYPE_MID:
         return m_midStrategy != NULL ? m_midStrategy.GetEntryPrice() : 0.0;
         
      case POSITION_TYPE_LOW:
         return m_lowStrategy != NULL ? m_lowStrategy.GetEntryPrice() : 0.0;
         
      default:
         return 0.0;
     }
  }

//+------------------------------------------------------------------+
//| 获取当前出场价格                                                  |
//+------------------------------------------------------------------+
double CStrategyManager::GetExitPrice() const
  {
   // 根据市场位置选择对应的策略
   switch(m_activePositionType)
     {
      case POSITION_TYPE_HIGH:
         return m_highStrategy != NULL ? m_highStrategy.GetExitPrice() : 0.0;
         
      case POSITION_TYPE_MID:
         return m_midStrategy != NULL ? m_midStrategy.GetExitPrice() : 0.0;
         
      case POSITION_TYPE_LOW:
         return m_lowStrategy != NULL ? m_lowStrategy.GetExitPrice() : 0.0;
         
      default:
         return 0.0;
     }
  }

//+------------------------------------------------------------------+
//| 获取当前交易类型                                                  |
//+------------------------------------------------------------------+
ENUM_TRADE_TYPE CStrategyManager::GetTradeType() const
  {
   // 根据市场位置选择对应的策略
   switch(m_activePositionType)
     {
      case POSITION_TYPE_HIGH:
         return m_highStrategy != NULL ? m_highStrategy.GetTradeType() : TRADE_TYPE_NONE;
         
      case POSITION_TYPE_MID:
         return m_midStrategy != NULL ? m_midStrategy.GetTradeType() : TRADE_TYPE_NONE;
         
      case POSITION_TYPE_LOW:
         return m_lowStrategy != NULL ? m_lowStrategy.GetTradeType() : TRADE_TYPE_NONE;
         
      default:
         return TRADE_TYPE_NONE;
     }
  }

//+------------------------------------------------------------------+
//| 获取当前位置类型的描述                                            |
//+------------------------------------------------------------------+
string CStrategyManager::GetPositionTypeDescription() const
  {
   switch(m_activePositionType)
     {
      case POSITION_TYPE_HIGH:
         return "高位区间 (0%-33.3%)";
         
      case POSITION_TYPE_MID:
         return "中位区间 (33.3%-66.6%)";
         
      case POSITION_TYPE_LOW:
         return "低位区间 (66.6%-100%)";
         
      default:
         return "未确定区间";
     }
  }

//+------------------------------------------------------------------+
//| 获取当前策略的描述                                                |
//+------------------------------------------------------------------+
string CStrategyManager::GetStrategyDescription() const
  {
   ENUM_TRADE_TYPE tradeType = GetTradeType();
   string tradeDirection = (tradeType == TRADE_TYPE_BUY) ? "做多" : ((tradeType == TRADE_TYPE_SELL) ? "做空" : "无交易");
   
   switch(m_activePositionType)
     {
      case POSITION_TYPE_HIGH:
         return "高位策略: " + tradeDirection + " - 趋势跟随，适合价格波动较小的情况";
         
      case POSITION_TYPE_MID:
         return "中位策略: " + tradeDirection + " - 等待中等幅度回调/反弹后跟随趋势";
         
      case POSITION_TYPE_LOW:
         return "低位策略: " + tradeDirection + " - 等待深度回调/反弹后跟随趋势";
         
      default:
         return "无活跃策略";
     }
  }

//+------------------------------------------------------------------+
//| 静态方法 - 获取当前位置类型的描述                                 |
//+------------------------------------------------------------------+
string CStrategyManager::GetPositionTypeDescription()
  {
   // 这里我们需要一个全局变量来存储当前的位置类型
   // 由于静态方法无法访问实例变量，我们返回一个通用描述
   return "高位区间 (0%-33.3%): 回撤/反弹幅度在0%-33.3%之间\n"
          "中位区间 (33.3%-66.6%): 回撤/反弹幅度在33.3%-66.6%之间\n"
          "低位区间 (66.6%-100%): 回撤/反弹幅度在66.6%-100%之间";
  }

//+------------------------------------------------------------------+
//| 静态方法 - 获取当前策略的描述                                     |
//+------------------------------------------------------------------+
string CStrategyManager::GetStrategyDescription()
  {
   // 由于静态方法无法访问实例变量，我们返回一个通用描述
   return "高位策略: 趋势跟随，适合价格波动较小的情况\n"
          "中位策略: 等待中等幅度回调/反弹后跟随趋势\n"
          "低位策略: 等待深度回调/反弹后跟随趋势";
  }
//+------------------------------------------------------------------+
