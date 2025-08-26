//+------------------------------------------------------------------+
//|                                                 ShapeManager.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

// 引入交易分析类和全局实例
#include "../GlobalInstances.mqh"
#include "../DynamicPricePoint.mqh"

// 全局变量 - 图形管理器默认属性
color   g_ShapeBorderColor = clrBlue;
color   g_ShapeFillColor = clrAliceBlue;
int     g_ShapeWidth = 1;
int     g_ShapeStyle = STYLE_SOLID;
bool    g_ShapeSelectable = false;

//+------------------------------------------------------------------+
//| 图形绘制静态类                                                   |
//+------------------------------------------------------------------+
class CShapeManager
  {
private:
   // 设置矩形对象的属性
   static void SetRectangleProperties(string objectName, color borderColor, color fillColor, 
                                     int width = 2, ENUM_LINE_STYLE style = STYLE_SOLID, 
                                     int transparency = 80, bool selectable = false)
     {
      ObjectSetInteger(0, objectName, OBJPROP_COLOR, borderColor);
      // 使用带透明度的颜色
      color colorWithAlpha = (color)(fillColor & 0x00FFFFFF | (transparency << 24));
      ObjectSetInteger(0, objectName, OBJPROP_BGCOLOR, colorWithAlpha);
      ObjectSetInteger(0, objectName, OBJPROP_FILL, true);
      ObjectSetInteger(0, objectName, OBJPROP_WIDTH, width);
      ObjectSetInteger(0, objectName, OBJPROP_STYLE, style);
      ObjectSetInteger(0, objectName, OBJPROP_BACK, false);
      ObjectSetInteger(0, objectName, OBJPROP_SELECTABLE, selectable);
      ObjectSetInteger(0, objectName, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, objectName, OBJPROP_HIDDEN, false);
     }
     
   // 设置文本标签的属性
   static void SetTextProperties(string objectName, string text, color textColor, 
                               string font = "Arial", int fontSize = 9, 
                               ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_LOWER)
     {
      ObjectSetString(0, objectName, OBJPROP_TEXT, text);
      ObjectSetString(0, objectName, OBJPROP_FONT, font);
      ObjectSetInteger(0, objectName, OBJPROP_FONTSIZE, fontSize);
      ObjectSetInteger(0, objectName, OBJPROP_COLOR, textColor);
      ObjectSetInteger(0, objectName, OBJPROP_ANCHOR, anchor);
      ObjectSetInteger(0, objectName, OBJPROP_BACK, false);
      ObjectSetInteger(0, objectName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objectName, OBJPROP_HIDDEN, false);
      // 确保文本在前景显示
      ObjectSetInteger(0, objectName, OBJPROP_ZORDER, 100);
     }
     
   // 创建支撑/压力矩形和标签
   static void CreateSupportResistanceRect(string rectName, string labelName, datetime startTime, 
                                         datetime endTime, double price, double rectHeight, 
                                         color objectColor, string labelText, 
                                         ENUM_LINE_STYLE style = STYLE_SOLID, int transparency = 80)
     {
      // 创建矩形
      ObjectCreate(0, rectName, OBJ_RECTANGLE, 0, startTime, price + rectHeight/2, 
                  endTime, price - rectHeight/2);
      SetRectangleProperties(rectName, objectColor, objectColor, 2, style, transparency);
      
      // 添加标签
      ObjectCreate(0, labelName, OBJ_TEXT, 0, startTime, price + rectHeight);
      SetTextProperties(labelName, labelText, objectColor);
     }

public:
   // 初始化全局变量
   static void Init(color borderColor = clrBlue, color fillColor = clrAliceBlue)
     {
      g_ShapeBorderColor = borderColor;
      g_ShapeFillColor = fillColor;
      g_ShapeWidth = 1;
      g_ShapeStyle = STYLE_SOLID;
      g_ShapeSelectable = false;
     }
     
   // 绘制支撑或压力线（矩形显示）
   static void DrawSupportResistanceLines()
     {
      if(!g_tradeAnalyzer.IsValid())
         return;
         
      // 删除所有旧的图形对象
      ObjectsDeleteAll(0, "SR_");  // 删除所有以SR_开头的对象
      
      // 矩形高度（价格单位）
      double rectHeight = 800 * _Point; // 矩形高度为20个点，可以根据需要调整
      
      // 绘制回撤点或反弹点
      DrawRetraceReboundPoint();
     }
     
   // 绘制动态价格点（支撑/压力/回撤/反弹/区间高低点）
   static void DrawDynamicPricePoint(CDynamicPricePoint &pricePoint, double referencePrice, 
                                   double comparePrice, bool shouldDraw, 
                                   string baseName, color pointColor, 
                                   double retracePercent = 0.0)
     {
      if(!g_tradeAnalyzer.IsValid() || referencePrice <= 0)
         return;
         
      // 矩形高度（价格单位）
      double rectHeight = 600 * _Point; // 矩形高度为15个点
      
      // 获取点类型
      ENUM_SR_POINT_TYPE pointType = pricePoint.GetPointType();
      
      // 分离点的类型和作用
      string pointTypeDesc = ""; // 点的类型描述（区间高点、区间低点、回撤点、反弹点）
      string pointRoleDesc = ""; // 点的作用描述（支撑、压力）
      
      // 确定点的类型
      switch(pointType)
        {
         case SR_SUPPORT_RANGE_HIGH:
            pointTypeDesc = "区间高点";
            pointRoleDesc = "支撑";
            break;
         case SR_RESISTANCE_RETRACE:
            pointTypeDesc = "回撤点";
            pointRoleDesc = "压力";
            break;
         case SR_RESISTANCE_RANGE_LOW:
            pointTypeDesc = "区间低点";
            pointRoleDesc = "压力";
            break;
         case SR_SUPPORT_REBOUND:
            pointTypeDesc = "反弹点";
            pointRoleDesc = "支撑";
            break;
         case SR_SUPPORT:
            pointTypeDesc = "";
            pointRoleDesc = "支撑";
            break;
         case SR_RESISTANCE:
            pointTypeDesc = "";
            pointRoleDesc = "压力";
            break;
        }
      
      // 根据点类型选择基础颜色
      color baseColor;
      if(pointType == SR_SUPPORT || pointType == SR_SUPPORT_RANGE_HIGH || pointType == SR_SUPPORT_REBOUND)
        {
         // 支撑点使用蓝色系
         baseColor = clrDodgerBlue;
        }
      else
        {
         // 压力点使用红色系
         baseColor = clrCrimson;
        }
      
      // 定义需要绘制的时间周期数组
      ENUM_TIMEFRAMES timeframes[] = {PERIOD_H1, PERIOD_H4, PERIOD_D1};
      string timeframeNames[] = {"H1", "H4", "D1"};
      // 颜色由浅到深：H1最浅，D1最深
      color timeframeColors[] = {ColorBrighten(baseColor, 30), baseColor, ColorBrighten(baseColor, -30)};
      
      // 对每个时间周期进行绘制
      for(int i = 0; i < ArraySize(timeframes); i++)
        {
         // 获取当前时间周期的价格和时间
         double price = pricePoint.GetPrice(timeframes[i]);
         datetime time = pricePoint.GetTime(timeframes[i]);
         
         // 获取价格点对象
         CSupportResistancePoint* point = pricePoint.GetPoint(timeframes[i]);
         
            // 强制重新检查穿越状态
            bool isPenetrated = false;
            
            // 根据点类型检查穿越状态
            if(pointType == SR_SUPPORT_RANGE_HIGH || pointType == SR_SUPPORT_REBOUND || pointType == SR_SUPPORT)
              {
               // 支撑点 - 如果当前价格低于支撑价格，则被穿越
               double currentPrice = g_tradeAnalyzer.GetRetracePrice();
               isPenetrated = (currentPrice > 0 && currentPrice < price);
              }
            else if(pointType == SR_RESISTANCE_RETRACE)
              {
               // 回撤点压力 - 使用回撤点之后到最近区间的最高价格来判断
               datetime retraceTime = g_tradeAnalyzer.GetRetraceTime();
               datetime highTime = 0;
               // 查找回撤点之后的最高价格
               double highestPrice = 0.0;
               
               // 如果回撤时间有效，查找之后的最高价格
               if(retraceTime > 0)
                 {
                  // 使用CommonUtils中的函数查找回撤点之后的最高价格
                  highestPrice = FindHighestPriceAfterLowPrice(g_tradeAnalyzer.GetRetracePrice(), highTime, PERIOD_CURRENT, PERIOD_M1, retraceTime);
                 }
               else
                 {
                  // 如果回撤时间无效，使用当前价格
                  highestPrice = g_tradeAnalyzer.GetRetracePrice();
                 }
               
               // 判断最高价格是否突破了压力点
               isPenetrated = (highestPrice > 0 && highestPrice > price);
              }
            else if(pointType == SR_RESISTANCE_RANGE_LOW || pointType == SR_RESISTANCE)
              {
               // 其他压力点 - 如果当前价格高于压力价格，则被穿越
               double currentPrice = g_tradeAnalyzer.GetRetracePrice();
               isPenetrated = (currentPrice > 0 && currentPrice > price);
              }
              
            // 如果价格有效且满足绘制条件，并且（未被穿越或设置为显示已穿越的点）
            // 特殊处理：回撤点压力被突破后不再显示
            bool shouldSkipPenetratedRetrace = (isPenetrated && pointType == SR_RESISTANCE_RETRACE);
            
            if(price > 0 && shouldDraw && point != NULL && (!isPenetrated || (g_ShowPenetratedPoints && !shouldSkipPenetratedRetrace)))
           {
            // 如果时间无效，使用参考时间
            if(time == 0)
               time = g_tradeAnalyzer.GetRetraceTime();
               
            // 计算矩形的开始和结束时间
            datetime startTime = time;
            datetime endTime = time + PeriodSeconds(PERIOD_H1) * 15;
            
            // 创建对象名称
            string rectName = StringFormat("SR_%s_%s", baseName, timeframeNames[i]);
            string labelName = StringFormat("SR_%s_Label_%s", baseName, timeframeNames[i]);
            
            // 创建标签文本，显示时间周期、价格和穿越状态
            string labelText;
            color labelColor;
            ENUM_LINE_STYLE lineStyle;
            int transparency;
            
            // 强制重新检查穿越状态
            bool isPenetrated = false;
            
            // 根据点类型和当前价格检查穿越状态
            if(pointType == SR_SUPPORT_RANGE_HIGH || pointType == SR_SUPPORT_REBOUND || pointType == SR_SUPPORT)
              {
               // 支撑点 - 如果当前价格低于支撑价格，则被穿越
               double currentPrice = g_tradeAnalyzer.GetRetracePrice();
               isPenetrated = (currentPrice > 0 && currentPrice < price);
              }
            else if(pointType == SR_RESISTANCE_RETRACE || pointType == SR_RESISTANCE_RANGE_LOW || pointType == SR_RESISTANCE)
              {
               // 压力点 - 如果当前价格高于压力价格，则被穿越
               double currentPrice = g_tradeAnalyzer.GetRetracePrice();
               isPenetrated = (currentPrice > 0 && currentPrice > price);
              }
            
            if(isPenetrated)
              {
               // 被穿越的点使用特殊标记，但保持相同的颜色系列
               labelText = StringFormat("%s-> %s [穿]", 
                                      timeframeNames[i], 
                                      DoubleToString(price, _Digits));
               labelColor = timeframeColors[i]; // 使用与未穿越点相同的颜色系列
               lineStyle = STYLE_DOT; // 使用点线样式区分
               transparency = 85; // 稍微增加透明度
              }
            else
              {
               // 正常点
               labelText = StringFormat("%s-> %s", 
                                      timeframeNames[i], 
                                      DoubleToString(price, _Digits));
               labelColor = timeframeColors[i];
               lineStyle = STYLE_DASH;
               transparency = 70;
              }
            
            // 创建矩形和标签
            CreateSupportResistanceRect(rectName, labelName, 
                                      startTime, endTime, price, rectHeight, 
                                      labelColor, labelText, lineStyle, transparency);
           }
        }
     }
     
   // 辅助函数：调整颜色亮度
   static color ColorBrighten(color clr, int percent)
     {
      // 提取RGB分量
      int r = (clr >> 16) & 0xFF;
      int g = (clr >> 8) & 0xFF;
      int b = clr & 0xFF;
      
      // 调整亮度
      if(percent > 0)
        {
         // 增加亮度
         r = r + (255 - r) * percent / 100;
         g = g + (255 - g) * percent / 100;
         b = b + (255 - b) * percent / 100;
        }
      else if(percent < 0)
        {
         // 减少亮度
         r = r * (100 + percent) / 100;
         g = g * (100 + percent) / 100;
         b = b * (100 + percent) / 100;
        }
      
      // 确保值在0-255范围内
      r = MathMax(0, MathMin(255, r));
      g = MathMax(0, MathMin(255, g));
      b = MathMax(0, MathMin(255, b));
      
      // 重新组合RGB分量
      return (color)((r << 16) | (g << 8) | b);
     }
     
   // 绘制回撤点、反弹点和区间高低点
   static void DrawRetraceReboundPoint()
     {
      if(!g_tradeAnalyzer.IsValid())
         return;
         
      // 获取回撤或反弹价格和时间
      double retracePrice = g_tradeAnalyzer.GetRetracePrice();
      datetime retraceTime = g_tradeAnalyzer.GetRetraceTime();
      double retracePercent = g_tradeAnalyzer.GetRetracePercent();
      
      if(retracePrice <= 0 || retraceTime == 0)
         return;
      
      // 矩形高度（价格单位）
      double rectHeight = 600 * _Point; // 矩形高度为15个点，比支撑压力区域小一些
      
      // 根据趋势方向确定是回撤点还是反弹点
      if(g_tradeAnalyzer.IsUpTrend())
        {
         // 上涨趋势，绘制回撤点压力
         
         // 获取支撑位价格
         double support1H = g_tradeAnalyzer.GetSupportPrice(PERIOD_H1);
         
         // 创建回撤点动态价格点对象
         CDynamicPricePoint retracePoints(retracePrice, SR_RESISTANCE_RETRACE);
         
         // 绘制回撤点压力 - 红色系
         DrawDynamicPricePoint(retracePoints, retracePrice, support1H, 
                             retracePrice < support1H, "Retrace", clrCrimson, 
                             retracePercent);
                             
         // 绘制区间高点支撑 - 蓝色系
         double rangeHigh = g_tradeAnalyzer.GetRangeHigh();
         CDynamicPricePoint rangeHighPoints(rangeHigh, SR_SUPPORT_RANGE_HIGH);
         
         DrawDynamicPricePoint(rangeHighPoints, rangeHigh, 0, true, 
                             "RangeHigh", clrDodgerBlue);
        }
      else
        {
         // 下跌趋势，绘制反弹点支撑
         
         // 获取压力位价格
         double resistance1H = g_tradeAnalyzer.GetResistancePrice(PERIOD_H1);
         
         // 创建反弹点动态价格点对象
         CDynamicPricePoint reboundPoints(retracePrice, SR_SUPPORT_REBOUND);
         
         // 绘制反弹点支撑 - 蓝色系
         DrawDynamicPricePoint(reboundPoints, retracePrice, resistance1H, 
                             retracePrice > resistance1H, "Rebound", clrDodgerBlue, 
                             retracePercent);
                             
         // 绘制区间低点压力 - 红色系
         double rangeLow = g_tradeAnalyzer.GetRangeLow();
         CDynamicPricePoint rangeLowPoints(rangeLow, SR_RESISTANCE_RANGE_LOW);
         
         DrawDynamicPricePoint(rangeLowPoints, rangeLow, 0, true, 
                             "RangeLow", clrCrimson);
        }
     }
  };
