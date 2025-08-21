//+------------------------------------------------------------------+
//|                                              EnumDefinitions.mqh |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

//+------------------------------------------------------------------+
//| 公用枚举类型定义文件 - 集中管理所有枚举类型                        |
//+------------------------------------------------------------------+

// 定义支撑压力点类型枚举
enum ENUM_SR_POINT_TYPE
  {
   SR_SUPPORT = 0,                // 普通支撑点
   SR_RESISTANCE = 1,             // 普通压力点
   SR_SUPPORT_RANGE_HIGH = 2,     // 区间高点支撑（上涨行情）
   SR_RESISTANCE_RETRACE = 3,     // 回撤点压力（上涨行情）
   SR_RESISTANCE_RANGE_LOW = 4,   // 区间低点压力（下跌行情）
   SR_SUPPORT_REBOUND = 5         // 反弹点支撑（下跌行情）
  };

// 定义交易方向枚举
enum ENUM_TRADE_DIRECTION
  {
   TRADE_DIRECTION_BUY = 0,     // 买入
   TRADE_DIRECTION_SELL = 1     // 卖出
  };

// 定义交易状态枚举
enum ENUM_TRADE_STATUS
  {
   TRADE_STATUS_PENDING = 0,    // 挂单中
   TRADE_STATUS_OPEN = 1,       // 已开仓
   TRADE_STATUS_CLOSED = 2,     // 已平仓
   TRADE_STATUS_CANCELED = 3    // 已取消
  };

// 定义时间周期描述枚举
enum ENUM_TIMEFRAME
  {
   M1 = PERIOD_M1,    // 1分钟
   M5 = PERIOD_M5,    // 5分钟
   M15 = PERIOD_M15,  // 15分钟
   M30 = PERIOD_M30,  // 30分钟
   H1 = PERIOD_H1,    // 1小时
   H4 = PERIOD_H4,    // 4小时
   D1 = PERIOD_D1,    // 日线
   W1 = PERIOD_W1,    // 周线
   MN = PERIOD_MN1    // 月线
  };

// 定义价格类型枚举
enum ENUM_PRICE_TYPE
  {
   PRICE_TYPE_OPEN = 0,         // 开盘价
   PRICE_TYPE_HIGH = 1,         // 最高价
   PRICE_TYPE_LOW = 2,          // 最低价
   PRICE_TYPE_CLOSE = 3,        // 收盘价
   PRICE_TYPE_MEDIAN = 4,       // 中间价 (High+Low)/2
   PRICE_TYPE_TYPICAL = 5,      // 典型价 (High+Low+Close)/3
   PRICE_TYPE_WEIGHTED = 6      // 加权价 (High+Low+Close+Close)/4
  };

// 注意：TimeframeToString 函数已在 CommonUtils.mqh 中定义
