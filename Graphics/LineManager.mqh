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
      // 使用默认值或传入的参数
      color actualColor = (lineColor == NULL) ? g_LineColor : lineColor;
      int actualWidth = (width == 0) ? g_LineWidth : width;
      int actualStyle = (style == -1) ? g_LineStyle : style;
      
      // 删除可能存在的同名对象
      ObjectDelete(0, name);
      
      // 创建趋势线
      ObjectCreate(0, name, OBJ_TREND, 0, time1, price1, time2, price2);
      
      // 设置线条属性
      ObjectSetInteger(0, name, OBJPROP_COLOR, actualColor);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, actualWidth);
      ObjectSetInteger(0, name, OBJPROP_STYLE, actualStyle);
      ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, g_LineRayLeft);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, g_LineRayRight);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, g_LineSelectable);
     }
     
   // 删除指定前缀的所有线条
   static void DeleteAllLines(string prefix)
     {
      ObjectsDeleteAll(0, prefix, OBJ_TREND);
     }
  };