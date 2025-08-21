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
            
            // 创建矩形
            string rectName1H = "SR_Retrace_H1";
            ObjectCreate(0, rectName1H, OBJ_RECTANGLE, 0, startTime1H, retrace1H + rectHeight/2, endTime1H, retrace1H - rectHeight/2);
            ObjectSetInteger(0, rectName1H, OBJPROP_COLOR, clrMagenta);
            // 使用带透明度的颜色
            color magentaWithAlpha = clrMagenta & 0x00FFFFFF | (70 << 24); // 70是透明度(0-255)
            ObjectSetInteger(0, rectName1H, OBJPROP_BGCOLOR, magentaWithAlpha);
            ObjectSetInteger(0, rectName1H, OBJPROP_FILL, true);
            ObjectSetInteger(0, rectName1H, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, rectName1H, OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(0, rectName1H, OBJPROP_BACK, false);
            ObjectSetInteger(0, rectName1H, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, rectName1H, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, rectName1H, OBJPROP_HIDDEN, false);
            
            // 添加标签
            string labelName1H = "SR_Retrace_Label_H1";
            ObjectCreate(0, labelName1H, OBJ_TEXT, 0, retraceTime1H, retrace1H + rectHeight);
            ObjectSetString(0, labelName1H, OBJPROP_TEXT, "1H回撤点压力 " + DoubleToString(retrace1H, _Digits) + " (" + DoubleToString(retracePercent, 1) + "%)");
            ObjectSetString(0, labelName1H, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, labelName1H, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, labelName1H, OBJPROP_COLOR, clrMagenta);
            ObjectSetInteger(0, labelName1H, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
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
            
            // 创建矩形
            string rectName4H = "SR_Retrace_H4";
            ObjectCreate(0, rectName4H, OBJ_RECTANGLE, 0, startTime4H, retrace4H + rectHeight/2, endTime4H, retrace4H - rectHeight/2);
            ObjectSetInteger(0, rectName4H, OBJPROP_COLOR, clrDarkMagenta);
            // 使用带透明度的颜色
            color darkMagentaWithAlpha = clrDarkMagenta & 0x00FFFFFF | (70 << 24); // 70是透明度(0-255)
            ObjectSetInteger(0, rectName4H, OBJPROP_BGCOLOR, darkMagentaWithAlpha);
            ObjectSetInteger(0, rectName4H, OBJPROP_FILL, true);
            ObjectSetInteger(0, rectName4H, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, rectName4H, OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(0, rectName4H, OBJPROP_BACK, false);
            ObjectSetInteger(0, rectName4H, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, rectName4H, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, rectName4H, OBJPROP_HIDDEN, false);
            
            // 添加标签
            string labelName4H = "SR_Retrace_Label_H4";
            ObjectCreate(0, labelName4H, OBJ_TEXT, 0, retraceTime4H, retrace4H + rectHeight);
            ObjectSetString(0, labelName4H, OBJPROP_TEXT, "4H回撤点压力 " + DoubleToString(retrace4H, _Digits));
            ObjectSetString(0, labelName4H, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, labelName4H, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, labelName4H, OBJPROP_COLOR, clrDarkMagenta);
            ObjectSetInteger(0, labelName4H, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
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
            
            // 创建矩形
            string rectNameD1 = "SR_Retrace_D1";
            ObjectCreate(0, rectNameD1, OBJ_RECTANGLE, 0, startTimeD1, retraceD1 + rectHeight/2, endTimeD1, retraceD1 - rectHeight/2);
            ObjectSetInteger(0, rectNameD1, OBJPROP_COLOR, clrPurple);
            // 使用带透明度的颜色
            color purpleWithAlpha = clrPurple & 0x00FFFFFF | (70 << 24); // 70是透明度(0-255)
            ObjectSetInteger(0, rectNameD1, OBJPROP_BGCOLOR, purpleWithAlpha);
            ObjectSetInteger(0, rectNameD1, OBJPROP_FILL, true);
            ObjectSetInteger(0, rectNameD1, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, rectNameD1, OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(0, rectNameD1, OBJPROP_BACK, false);
            ObjectSetInteger(0, rectNameD1, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, rectNameD1, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, rectNameD1, OBJPROP_HIDDEN, false);
            
            // 添加标签
            string labelNameD1 = "SR_Retrace_Label_D1";
            ObjectCreate(0, labelNameD1, OBJ_TEXT, 0, retraceTimeD1, retraceD1 + rectHeight);
            ObjectSetString(0, labelNameD1, OBJPROP_TEXT, "D1回撤点压力 " + DoubleToString(retraceD1, _Digits));
            ObjectSetString(0, labelNameD1, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, labelNameD1, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, labelNameD1, OBJPROP_COLOR, clrPurple);
            ObjectSetInteger(0, labelNameD1, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
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
            
            // 创建矩形
            string rectName1H = "SR_Rebound_H1";
            ObjectCreate(0, rectName1H, OBJ_RECTANGLE, 0, startTime1H, rebound1H + rectHeight/2, endTime1H, rebound1H - rectHeight/2);
            ObjectSetInteger(0, rectName1H, OBJPROP_COLOR, clrGold);
            // 使用带透明度的颜色
            color goldWithAlpha = clrGold & 0x00FFFFFF | (70 << 24); // 70是透明度(0-255)
            ObjectSetInteger(0, rectName1H, OBJPROP_BGCOLOR, goldWithAlpha);
            ObjectSetInteger(0, rectName1H, OBJPROP_FILL, true);
            ObjectSetInteger(0, rectName1H, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, rectName1H, OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(0, rectName1H, OBJPROP_BACK, false);
            ObjectSetInteger(0, rectName1H, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, rectName1H, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, rectName1H, OBJPROP_HIDDEN, false);
            
            // 添加标签
            string labelName1H = "SR_Rebound_Label_H1";
            ObjectCreate(0, labelName1H, OBJ_TEXT, 0, reboundTime1H, rebound1H + rectHeight);
            ObjectSetString(0, labelName1H, OBJPROP_TEXT, "1H反弹点支撑 " + DoubleToString(rebound1H, _Digits) + " (" + DoubleToString(retracePercent, 1) + "%)");
            ObjectSetString(0, labelName1H, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, labelName1H, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, labelName1H, OBJPROP_COLOR, clrGold);
            ObjectSetInteger(0, labelName1H, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
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
            
            // 创建矩形
            string rectName4H = "SR_Rebound_H4";
            ObjectCreate(0, rectName4H, OBJ_RECTANGLE, 0, startTime4H, rebound4H + rectHeight/2, endTime4H, rebound4H - rectHeight/2);
            ObjectSetInteger(0, rectName4H, OBJPROP_COLOR, clrOrange);
            // 使用带透明度的颜色
            color orangeWithAlpha = clrOrange & 0x00FFFFFF | (70 << 24); // 70是透明度(0-255)
            ObjectSetInteger(0, rectName4H, OBJPROP_BGCOLOR, orangeWithAlpha);
            ObjectSetInteger(0, rectName4H, OBJPROP_FILL, true);
            ObjectSetInteger(0, rectName4H, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, rectName4H, OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(0, rectName4H, OBJPROP_BACK, false);
            ObjectSetInteger(0, rectName4H, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, rectName4H, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, rectName4H, OBJPROP_HIDDEN, false);
            
            // 添加标签
            string labelName4H = "SR_Rebound_Label_H4";
            ObjectCreate(0, labelName4H, OBJ_TEXT, 0, reboundTime4H, rebound4H + rectHeight);
            ObjectSetString(0, labelName4H, OBJPROP_TEXT, "4H反弹点支撑 " + DoubleToString(rebound4H, _Digits));
            ObjectSetString(0, labelName4H, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, labelName4H, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, labelName4H, OBJPROP_COLOR, clrOrange);
            ObjectSetInteger(0, labelName4H, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
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
            
            // 创建矩形
            string rectNameD1 = "SR_Rebound_D1";
            ObjectCreate(0, rectNameD1, OBJ_RECTANGLE, 0, startTimeD1, reboundD1 + rectHeight/2, endTimeD1, reboundD1 - rectHeight/2);
            ObjectSetInteger(0, rectNameD1, OBJPROP_COLOR, clrDarkOrange);
            // 使用带透明度的颜色
            color darkOrangeWithAlpha = clrDarkOrange & 0x00FFFFFF | (70 << 24); // 70是透明度(0-255)
            ObjectSetInteger(0, rectNameD1, OBJPROP_BGCOLOR, darkOrangeWithAlpha);
            ObjectSetInteger(0, rectNameD1, OBJPROP_FILL, true);
            ObjectSetInteger(0, rectNameD1, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, rectNameD1, OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(0, rectNameD1, OBJPROP_BACK, false);
            ObjectSetInteger(0, rectNameD1, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, rectNameD1, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, rectNameD1, OBJPROP_HIDDEN, false);
            
            // 添加标签
            string labelNameD1 = "SR_Rebound_Label_D1";
            ObjectCreate(0, labelNameD1, OBJ_TEXT, 0, reboundTimeD1, reboundD1 + rectHeight);
            ObjectSetString(0, labelNameD1, OBJPROP_TEXT, "D1反弹点支撑 " + DoubleToString(reboundD1, _Digits));
            ObjectSetString(0, labelNameD1, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, labelNameD1, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, labelNameD1, OBJPROP_COLOR, clrDarkOrange);
            ObjectSetInteger(0, labelNameD1, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
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
            
            // 创建矩形
            string rectName1H = "SR_Rect_1H";
            ObjectCreate(0, rectName1H, OBJ_RECTANGLE, 0, startTime1H, support1H + rectHeight/2, endTime1H, support1H - rectHeight/2);
            ObjectSetInteger(0, rectName1H, OBJPROP_COLOR, clrGreen);
            // 使用带透明度的颜色 - 使用ARGB格式，第一个参数是透明度(0-255)
            color greenWithAlpha = clrGreen & 0x00FFFFFF | (80 << 24); // 80是透明度(0-255)
            ObjectSetInteger(0, rectName1H, OBJPROP_BGCOLOR, greenWithAlpha);
            ObjectSetInteger(0, rectName1H, OBJPROP_FILL, true);
            ObjectSetInteger(0, rectName1H, OBJPROP_WIDTH, 2); // 增加边框宽度
            ObjectSetInteger(0, rectName1H, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, rectName1H, OBJPROP_BACK, false); // 放在前景，使其更明显
            ObjectSetInteger(0, rectName1H, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, rectName1H, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, rectName1H, OBJPROP_HIDDEN, false); // 确保不隐藏
            ObjectSetInteger(0, rectName1H, OBJPROP_FILL, true);
            
            // 添加标签
            string labelName1H = "SR_Label_1H";
            ObjectCreate(0, labelName1H, OBJ_TEXT, 0, supportTime1H, support1H + rectHeight);
            ObjectSetString(0, labelName1H, OBJPROP_TEXT, "1H支撑=" + DoubleToString(support1H, _Digits));
            ObjectSetString(0, labelName1H, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, labelName1H, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, labelName1H, OBJPROP_COLOR, clrGreen);
            ObjectSetInteger(0, labelName1H, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
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
            
            // 创建矩形
            string rectName4H = "SR_Rect_4H";
            ObjectCreate(0, rectName4H, OBJ_RECTANGLE, 0, startTime4H, support4H + rectHeight/2, endTime4H, support4H - rectHeight/2);
            ObjectSetInteger(0, rectName4H, OBJPROP_COLOR, clrBlue);
            // 使用带透明度的颜色 - 使用ARGB格式，第一个参数是透明度(0-255)
            color blueWithAlpha = clrBlue & 0x00FFFFFF | (80 << 24); // 80是透明度(0-255)
            ObjectSetInteger(0, rectName4H, OBJPROP_BGCOLOR, blueWithAlpha);
            ObjectSetInteger(0, rectName4H, OBJPROP_FILL, true);
            ObjectSetInteger(0, rectName4H, OBJPROP_WIDTH, 2); // 增加边框宽度
            ObjectSetInteger(0, rectName4H, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, rectName4H, OBJPROP_BACK, false); // 放在前景，使其更明显
            ObjectSetInteger(0, rectName4H, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, rectName4H, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, rectName4H, OBJPROP_HIDDEN, false); // 确保不隐藏
            ObjectSetInteger(0, rectName4H, OBJPROP_FILL, true);
            
            // 添加标签
            string labelName4H = "SR_Label_4H";
            ObjectCreate(0, labelName4H, OBJ_TEXT, 0, supportTime4H, support4H + rectHeight);
            ObjectSetString(0, labelName4H, OBJPROP_TEXT, "4H支撑");
            ObjectSetString(0, labelName4H, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, labelName4H, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, labelName4H, OBJPROP_COLOR, clrBlue);
            ObjectSetInteger(0, labelName4H, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
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
            
            // 创建矩形 - 确保日线支撑区正确显示
            string rectNameD1 = "SR_Rect_D1";
            ObjectCreate(0, rectNameD1, OBJ_RECTANGLE, 0, startTimeD1, supportD1 + rectHeight/2, endTimeD1, supportD1 - rectHeight/2);
            ObjectSetInteger(0, rectNameD1, OBJPROP_COLOR, clrRed);
            // 使用带透明度的颜色 - 使用ARGB格式，第一个参数是透明度(0-255)
            color redWithAlpha = clrRed & 0x00FFFFFF | (80 << 24); // 80是透明度(0-255)
            ObjectSetInteger(0, rectNameD1, OBJPROP_BGCOLOR, redWithAlpha);
            ObjectSetInteger(0, rectNameD1, OBJPROP_FILL, true);
            ObjectSetInteger(0, rectNameD1, OBJPROP_WIDTH, 2); // 增加边框宽度
            ObjectSetInteger(0, rectNameD1, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, rectNameD1, OBJPROP_BACK, false); // 放在前景，使其更明显
            ObjectSetInteger(0, rectNameD1, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, rectNameD1, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, rectNameD1, OBJPROP_HIDDEN, false); // 确保不隐藏
            ObjectSetInteger(0, rectNameD1, OBJPROP_FILL, true);
            
            // 添加标签
            string labelNameD1 = "SR_Label_D1";
            ObjectCreate(0, labelNameD1, OBJ_TEXT, 0, supportTimeD1, supportD1 + rectHeight);
            ObjectSetString(0, labelNameD1, OBJPROP_TEXT, "D1支撑");
            ObjectSetString(0, labelNameD1, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, labelNameD1, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, labelNameD1, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, labelNameD1, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
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
            
            // 创建矩形
            string rectName1H = "SR_Rect_1H";
            ObjectCreate(0, rectName1H, OBJ_RECTANGLE, 0, startTime1H, resistance1H + rectHeight/2, endTime1H, resistance1H - rectHeight/2);
            ObjectSetInteger(0, rectName1H, OBJPROP_COLOR, clrGreen);
            // 使用带透明度的颜色 - 使用ARGB格式，第一个参数是透明度(0-255)
            color greenWithAlpha = clrGreen & 0x00FFFFFF | (80 << 24); // 80是透明度(0-255)
            ObjectSetInteger(0, rectName1H, OBJPROP_BGCOLOR, greenWithAlpha);
            ObjectSetInteger(0, rectName1H, OBJPROP_FILL, true);
            ObjectSetInteger(0, rectName1H, OBJPROP_WIDTH, 2); // 增加边框宽度
            ObjectSetInteger(0, rectName1H, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, rectName1H, OBJPROP_BACK, false); // 放在前景，使其更明显
            ObjectSetInteger(0, rectName1H, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, rectName1H, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, rectName1H, OBJPROP_HIDDEN, false); // 确保不隐藏
            ObjectSetInteger(0, rectName1H, OBJPROP_FILL, true);
            
            // 添加标签
            string labelName1H = "SR_Label_1H";
            ObjectCreate(0, labelName1H, OBJ_TEXT, 0, resistanceTime1H, resistance1H + rectHeight);
            ObjectSetString(0, labelName1H, OBJPROP_TEXT, "1H压力=" + DoubleToString(resistance1H, _Digits));
            ObjectSetString(0, labelName1H, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, labelName1H, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, labelName1H, OBJPROP_COLOR, clrGreen);
            ObjectSetInteger(0, labelName1H, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
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
            
            // 创建矩形
            string rectName4H = "SR_Rect_4H";
            ObjectCreate(0, rectName4H, OBJ_RECTANGLE, 0, startTime4H, resistance4H + rectHeight/2, endTime4H, resistance4H - rectHeight/2);
            ObjectSetInteger(0, rectName4H, OBJPROP_COLOR, clrBlue);
            // 使用带透明度的颜色 - 使用ARGB格式，第一个参数是透明度(0-255)
            color blueWithAlpha = clrBlue & 0x00FFFFFF | (80 << 24); // 80是透明度(0-255)
            ObjectSetInteger(0, rectName4H, OBJPROP_BGCOLOR, blueWithAlpha);
            ObjectSetInteger(0, rectName4H, OBJPROP_FILL, true);
            ObjectSetInteger(0, rectName4H, OBJPROP_WIDTH, 2); // 增加边框宽度
            ObjectSetInteger(0, rectName4H, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, rectName4H, OBJPROP_BACK, false); // 放在前景，使其更明显
            ObjectSetInteger(0, rectName4H, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, rectName4H, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, rectName4H, OBJPROP_HIDDEN, false); // 确保不隐藏
            ObjectSetInteger(0, rectName4H, OBJPROP_FILL, true);
            
            // 添加标签
            string labelName4H = "SR_Label_4H";
            ObjectCreate(0, labelName4H, OBJ_TEXT, 0, resistanceTime4H, resistance4H + rectHeight);
            ObjectSetString(0, labelName4H, OBJPROP_TEXT, "4H压力");
            ObjectSetString(0, labelName4H, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, labelName4H, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, labelName4H, OBJPROP_COLOR, clrBlue);
            ObjectSetInteger(0, labelName4H, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
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
            
            // 创建矩形 - 确保日线压力区正确显示，使用更明显的颜色和更宽的边框
            string rectNameD1 = "SR_Rect_D1";
            ObjectCreate(0, rectNameD1, OBJ_RECTANGLE, 0, startTimeD1, resistanceD1 + rectHeight/2, endTimeD1, resistanceD1 - rectHeight/2);
            ObjectSetInteger(0, rectNameD1, OBJPROP_COLOR, clrCrimson); // 使用更明显的红色
            // 使用带透明度的颜色 - 使用ARGB格式，第一个参数是透明度(0-255)
            color redWithAlpha = clrCrimson & 0x00FFFFFF | (60 << 24); // 60是透明度(0-255)，更不透明
            ObjectSetInteger(0, rectNameD1, OBJPROP_BGCOLOR, redWithAlpha);
            ObjectSetInteger(0, rectNameD1, OBJPROP_FILL, true);
            ObjectSetInteger(0, rectNameD1, OBJPROP_WIDTH, 3); // 增加边框宽度到3
            ObjectSetInteger(0, rectNameD1, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, rectNameD1, OBJPROP_BACK, false); // 放在前景，使其更明显
            ObjectSetInteger(0, rectNameD1, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, rectNameD1, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, rectNameD1, OBJPROP_HIDDEN, false); // 确保不隐藏
            ObjectSetInteger(0, rectNameD1, OBJPROP_FILL, true);
            
            // 添加标签
            string labelNameD1 = "SR_Label_D1";
            ObjectCreate(0, labelNameD1, OBJ_TEXT, 0, resistanceTimeD1, resistanceD1 + rectHeight);
            ObjectSetString(0, labelNameD1, OBJPROP_TEXT, "D1压力");
            ObjectSetString(0, labelNameD1, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, labelNameD1, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, labelNameD1, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, labelNameD1, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
           }
        }
     }
  };
