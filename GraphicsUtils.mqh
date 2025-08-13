//+------------------------------------------------------------------+
//|                                                GraphicsUtils.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

//+------------------------------------------------------------------+
//| 图形工具类 - 用于绘制各种图形元素                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 标签管理静态类                                                   |
//+------------------------------------------------------------------+
class CLabelManager
  {
private:
   // 默认标签属性
   static string  DefaultFont;
   static int     DefaultFontSize;
   static color   DefaultColor;
   static int     DefaultWidth;
   static bool    DefaultSelectable;

public:
   // 初始化静态变量
   static void Init(color labelColor = clrWhite)
     {
      DefaultFont = "Arial";
      DefaultFontSize = 8;
      DefaultColor = labelColor;
      DefaultWidth = 1;
      DefaultSelectable = false;
     }
     
   // 创建文本标签的方法
   static void CreateTextLabel(string name, string text, datetime time, double price, bool isPeak, 
                              color textColor = NULL, string font = NULL, int fontSize = 0)
     {
      // 使用默认值或传入的参数
      color actualColor = (textColor == NULL) ? DefaultColor : textColor;
      string actualFont = (font == NULL) ? DefaultFont : font;
      int actualFontSize = (fontSize == 0) ? DefaultFontSize : fontSize;
      
      // 删除可能存在的同名对象
      ObjectDelete(0, name);
      
      // 创建文本标签
      ObjectCreate(0, name, OBJ_TEXT, 0, time, price);
      
      // 设置标签属性
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetString(0, name, OBJPROP_FONT, actualFont);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, actualFontSize);
      ObjectSetInteger(0, name, OBJPROP_COLOR, actualColor);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, DefaultWidth);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, DefaultSelectable);
      
      // 设置标签位置（峰值点在上方，谷值点在下方）
      if(isPeak)
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
      else
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_TOP);
     }
     
   // 删除指定前缀的所有标签
   static void DeleteAllLabels(string prefix)
     {
      ObjectsDeleteAll(0, prefix);
     }
  };

// 初始化静态成员变量
string CLabelManager::DefaultFont = "Arial";
int CLabelManager::DefaultFontSize = 8;
color CLabelManager::DefaultColor = clrWhite;
int CLabelManager::DefaultWidth = 1;
bool CLabelManager::DefaultSelectable = false;

//+------------------------------------------------------------------+
//| 线条绘制静态类                                                   |
//+------------------------------------------------------------------+
class CLineManager
  {
private:
   // 默认线条属性
   static color   DefaultColor;
   static int     DefaultWidth;
   static int     DefaultStyle;
   static bool    DefaultRayLeft;
   static bool    DefaultRayRight;
   static bool    DefaultSelectable;

public:
   // 初始化静态变量
   static void Init(color lineColor = clrRed)
     {
      DefaultColor = lineColor;
      DefaultWidth = 1;
      DefaultStyle = STYLE_SOLID;
      DefaultRayLeft = false;
      DefaultRayRight = false;
      DefaultSelectable = false;
     }
     
   // 创建趋势线
   static void CreateTrendLine(string name, datetime time1, double price1, 
                              datetime time2, double price2, 
                              color lineColor = NULL, int width = 0, int style = -1)
     {
      // 使用默认值或传入的参数
      color actualColor = (lineColor == NULL) ? DefaultColor : lineColor;
      int actualWidth = (width == 0) ? DefaultWidth : width;
      int actualStyle = (style == -1) ? DefaultStyle : style;
      
      // 删除可能存在的同名对象
      ObjectDelete(0, name);
      
      // 创建趋势线
      ObjectCreate(0, name, OBJ_TREND, 0, time1, price1, time2, price2);
      
      // 设置线条属性
      ObjectSetInteger(0, name, OBJPROP_COLOR, actualColor);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, actualWidth);
      ObjectSetInteger(0, name, OBJPROP_STYLE, actualStyle);
      ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, DefaultRayLeft);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, DefaultRayRight);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, DefaultSelectable);
     }
     
   // 删除指定前缀的所有线条
   static void DeleteAllLines(string prefix)
     {
      ObjectsDeleteAll(0, prefix, OBJ_TREND);
     }
  };

