//+------------------------------------------------------------------+
//|                                                GraphicsUtils.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

// 引入交易分析类
#include "TradeAnalyzer.mqh"

//+------------------------------------------------------------------+
//| 图形工具类 - 用于绘制各种图形元素                                |
//+------------------------------------------------------------------+

// 全局变量 - 信息面板管理器默认属性
string  g_InfoPanelName = "InfoPanel";
color   g_InfoPanelTextColor = clrWhite;
color   g_InfoPanelBgColor = clrNavy;
int     g_InfoPanelFontSize = 9;
string  g_InfoPanelFont = "Arial";

// 全局变量 - 标签管理器默认属性
string  g_LabelFont = "Arial";
int     g_LabelFontSize = 8;
color   g_LabelColor = clrWhite;      // 当前周期标签颜色(默认对应中周期)
color   g_Label4HColor = clrOrange;   // 4小时周期标签颜色(大周期)
int     g_LabelWidth = 1;
bool    g_LabelSelectable = false;

// 全局变量 - 线条管理器默认属性
color   g_LineColor = clrRed;
int     g_LineWidth = 1;
int     g_LineStyle = STYLE_SOLID;
bool    g_LineRayLeft = false;
bool    g_LineRayRight = false;
bool    g_LineSelectable = false;

// 全局变量 - 图形管理器默认属性
color   g_ShapeBorderColor = clrBlue;
color   g_ShapeFillColor = clrAliceBlue;
int     g_ShapeWidth = 1;
int     g_ShapeStyle = STYLE_SOLID;
bool    g_ShapeSelectable = false;

