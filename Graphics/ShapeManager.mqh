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
         
      // 删除旧的支撑/压力线和矩形
      ObjectsDeleteAll(0, "SR_Line_");
      ObjectsDeleteAll(0, "SR_Rect_");
      
      // 矩形高度（价格单位）
      double rectHeight = 20 * _Point; // 矩形高度为20个点，可以根据需要调整
      
      // 根据趋势方向绘制支撑或压力线
      if(CTradeAnalyzer::IsUpTrend())
        {
         // 上涨趋势，绘制支撑线
         
         // 1小时支撑线 - 绿色
         double support1H = CTradeAnalyzer::GetSupport1H();
         if(support1H > 0)
           {
            // 获取支撑位对应的时间 - 使用区间高点时间作为中心点
            datetime supportTime1H = CTradeAnalyzer::GetRangeHighTime();
            
            // 计算矩形的开始和结束时间（以中心点为基准，向左右各延伸10个1小时周期）
            datetime startTime1H = supportTime1H - PeriodSeconds(PERIOD_H1) * 10;
            datetime endTime1H = supportTime1H + PeriodSeconds(PERIOD_H1) * 10;
            
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
            // 获取支撑位对应的时间 - 使用高点时间作为中心点
            datetime supportTime4H = CTradeAnalyzer::GetRangeHighTime();
            
            // 计算矩形的开始和结束时间（以中心点为基准，向左右各延伸10个1小时周期）
            datetime startTime4H = supportTime4H - PeriodSeconds(PERIOD_H1) * 10;
            datetime endTime4H = supportTime4H + PeriodSeconds(PERIOD_H1) * 10;
            
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
            // 获取支撑位对应的时间 - 使用高点时间作为中心点
            datetime supportTimeD1 = CTradeAnalyzer::GetRangeHighTime();
            
            // 计算矩形的开始和结束时间（以中心点为基准，向左右各延伸10个1小时周期）
            datetime startTimeD1 = supportTimeD1 - PeriodSeconds(PERIOD_H1) * 10;
            datetime endTimeD1 = supportTimeD1 + PeriodSeconds(PERIOD_H1) * 10;
            
            // 创建矩形
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
            // 获取压力位对应的时间 - 使用低点时间作为中心点
            datetime resistanceTime1H = CTradeAnalyzer::GetRangeLowTime();
            
            // 计算矩形的开始和结束时间（以中心点为基准，向左右各延伸10个1小时周期）
            datetime startTime1H = resistanceTime1H - PeriodSeconds(PERIOD_H1) * 10;
            datetime endTime1H = resistanceTime1H + PeriodSeconds(PERIOD_H1) * 10;
            
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
            // 获取压力位对应的时间 - 使用低点时间作为中心点
            datetime resistanceTime4H = CTradeAnalyzer::GetRangeLowTime();
            
            // 计算矩形的开始和结束时间（以中心点为基准，向左右各延伸10个1小时周期）
            datetime startTime4H = resistanceTime4H - PeriodSeconds(PERIOD_H1) * 10;
            datetime endTime4H = resistanceTime4H + PeriodSeconds(PERIOD_H1) * 10;
            
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
            // 获取压力位对应的时间 - 使用低点时间作为中心点
            datetime resistanceTimeD1 = CTradeAnalyzer::GetRangeLowTime();
            
            // 计算矩形的开始和结束时间（以中心点为基准，向左右各延伸10个1小时周期）
            datetime startTimeD1 = resistanceTimeD1 - PeriodSeconds(PERIOD_H1) * 10;
            datetime endTimeD1 = resistanceTimeD1 + PeriodSeconds(PERIOD_H1) * 10;
            
            // 创建矩形
            string rectNameD1 = "SR_Rect_D1";
            ObjectCreate(0, rectNameD1, OBJ_RECTANGLE, 0, startTimeD1, resistanceD1 + rectHeight/2, endTimeD1, resistanceD1 - rectHeight/2);
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