// 初始化静态成员变量
color CLineManager::DefaultColor = clrRed;
int CLineManager::DefaultWidth = 1;
int CLineManager::DefaultStyle = STYLE_SOLID;
bool CLineManager::DefaultRayLeft = false;
bool CLineManager::DefaultRayRight = false;
bool CLineManager::DefaultSelectable = false;

//+------------------------------------------------------------------+
//| 图形绘制静态类                                                   |
//+------------------------------------------------------------------+
class CShapeManager
  {
private:
   // 默认图形属性
   static color   DefaultBorderColor;
   static color   DefaultFillColor;
   static int     DefaultWidth;
   static int     DefaultStyle;
   static bool    DefaultSelectable;

public:
   // 初始化静态变量
   static void Init(color borderColor = clrBlue, color fillColor = clrAliceBlue)
     {
      DefaultBorderColor = borderColor;
      DefaultFillColor = fillColor;
      DefaultWidth = 1;
      DefaultStyle = STYLE_SOLID;
      DefaultSelectable = false;
     }
     
   // 创建矩形
   static void CreateRectangle(string name, datetime time1, double price1, 
                              datetime time2, double price2, 
                              color borderColor = NULL, color fillColor = NULL, 
                              int width = 0, int style = -1)
     {
      // 使用默认值或传入的参数
      color actualBorderColor = (borderColor == NULL) ? DefaultBorderColor : borderColor;
      color actualFillColor = (fillColor == NULL) ? DefaultFillColor : fillColor;
      int actualWidth = (width == 0) ? DefaultWidth : width;
      int actualStyle = (style == -1) ? DefaultStyle : style;
      
      // 删除可能存在的同名对象
      ObjectDelete(0, name);
      
      // 创建矩形
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, price1, time2, price2);
      
      // 设置矩形属性
      ObjectSetInteger(0, name, OBJPROP_COLOR, actualBorderColor);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, actualFillColor);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, actualWidth);
      ObjectSetInteger(0, name, OBJPROP_STYLE, actualStyle);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, DefaultSelectable);
     }
     
   // 创建三角形
   static void CreateTriangle(string name, datetime time1, double price1, 
                             datetime time2, double price2, 
                             datetime time3, double price3,
                             color borderColor = NULL, color fillColor = NULL, 
                             int width = 0, int style = -1)
     {
      // 使用默认值或传入的参数
      color actualBorderColor = (borderColor == NULL) ? DefaultBorderColor : borderColor;
      color actualFillColor = (fillColor == NULL) ? DefaultFillColor : fillColor;
      int actualWidth = (width == 0) ? DefaultWidth : width;
      int actualStyle = (style == -1) ? DefaultStyle : style;
      
      // 删除可能存在的同名对象
      ObjectDelete(0, name);
      
      // 创建三角形
      ObjectCreate(0, name, OBJ_TRIANGLE, 0, time1, price1, time2, price2, time3, price3);
      
      // 设置三角形属性
      ObjectSetInteger(0, name, OBJPROP_COLOR, actualBorderColor);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, actualFillColor);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, actualWidth);
      ObjectSetInteger(0, name, OBJPROP_STYLE, actualStyle);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, DefaultSelectable);
     }
     
   // 删除指定前缀的所有图形
   static void DeleteAllShapes(string prefix)
     {
      ObjectsDeleteAll(0, prefix, OBJ_RECTANGLE);
      ObjectsDeleteAll(0, prefix, OBJ_TRIANGLE);
      ObjectsDeleteAll(0, prefix, OBJ_ELLIPSE);
     }
  };

// 初始化静态成员变量
color CShapeManager::DefaultBorderColor = clrBlue;
color CShapeManager::DefaultFillColor = clrAliceBlue;
int CShapeManager::DefaultWidth = 1;
int CShapeManager::DefaultStyle = STYLE_SOLID;
bool CShapeManager::DefaultSelectable = false;