//+------------------------------------------------------------------+
//| 信息面板管理类                                                   |
//+------------------------------------------------------------------+
class CInfoPanelManager
  {
public:
   // 初始化全局变量
   static void Init(string panelName = "InfoPanel", color textColor = clrWhite, color bgColor = clrNavy, int fontSize = 9)
     {
      g_InfoPanelName = panelName;
      g_InfoPanelTextColor = textColor;
      g_InfoPanelBgColor = bgColor;
      g_InfoPanelFontSize = fontSize;
      g_InfoPanelFont = "Arial";
     }
     
   // 创建交易信息面板 - 统一的面板创建方法
   static void CreateTradeInfoPanel(string panelName = "", color textColor = NULL, color bgColor = NULL)
     {
      // 使用默认值或传入的参数
      string actualPanelName = (panelName == "") ? g_InfoPanelName : panelName;
      color actualTextColor = (textColor == NULL) ? g_InfoPanelTextColor : textColor;
      color actualBgColor = (bgColor == NULL) ? g_InfoPanelBgColor : bgColor;
      
      // 删除旧的面板
      ObjectDelete(0, actualPanelName);
      
      // 获取图表宽度和高度
      int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
      
      // 面板位置和大小
      int panelWidth = 250;
      int panelHeight = 180; // 增加高度，显示多行支撑/压力信息
      int panelX = chartWidth - panelWidth - 10; // 右侧边缘留10像素间距
      int panelY = 10; // 顶部边缘留10像素间距
      
      // 创建面板背景
      ObjectCreate(0, actualPanelName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, actualPanelName, OBJPROP_XDISTANCE, panelX);
      ObjectSetInteger(0, actualPanelName, OBJPROP_YDISTANCE, panelY);
      ObjectSetInteger(0, actualPanelName, OBJPROP_XSIZE, panelWidth);
      ObjectSetInteger(0, actualPanelName, OBJPROP_YSIZE, panelHeight);
      ObjectSetInteger(0, actualPanelName, OBJPROP_BGCOLOR, actualBgColor);
      ObjectSetInteger(0, actualPanelName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, actualPanelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, actualPanelName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, actualPanelName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, actualPanelName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, actualPanelName, OBJPROP_BACK, true); // 设置为背景，确保文本显示在上面
      ObjectSetInteger(0, actualPanelName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, actualPanelName, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, actualPanelName, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, actualPanelName, OBJPROP_ZORDER, 0);
      
      // 如果交易分析器有有效数据，添加区间分析信息
      if(CTradeAnalyzer::IsValid())
        {
         // 创建区间分析文本 - 调整位置到面板顶部
         string rangeName = actualPanelName + "_Range";
         ObjectCreate(0, rangeName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, rangeName, OBJPROP_XDISTANCE, panelX + 10);
         ObjectSetInteger(0, rangeName, OBJPROP_YDISTANCE, panelY + 10); // 调整到面板顶部
         ObjectSetInteger(0, rangeName, OBJPROP_COLOR, actualTextColor);
         ObjectSetInteger(0, rangeName, OBJPROP_FONTSIZE, g_InfoPanelFontSize);
         ObjectSetInteger(0, rangeName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, rangeName, OBJPROP_ZORDER, 100); // 确保文本在最上层
         ObjectSetString(0, rangeName, OBJPROP_FONT, g_InfoPanelFont);
         ObjectSetString(0, rangeName, OBJPROP_TEXT, StringFormat("区间: %s - %s", 
                                                                DoubleToString(CTradeAnalyzer::GetRangeLow(), _Digits),
                                                                DoubleToString(CTradeAnalyzer::GetRangeHigh(), _Digits)));
         
         // 创建趋势方向文本 - 调整位置紧跟在区间分析文本下方
         string trendName = actualPanelName + "_Trend";
         ObjectCreate(0, trendName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, trendName, OBJPROP_XDISTANCE, panelX + 10);
         ObjectSetInteger(0, trendName, OBJPROP_YDISTANCE, panelY + 30); // 调整到区间分析文本下方
         ObjectSetInteger(0, trendName, OBJPROP_COLOR, actualTextColor);
         ObjectSetInteger(0, trendName, OBJPROP_FONTSIZE, g_InfoPanelFontSize);
         ObjectSetInteger(0, trendName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, trendName, OBJPROP_ZORDER, 100); // 确保文本在最上层
         ObjectSetString(0, trendName, OBJPROP_FONT, g_InfoPanelFont);
         ObjectSetString(0, trendName, OBJPROP_TEXT, StringFormat("趋势方向: %s", 
                                                                CTradeAnalyzer::GetTrendDirection()));
         
         // 计算回撤或反弹
         CTradeAnalyzer::CalculateRetracement();
         
         // 创建回撤或反弹文本 - 调整位置紧跟在趋势方向文本下方
         string retraceName = actualPanelName + "_Retrace";
         ObjectCreate(0, retraceName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, retraceName, OBJPROP_XDISTANCE, panelX + 10);
         ObjectSetInteger(0, retraceName, OBJPROP_YDISTANCE, panelY + 50); // 调整到趋势方向文本下方
         ObjectSetInteger(0, retraceName, OBJPROP_COLOR, actualTextColor);
         ObjectSetInteger(0, retraceName, OBJPROP_FONTSIZE, g_InfoPanelFontSize);
         ObjectSetInteger(0, retraceName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, retraceName, OBJPROP_ZORDER, 100); // 确保文本在最上层
         ObjectSetString(0, retraceName, OBJPROP_FONT, g_InfoPanelFont);
         ObjectSetString(0, retraceName, OBJPROP_TEXT, CTradeAnalyzer::GetRetraceDescription());
         
         // 计算多时间周期支撑和压力
         CTradeAnalyzer::CalculateSupportResistance();
         
         // 不再创建单独的支撑或压力标题文本，直接使用GetSupportResistanceDescription的返回值
         
         // 创建支撑或压力文本（包含参考点）
         string sr1HName = actualPanelName + "_SR1H";
         ObjectCreate(0, sr1HName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, sr1HName, OBJPROP_XDISTANCE, panelX + 10);
         ObjectSetInteger(0, sr1HName, OBJPROP_YDISTANCE, panelY + 70); // 调整位置
         ObjectSetInteger(0, sr1HName, OBJPROP_COLOR, actualTextColor);
         ObjectSetInteger(0, sr1HName, OBJPROP_FONTSIZE, g_InfoPanelFontSize);
         ObjectSetInteger(0, sr1HName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, sr1HName, OBJPROP_ZORDER, 100); // 确保文本在最上层
         ObjectSetString(0, sr1HName, OBJPROP_FONT, g_InfoPanelFont);
         ObjectSetString(0, sr1HName, OBJPROP_TEXT, CTradeAnalyzer::GetSupportResistanceDescription());
         
         // 创建1小时支撑或压力文本
         string sr1HValueName = actualPanelName + "_SR1HValue";
         ObjectCreate(0, sr1HValueName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, sr1HValueName, OBJPROP_XDISTANCE, panelX + 10);
         ObjectSetInteger(0, sr1HValueName, OBJPROP_YDISTANCE, panelY + 90); // 调整位置
         ObjectSetInteger(0, sr1HValueName, OBJPROP_COLOR, actualTextColor);
         ObjectSetInteger(0, sr1HValueName, OBJPROP_FONTSIZE, g_InfoPanelFontSize);
         ObjectSetInteger(0, sr1HValueName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, sr1HValueName, OBJPROP_ZORDER, 100); // 确保文本在最上层
         ObjectSetString(0, sr1HValueName, OBJPROP_FONT, g_InfoPanelFont);
         if(CTradeAnalyzer::IsUpTrend())
            ObjectSetString(0, sr1HValueName, OBJPROP_TEXT, "1H=" + DoubleToString(CTradeAnalyzer::GetSupport1H(), _Digits));
         else
            ObjectSetString(0, sr1HValueName, OBJPROP_TEXT, "1H=" + DoubleToString(CTradeAnalyzer::GetResistance1H(), _Digits));
         
         // 创建4小时支撑或压力文本
         string sr4HName = actualPanelName + "_SR4H";
         ObjectCreate(0, sr4HName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, sr4HName, OBJPROP_XDISTANCE, panelX + 10);
         ObjectSetInteger(0, sr4HName, OBJPROP_YDISTANCE, panelY + 110); // 调整位置
         ObjectSetInteger(0, sr4HName, OBJPROP_COLOR, actualTextColor);
         ObjectSetInteger(0, sr4HName, OBJPROP_FONTSIZE, g_InfoPanelFontSize);
         ObjectSetInteger(0, sr4HName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, sr4HName, OBJPROP_ZORDER, 100); // 确保文本在最上层
         ObjectSetString(0, sr4HName, OBJPROP_FONT, g_InfoPanelFont);
         ObjectSetString(0, sr4HName, OBJPROP_TEXT, CTradeAnalyzer::GetSupportResistance4HDescription());
         
         // 创建日线支撑或压力文本
         string srD1Name = actualPanelName + "_SRD1";
         ObjectCreate(0, srD1Name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, srD1Name, OBJPROP_XDISTANCE, panelX + 10);
         ObjectSetInteger(0, srD1Name, OBJPROP_YDISTANCE, panelY + 130); // 调整到4小时下方
         ObjectSetInteger(0, srD1Name, OBJPROP_COLOR, actualTextColor);
         ObjectSetInteger(0, srD1Name, OBJPROP_FONTSIZE, g_InfoPanelFontSize);
         ObjectSetInteger(0, srD1Name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, srD1Name, OBJPROP_ZORDER, 100); // 确保文本在最上层
         ObjectSetString(0, srD1Name, OBJPROP_FONT, g_InfoPanelFont);
         ObjectSetString(0, srD1Name, OBJPROP_TEXT, CTradeAnalyzer::GetSupportResistanceD1Description());
        }
      else
        {
         // 如果没有有效数据，显示提示信息
         string noDataName = actualPanelName + "_NoData";
         ObjectCreate(0, noDataName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, noDataName, OBJPROP_XDISTANCE, panelX + 10);
         ObjectSetInteger(0, noDataName, OBJPROP_YDISTANCE, panelY + 30);
         ObjectSetInteger(0, noDataName, OBJPROP_COLOR, actualTextColor);
         ObjectSetInteger(0, noDataName, OBJPROP_FONTSIZE, g_InfoPanelFontSize);
         ObjectSetInteger(0, noDataName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, noDataName, OBJPROP_ZORDER, 100); // 确保文本在最上层
         ObjectSetString(0, noDataName, OBJPROP_FONT, g_InfoPanelFont);
         ObjectSetString(0, noDataName, OBJPROP_TEXT, "暂无有效的交易区间数据");
        }
     }
     
   // 创建简单信息面板（无数据版本）
   static void CreateSimpleInfoPanel(string panelName, string message, color textColor = NULL, color bgColor = NULL)
     {
      // 使用默认值或传入的参数
      string actualPanelName = (panelName == "") ? g_InfoPanelName : panelName;
      color actualTextColor = (textColor == NULL) ? g_InfoPanelTextColor : textColor;
      color actualBgColor = (bgColor == NULL) ? g_InfoPanelBgColor : bgColor;
      
      // 删除旧的面板
      ObjectDelete(0, actualPanelName);
      
      // 获取图表宽度和高度
      int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
      
      // 面板位置和大小
      int panelWidth = 250;
      int panelHeight = 60;
      int panelX = chartWidth - panelWidth - 10; // 右侧边缘留10像素间距
      int panelY = 10; // 顶部边缘留10像素间距
      
      // 创建面板背景
      ObjectCreate(0, actualPanelName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, actualPanelName, OBJPROP_XDISTANCE, panelX);
      ObjectSetInteger(0, actualPanelName, OBJPROP_YDISTANCE, panelY);
      ObjectSetInteger(0, actualPanelName, OBJPROP_XSIZE, panelWidth);
      ObjectSetInteger(0, actualPanelName, OBJPROP_YSIZE, panelHeight);
      ObjectSetInteger(0, actualPanelName, OBJPROP_BGCOLOR, actualBgColor);
      ObjectSetInteger(0, actualPanelName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, actualPanelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, actualPanelName, OBJPROP_COLOR, clrWhite);
      
      // 创建提示文本
      string noDataName = actualPanelName + "_Message";
      ObjectCreate(0, noDataName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, noDataName, OBJPROP_XDISTANCE, panelX + 10);
      ObjectSetInteger(0, noDataName, OBJPROP_YDISTANCE, panelY + 25);
      ObjectSetInteger(0, noDataName, OBJPROP_COLOR, actualTextColor);
      ObjectSetInteger(0, noDataName, OBJPROP_FONTSIZE, g_InfoPanelFontSize);
      ObjectSetInteger(0, noDataName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, noDataName, OBJPROP_ZORDER, 100); // 确保文本在最上层
      ObjectSetString(0, noDataName, OBJPROP_FONT, g_InfoPanelFont);
      ObjectSetString(0, noDataName, OBJPROP_TEXT, message);
     }
     
   // 删除面板
   static void DeletePanel(string panelName = "")
     {
      string actualPanelName = (panelName == "") ? g_InfoPanelName : panelName;
      ObjectsDeleteAll(0, actualPanelName);
     }
     
   // 获取当前价格
   static double GetCurrentPrice()
     {
      double price = 0.0;
      
      // 获取当前品种的最新价格
      MqlTick last_tick;
      if(SymbolInfoTick(Symbol(), last_tick))
        {
         // 使用最后成交价作为当前价格
         price = last_tick.last;
         
         // 如果最后成交价为0，则使用买卖价的中间价
         if(price == 0)
           {
            price = (last_tick.bid + last_tick.ask) / 2.0;
           }
        }
      
      return price;
     }
  };

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
      
      // 获取图表时间范围
      datetime time1 = TimeCurrent() - PeriodSeconds(PERIOD_D1) * 30; // 30天前
      datetime time2 = TimeCurrent() + PeriodSeconds(PERIOD_D1) * 5;  // 未来5天
      
      // 矩形高度（价格单位）- 大幅增加高度使其更明显
      double rectHeight = 100 * _Point; // 矩形高度为100个点，可以根据需要调整
      
      // 根据趋势方向绘制支撑或压力线
      if(CTradeAnalyzer::IsUpTrend())
        {
         // 上涨趋势，绘制支撑线
         
         // 1小时支撑线 - 绿色
         double support1H = CTradeAnalyzer::GetSupport1H();
         if(support1H > 0)
           {
            // 获取支撑位对应的时间 - 使用区间高点时间作为起点
            datetime supportTime1H = CTradeAnalyzer::GetRangeHighTime();
            
            // 创建矩形
            string rectName1H = "SR_Rect_1H";
            ObjectCreate(0, rectName1H, OBJ_RECTANGLE, 0, supportTime1H, support1H + rectHeight/2, time2, support1H - rectHeight/2);
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
            // 获取支撑位对应的时间
            datetime supportTime4H = CTradeAnalyzer::GetRangeHighTime(); // 使用高点时间作为起点
            
            // 创建矩形
            string rectName4H = "SR_Rect_4H";
            ObjectCreate(0, rectName4H, OBJ_RECTANGLE, 0, supportTime4H, support4H + rectHeight/2, time2, support4H - rectHeight/2);
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
            // 获取支撑位对应的时间
            datetime supportTimeD1 = CTradeAnalyzer::GetRangeHighTime(); // 使用高点时间作为起点
            
            // 创建矩形
            string rectNameD1 = "SR_Rect_D1";
            ObjectCreate(0, rectNameD1, OBJ_RECTANGLE, 0, supportTimeD1, supportD1 + rectHeight/2, time2, supportD1 - rectHeight/2);
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
            // 创建矩形
            string rectName1H = "SR_Rect_1H";
            ObjectCreate(0, rectName1H, OBJ_RECTANGLE, 0, time1, resistance1H + rectHeight/2, time2, resistance1H - rectHeight/2);
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
            ObjectCreate(0, labelName1H, OBJ_TEXT, 0, time1, resistance1H + rectHeight);
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
            // 创建矩形
            string rectName4H = "SR_Rect_4H";
            ObjectCreate(0, rectName4H, OBJ_RECTANGLE, 0, time1, resistance4H + rectHeight/2, time2, resistance4H - rectHeight/2);
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
            ObjectCreate(0, labelName4H, OBJ_TEXT, 0, time1, resistance4H + rectHeight);
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
            // 创建矩形
            string rectNameD1 = "SR_Rect_D1";
            ObjectCreate(0, rectNameD1, OBJ_RECTANGLE, 0, time1, resistanceD1 + rectHeight/2, time2, resistanceD1 - rectHeight/2);
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
            ObjectCreate(0, labelNameD1, OBJ_TEXT, 0, time1, resistanceD1 + rectHeight);
            ObjectSetString(0, labelNameD1, OBJPROP_TEXT, "D1压力");
            ObjectSetString(0, labelNameD1, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, labelNameD1, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, labelNameD1, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, labelNameD1, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
           }
        }
     }
     
   // 创建矩形
   static void CreateRectangle(string name, datetime time1, double price1, 
                              datetime time2, double price2, 
                              color borderColor = NULL, color fillColor = NULL, 
                              int width = 0, int style = -1)
     {
      // 使用默认值或传入的参数
      color actualBorderColor = (borderColor == NULL) ? g_ShapeBorderColor : borderColor;
      color actualFillColor = (fillColor == NULL) ? g_ShapeFillColor : fillColor;
      int actualWidth = (width == 0) ? g_ShapeWidth : width;
      int actualStyle = (style == -1) ? g_ShapeStyle : style;
      
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
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, g_ShapeSelectable);
     }
     
   // 创建三角形
   static void CreateTriangle(string name, datetime time1, double price1, 
                             datetime time2, double price2, 
                             datetime time3, double price3,
                             color borderColor = NULL, color fillColor = NULL, 
                             int width = 0, int style = -1)
     {
      // 使用默认值或传入的参数
      color actualBorderColor = (borderColor == NULL) ? g_ShapeBorderColor : borderColor;
      color actualFillColor = (fillColor == NULL) ? g_ShapeFillColor : fillColor;
      int actualWidth = (width == 0) ? g_ShapeWidth : width;
      int actualStyle = (style == -1) ? g_ShapeStyle : style;
      
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
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, g_ShapeSelectable);
     }
     
   // 删除指定前缀的所有图形
   static void DeleteAllShapes(string prefix)
     {
      ObjectsDeleteAll(0, prefix, OBJ_RECTANGLE);
      ObjectsDeleteAll(0, prefix, OBJ_TRIANGLE);
      ObjectsDeleteAll(0, prefix, OBJ_ELLIPSE);
     }
  };
