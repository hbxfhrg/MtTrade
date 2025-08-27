//+------------------------------------------------------------------+
//|                                                  LineManager.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

// 全局变量 - 线条管理器默认属性
color   g_LineColor = clrRed;
int     g_LineWidth = 1;
int     g_LineStyle = STYLE_SOLID;
bool    g_LineRayLeft = false;
bool    g_LineRayRight = false;
bool    g_LineSelectable = false;

// 防闪烁机制的全局变量
long g_LastUpdateTime = 0;       // 上次更新时间(毫秒)
int      g_UpdateThrottle = 500;     // 更新节流时间(毫秒)

//+------------------------------------------------------------------+
//| 线条绘制静态类                                                   |
//+------------------------------------------------------------------+
class CLineManager
  {
public:
   // 初始化全局变量
   static void Init(color lineColor = clrRed)
     {
      g_LineColor = lineColor;
      g_LineWidth = 1;
      g_LineStyle = STYLE_SOLID;
      g_LineRayLeft = false;
      g_LineRayRight = false;
      g_LineSelectable = false;
     }
     
   // 创建趋势线
   static void CreateTrendLine(string name, datetime time1, double price1, 
                              datetime time2, double price2, 
                              color lineColor = NULL, int width = 0, int style = -1)
     {
      // 获取当前时间(毫秒)
      long currentTimeMs = GetTickCount();
      
      // 检查是否需要更新 - 如果距离上次更新时间不足阈值，则跳过更新
      if(currentTimeMs - g_LastUpdateTime < g_UpdateThrottle)
        {
         // 时间间隔太短，跳过此次更新以防止闪烁
         return;
        }
      
      // 使用默认值或传入的参数
      color actualColor = (lineColor == NULL) ? g_LineColor : lineColor;
      int actualWidth = (width == 0) ? g_LineWidth : width;
      int actualStyle = (style == -1) ? g_LineStyle : style;
      
      // 检查对象是否已存在
      if(ObjectFind(0, name) >= 0)
        {
         // 对象已存在，检查是否需要更新
         datetime existingTime1 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 0);
         datetime existingTime2 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 1);
         double existingPrice1 = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
         double existingPrice2 = ObjectGetDouble(0, name, OBJPROP_PRICE, 1);
         
         // 计算价格变化的百分比
         double priceDiff1 = 0, priceDiff2 = 0;
         if(existingPrice1 != 0) priceDiff1 = MathAbs((price1 - existingPrice1) / existingPrice1);
         if(existingPrice2 != 0) priceDiff2 = MathAbs((price2 - existingPrice2) / existingPrice2);
         
         // 如果时间相同且价格变化很小(小于0.01%)，只更新样式属性，不重新创建对象
         if(existingTime1 == time1 && existingTime2 == time2 && 
            priceDiff1 < 0.0001 && priceDiff2 < 0.0001)
           {
            // 只更新样式属性
            ObjectSetInteger(0, name, OBJPROP_COLOR, actualColor);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, actualWidth);
            ObjectSetInteger(0, name, OBJPROP_STYLE, actualStyle);
            return; // 不需要重新创建对象
           }
         
         // 如果价格变化较大，则更新价格点但不删除重建对象
         if(existingTime1 == time1 && existingTime2 == time2)
           {
            // 直接修改价格点
            ObjectMove(0, name, 0, time1, price1);
            ObjectMove(0, name, 1, time2, price2);
            
            // 更新样式属性
            ObjectSetInteger(0, name, OBJPROP_COLOR, actualColor);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, actualWidth);
            ObjectSetInteger(0, name, OBJPROP_STYLE, actualStyle);
            
            // 更新最后更新时间
            g_LastUpdateTime = currentTimeMs;
            return;
           }
         
         // 如果时间点发生变化，删除旧对象并创建新对象
         ObjectDelete(0, name);
        }
      
      // 创建趋势线
      if(!ObjectCreate(0, name, OBJ_TREND, 0, time1, price1, time2, price2))
        {
         // 创建失败，可能是因为对象已存在但Find没有找到
         // 尝试删除可能存在的同名对象后重试
         ObjectDelete(0, name);
         ObjectCreate(0, name, OBJ_TREND, 0, time1, price1, time2, price2);
        }
      
      // 设置线条属性
      ObjectSetInteger(0, name, OBJPROP_COLOR, actualColor);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, actualWidth);
      ObjectSetInteger(0, name, OBJPROP_STYLE, actualStyle);
      ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, g_LineRayLeft);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, g_LineRayRight);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, g_LineSelectable);
      ObjectSetInteger(0, name, OBJPROP_BACK, false); // 确保线条在前景显示
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 1); // 设置Z顺序
      
      // 更新最后更新时间
      g_LastUpdateTime = currentTimeMs;
     }
     
   // 删除指定前缀的所有线条
   static void DeleteAllLines(string prefix)
     {
      ObjectsDeleteAll(0, prefix, OBJ_TREND);
     }
  };