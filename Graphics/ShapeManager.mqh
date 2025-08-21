//+------------------------------------------------------------------+
//|                                                 ShapeManager.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

// 引入交易分析类
#include "../TradeAnalyzer.mqh"

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
      color colorWithAlpha = fillColor & 0x00FFFFFF | (transparency << 24);
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
                               string font = "Arial", int fontSize = 8, 
                               ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_LOWER)
     {
      ObjectSetString(0, objectName, OBJPROP_TEXT, text);
      ObjectSetString(0, objectName, OBJPROP_FONT, font);
      ObjectSetInteger(0, objectName, OBJPROP_FONTSIZE, fontSize);
      ObjectSetInteger(0, objectName, OBJPROP_COLOR, textColor);
      ObjectSetInteger(0, objectName, OBJPROP_ANCHOR, anchor);
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
      if(!CTradeAnalyzer::IsValid())
         return;
         
      // 删除所有旧的图形对象
      ObjectsDeleteAll(0, "SR_");  // 删除所有以SR_开头的对象
      
      // 矩形高度（价格单位）
      double rectHeight = 800 * _Point; // 矩形高度为20个点，可以根据需要调整
      
      // 绘制回撤点或反弹点
      DrawRetraceReboundPoint();
     }
     
   // 绘制回撤点或反弹点
   static void DrawRetraceReboundPoint()
     {
      if(!CTradeAnalyzer::IsValid())
         return;
         
      // 获取回撤或反弹价格和时间
      double retracePrice = CTradeAnalyzer::GetRetracePrice();
      datetime retraceTime = CTradeAnalyzer::GetRetraceTime();
      double retracePercent = CTradeAnalyzer::GetRetracePercent();
      
      if(retracePrice <= 0 || retraceTime == 0)
         return;
      
      // 矩形高度（价格单位）
      double rectHeight = 600 * _Point; // 矩形高度为15个点，比支撑压力区域小一些
      
      // 根据趋势方向确定是回撤点还是反弹点
      if(CTradeAnalyzer::IsUpTrend())
        {
         // 上涨趋势，绘制回撤点压力 (H1, H4, D1三个级别)
         
         // 获取支撑位价格
         double support1H = CTradeAnalyzer::GetSupport1H();
         double support4H = CTradeAnalyzer::GetSupport4H();
         double supportD1 = CTradeAnalyzer::GetSupportD1();
         
         // 获取回撤点的动态支撑压力点对象
         CDynamicSupportResistancePoints retracePoints(retracePrice, SR_RESISTANCE_RETRACE);
         
         // 只有当回撤价格低于对应级别的支撑价格时，才绘制该级别的回撤点压力
         
         // 1小时回撤点压力 - 紫色
         double retrace1H = retracePoints.GetPriceH1();
         if(retrace1H > 0 && retracePrice < support1H)
           {
            // 获取回撤点对应的时间
            datetime retraceTime1H = retracePoints.GetTimeH1();
            if(retraceTime1H == 0) retraceTime1H = retraceTime;
            
            // 计算矩形的开始和结束时间
            datetime startTime1H = retraceTime1H;
            datetime endTime1H = retraceTime1H + PeriodSeconds(PERIOD_H1) * 15;
            
            // 创建矩形和标签
            string labelText1H = "1H回撤点压力 " + DoubleToString(retrace1H, _Digits) + " (" + DoubleToString(retracePercent, 1) + "%)";
            CreateSupportResistanceRect("SR_Retrace_H1", "SR_Retrace_Label_H1", 
                                      startTime1H, endTime1H, retrace1H, rectHeight, 
                                      clrMagenta, labelText1H, STYLE_DASH, 70);
           }
           
         // 4小时回撤点压力 - 深紫色 - 只有当回撤价格低于4小时支撑价格时才绘制
         double retrace4H = retracePoints.GetPriceH4();
         if(retrace4H > 0 && retracePrice < support4H)
           {
            // 获取回撤点对应的时间
            datetime retraceTime4H = retracePoints.GetTimeH4();
            if(retraceTime4H == 0) retraceTime4H = retraceTime;
            
            // 计算矩形的开始和结束时间
            datetime startTime4H = retraceTime4H;
            datetime endTime4H = retraceTime4H + PeriodSeconds(PERIOD_H1) * 15;
            
            // 创建矩形和标签
            string labelText4H = "4H回撤点压力 " + DoubleToString(retrace4H, _Digits);
            CreateSupportResistanceRect("SR_Retrace_H4", "SR_Retrace_Label_H4", 
                                      startTime4H, endTime4H, retrace4H, rectHeight, 
                                      clrDarkMagenta, labelText4H, STYLE_DASH, 70);
           }
           
         // 日线回撤点压力 - 紫红色 - 只有当回撤价格低于日线支撑价格时才绘制
         double retraceD1 = retracePoints.GetPriceD1();
         if(retraceD1 > 0 && retracePrice < supportD1)
           {
            // 获取回撤点对应的时间
            datetime retraceTimeD1 = retracePoints.GetTimeD1();
            if(retraceTimeD1 == 0) retraceTimeD1 = retraceTime;
            
            // 计算矩形的开始和结束时间
            datetime startTimeD1 = retraceTimeD1;
            datetime endTimeD1 = retraceTimeD1 + PeriodSeconds(PERIOD_H1) * 15;
            
            // 创建矩形和标签
            string labelTextD1 = "D1回撤点压力 " + DoubleToString(retraceD1, _Digits);
            CreateSupportResistanceRect("SR_Retrace_D1", "SR_Retrace_Label_D1", 
                                      startTimeD1, endTimeD1, retraceD1, rectHeight, 
                                      clrPurple, labelTextD1, STYLE_DASH, 70);
           }
        }
      else
        {
         // 下跌趋势，绘制反弹点支撑 (H1, H4, D1三个级别)
         
         // 获取压力位价格
         double resistance1H = CTradeAnalyzer::GetResistance1H();
         double resistance4H = CTradeAnalyzer::GetResistance4H();
         double resistanceD1 = CTradeAnalyzer::GetResistanceD1();
         
         // 获取反弹点的动态支撑压力点对象
         CDynamicSupportResistancePoints reboundPoints(retracePrice, SR_SUPPORT_REBOUND);
         
         // 1小时反弹点支撑 - 金色 - 只有当反弹价格高于1小时压力价格时才绘制
         double rebound1H = reboundPoints.GetPriceH1();
         if(rebound1H > 0 && retracePrice > resistance1H)
           {
            // 获取反弹点对应的时间
            datetime reboundTime1H = reboundPoints.GetTimeH1();
            if(reboundTime1H == 0) reboundTime1H = retraceTime;
            
            // 计算矩形的开始和结束时间
            datetime startTime1H = reboundTime1H;
            datetime endTime1H = reboundTime1H + PeriodSeconds(PERIOD_H1) * 15;
            
            // 创建矩形和标签
            string labelText1H = "1H反弹点支撑 " + DoubleToString(rebound1H, _Digits) + " (" + DoubleToString(retracePercent, 1) + "%)";
            CreateSupportResistanceRect("SR_Rebound_H1", "SR_Rebound_Label_H1", 
                                      startTime1H, endTime1H, rebound1H, rectHeight, 
                                      clrGold, labelText1H, STYLE_DASH, 70);
           }
           
         // 4小时反弹点支撑 - 橙色 - 只有当反弹价格高于4小时压力价格时才绘制
         double rebound4H = reboundPoints.GetPriceH4();
         if(rebound4H > 0 && retracePrice > resistance4H)
           {
            // 获取反弹点对应的时间
            datetime reboundTime4H = reboundPoints.GetTimeH4();
            if(reboundTime4H == 0) reboundTime4H = retraceTime;
            
            // 计算矩形的开始和结束时间
            datetime startTime4H = reboundTime4H;
            datetime endTime4H = reboundTime4H + PeriodSeconds(PERIOD_H1) * 15;
            
            // 创建矩形和标签
            string labelText4H = "4H反弹点支撑 " + DoubleToString(rebound4H, _Digits);
            CreateSupportResistanceRect("SR_Rebound_H4", "SR_Rebound_Label_H4", 
                                      startTime4H, endTime4H, rebound4H, rectHeight, 
                                      clrOrange, labelText4H, STYLE_DASH, 70);
           }
           
         // 日线反弹点支撑 - 深橙色 - 只有当反弹价格高于日线压力价格时才绘制
         double reboundD1 = reboundPoints.GetPriceD1();
         if(reboundD1 > 0 && retracePrice > resistanceD1)
           {
            // 获取反弹点对应的时间
            datetime reboundTimeD1 = reboundPoints.GetTimeD1();
            if(reboundTimeD1 == 0) reboundTimeD1 = retraceTime;
            
            // 计算矩形的开始和结束时间
            datetime startTimeD1 = reboundTimeD1;
            datetime endTimeD1 = reboundTimeD1 + PeriodSeconds(PERIOD_H1) * 15;
            
            // 创建矩形和标签
            string labelTextD1 = "D1反弹点支撑 " + DoubleToString(reboundD1, _Digits);
            CreateSupportResistanceRect("SR_Rebound_D1", "SR_Rebound_Label_D1", 
                                      startTimeD1, endTimeD1, reboundD1, rectHeight, 
                                      clrDarkOrange, labelTextD1, STYLE_DASH, 70);
           }
        }
      
      // 根据趋势方向绘制支撑或压力线
      if(CTradeAnalyzer::IsUpTrend())
        {
         // 上涨趋势，绘制支撑线
         
         // 1小时支撑线 - 绿色
         double support1H = CTradeAnalyzer::GetSupport1H();
         if(support1H > 0)
           {
            // 获取支撑位对应的1小时K线时间
            datetime supportTime1H = CTradeAnalyzer::GetSupport1HTime();
            
            // 如果没有有效的支撑时间，则使用区间高点时间
            if(supportTime1H == 0)
               supportTime1H = CTradeAnalyzer::GetRangeHighTime();
            
            // 计算矩形的开始和结束时间（以当前价格点为起点，向未来方向延伸20个1小时周期）
            datetime startTime1H = supportTime1H;
            datetime endTime1H = supportTime1H + PeriodSeconds(PERIOD_H1) * 20;
            
            // 创建矩形和标签
            string labelText1H = "1H支撑=" + DoubleToString(support1H, _Digits);
            CreateSupportResistanceRect("SR_Rect_1H", "SR_Label_1H", 
                                      startTime1H, endTime1H, support1H, rectHeight, 
                                      clrGreen, labelText1H);
           }
           
         // 4小时支撑线 - 蓝色
         double support4H = CTradeAnalyzer::GetSupport4H();
         if(support4H > 0)
           {
            // 获取支撑位对应的1小时K线时间
            datetime supportTime4H = CTradeAnalyzer::GetSupport4HTime();
            
            // 如果没有有效的支撑时间，则使用区间高点时间
            if(supportTime4H == 0)
               supportTime4H = CTradeAnalyzer::GetRangeHighTime();
            
            // 计算矩形的开始和结束时间（以当前价格点为起点，向未来方向延伸20个1小时周期）
            datetime startTime4H = supportTime4H;
            datetime endTime4H = supportTime4H + PeriodSeconds(PERIOD_H1) * 20;
            
            // 创建矩形和标签
            string labelText4H = "4H支撑";
            CreateSupportResistanceRect("SR_Rect_4H", "SR_Label_4H", 
                                      startTime4H, endTime4H, support4H, rectHeight, 
                                      clrBlue, labelText4H);
           }
           
         // 日线支撑线 - 红色
         double supportD1 = CTradeAnalyzer::GetSupportD1();
         if(supportD1 > 0)
           {
            // 获取支撑位对应的1小时K线时间
            datetime supportTimeD1 = CTradeAnalyzer::GetSupportD1Time();
            
            // 如果没有有效的支撑时间，则使用区间高点时间
            if(supportTimeD1 == 0)
               supportTimeD1 = CTradeAnalyzer::GetRangeHighTime();
            
            // 计算矩形的开始和结束时间（以当前价格点为起点，向未来方向延伸20个1小时周期）
            datetime startTimeD1 = supportTimeD1;
            datetime endTimeD1 = supportTimeD1 + PeriodSeconds(PERIOD_H1) * 20;
            
            // 创建矩形和标签
            string labelTextD1 = "D1支撑";
            CreateSupportResistanceRect("SR_Rect_D1", "SR_Label_D1", 
                                      startTimeD1, endTimeD1, supportD1, rectHeight, 
                                      clrRed, labelTextD1);
           }
        }
      else
        {
         // 下跌趋势，绘制压力线
         
         // 1小时压力线 - 绿色
         double resistance1H = CTradeAnalyzer::GetResistance1H();
         if(resistance1H > 0)
           {
            // 获取压力位对应的1小时K线时间
            datetime resistanceTime1H = CTradeAnalyzer::GetResistance1HTime();
            
            // 如果没有有效的压力时间，则使用区间低点时间
            if(resistanceTime1H == 0)
               resistanceTime1H = CTradeAnalyzer::GetRangeLowTime();
            
            // 计算矩形的开始和结束时间（以当前价格点为起点，向未来方向延伸20个1小时周期）
            datetime startTime1H = resistanceTime1H;
            datetime endTime1H = resistanceTime1H + PeriodSeconds(PERIOD_H1) * 20;
            
            // 创建矩形和标签
            string labelText1H = "1H压力=" + DoubleToString(resistance1H, _Digits);
            CreateSupportResistanceRect("SR_Rect_1H", "SR_Label_1H", 
                                      startTime1H, endTime1H, resistance1H, rectHeight, 
                                      clrGreen, labelText1H);
           }
           
         // 4小时压力线 - 蓝色
         double resistance4H = CTradeAnalyzer::GetResistance4H();
         if(resistance4H > 0)
           {
            // 获取压力位对应的1小时K线时间
            datetime resistanceTime4H = CTradeAnalyzer::GetResistance4HTime();
            
            // 如果没有有效的压力时间，则使用区间低点时间
            if(resistanceTime4H == 0)
               resistanceTime4H = CTradeAnalyzer::GetRangeLowTime();
            
            // 计算矩形的开始和结束时间（以当前价格点为起点，向未来方向延伸20个1小时周期）
            datetime startTime4H = resistanceTime4H;
            datetime endTime4H = resistanceTime4H + PeriodSeconds(PERIOD_H1) * 20;
            
            // 创建矩形和标签
            string labelText4H = "4H压力";
            CreateSupportResistanceRect("SR_Rect_4H", "SR_Label_4H", 
                                      startTime4H, endTime4H, resistance4H, rectHeight, 
                                      clrBlue, labelText4H);
           }
           
         // 日线压力线 - 红色
         double resistanceD1 = CTradeAnalyzer::GetResistanceD1();
         if(resistanceD1 > 0)
           {
            // 获取压力位对应的1小时K线时间
            datetime resistanceTimeD1 = CTradeAnalyzer::GetResistanceD1Time();
            
            // 如果没有有效的压力时间，则使用区间低点时间
            if(resistanceTimeD1 == 0)
               resistanceTimeD1 = CTradeAnalyzer::GetRangeLowTime();
            
            // 计算矩形的开始和结束时间（以当前价格点为起点，向未来方向延伸20个1小时周期）
            datetime startTimeD1 = resistanceTimeD1;
            datetime endTimeD1 = startTimeD1 + PeriodSeconds(PERIOD_H1) * 20;
            
            // 创建矩形和标签 - 日线压力使用更明显的红色和更宽的边框
            string labelTextD1 = "D1压力";
            CreateSupportResistanceRect("SR_Rect_D1", "SR_Label_D1", 
                                      startTimeD1, endTimeD1, resistanceD1, rectHeight, 
                                      clrCrimson, labelTextD1, STYLE_SOLID, 60);
           }
        }
     }
  };
