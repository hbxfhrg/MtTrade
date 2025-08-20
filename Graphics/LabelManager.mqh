//+------------------------------------------------------------------+
//|                                                 LabelManager.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

// 全局变量 - 标签管理器默认属性
string  g_LabelFont = "Arial";
int     g_LabelFontSize = 8;
color   g_LabelColor = clrWhite;      // 当前周期标签颜色(默认对应中周期)
color   g_Label4HColor = clrOrange;   // 4小时周期标签颜色(大周期)
int     g_LabelWidth = 1;
bool    g_LabelSelectable = false;

//+------------------------------------------------------------------+
//| 标签管理静态类                                                   |
//+------------------------------------------------------------------+
class CLabelManager
  {
public:
   // 初始化全局变量
   static void Init(color labelColor = clrWhite, color label4HColor = clrOrange)
     {
      g_LabelFont = "Arial";
      g_LabelFontSize = 8;
      g_LabelColor = labelColor;     // 当前周期(中周期)
      g_Label4HColor = label4HColor; // 大周期
      g_LabelWidth = 1;
      g_LabelSelectable = false;
     }
     
   // 创建文本标签的方法
   static void CreateTextLabel(string name, string text, datetime time, double price, bool isPeak, 
                              bool is4HPeriod = false, 
                              color textColor = NULL, string font = NULL, int fontSize = 0,
                              int xOffset = -10, bool centered = true, string tooltip = "")
     {
      // 使用默认值或传入的参数
      color actualColor;
      
      // 根据周期选择颜色
      if(textColor != NULL)
         actualColor = textColor;
      else if(is4HPeriod)  // 大周期
         actualColor = g_Label4HColor;
      else
         actualColor = g_LabelColor; // 当前周期(中周期)
         
      string actualFont = (font == NULL) ? g_LabelFont : font;
      int actualFontSize = (fontSize == 0) ? g_LabelFontSize : fontSize;
      
      // 删除可能存在的同名对象
      ObjectDelete(0, name);
      
      // 创建标签对象 - 使用OBJ_TEXT以保持正确的图表位置
      ObjectCreate(0, name, OBJ_TEXT, 0, time, price);
      
      // 如果提供了工具提示，则设置它
      if(tooltip != "")
        {
         // 为OBJ_TEXT对象设置工具提示
         ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
        }
      
      // 设置标签属性
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetString(0, name, OBJPROP_FONT, actualFont);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, actualFontSize);
      ObjectSetInteger(0, name, OBJPROP_COLOR, actualColor);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, g_LabelWidth);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, g_LabelSelectable);
      
      // 根据是峰值还是谷值设置不同的旋转角度
      if(isPeak)
         ObjectSetDouble(0, name, OBJPROP_ANGLE, 0);
      else
         ObjectSetDouble(0, name, OBJPROP_ANGLE, 0);

      // 设置标签位置和锚点
      if(centered)
      {
         // 居中显示
         if(isPeak)
            ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LOWER);
         else
            ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_UPPER);
      }
      else
      {
         // 非居中显示，使用左侧锚点
         if(isPeak)
            ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
         else
            ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      }
      
      // 设置X轴偏移量
      ObjectSetInteger(0, name, OBJPROP_XOFFSET, xOffset);
     }
     
   // 删除指定前缀的所有标签
   static void DeleteAllLabels(string prefix)
     {
      ObjectsDeleteAll(0, prefix);
     }
  };