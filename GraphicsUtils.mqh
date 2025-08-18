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

//+------------------------------------------------------------------+
//| 信息面板管理类                                                   |
//+------------------------------------------------------------------+
class CInfoPanelManager
  {
private:
   // 默认面板属性
   static string  DefaultPanelName;
   static color   DefaultTextColor;
   static color   DefaultBgColor;
   static int     DefaultFontSize;
   static string  DefaultFont;

public:
   // 初始化静态变量
   static void Init(string panelName = "InfoPanel", color textColor = clrWhite, color bgColor = clrNavy, int fontSize = 9)
     {
      DefaultPanelName = panelName;
      DefaultTextColor = textColor;
      DefaultBgColor = bgColor;
      DefaultFontSize = fontSize;
      DefaultFont = "Arial";
     }
     
   // 创建交易信息面板
   static void CreateTradeInfoPanel(string panelName = "", color textColor = NULL, color bgColor = NULL)
     {
      // 使用默认值或传入的参数
      string actualPanelName = (panelName == "") ? DefaultPanelName : panelName;
      color actualTextColor = (textColor == NULL) ? DefaultTextColor : textColor;
      color actualBgColor = (bgColor == NULL) ? DefaultBgColor : bgColor;
      
      // 删除旧的面板
      ObjectDelete(0, actualPanelName);
      
      // 获取图表宽度和高度
      int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
      
      // 面板位置和大小
      int panelWidth = 250;
      int panelHeight = 120;
      int panelX = chartWidth - panelWidth - 10; // 右侧边缘留10像素间距
      int panelY = 140; // 顶部边缘留140像素间距（在信息面板下方）
      
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
      
      // 创建面板标题
      string titleName = actualPanelName + "_Title";
      ObjectCreate(0, titleName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, titleName, OBJPROP_XDISTANCE, panelX + 10);
      ObjectSetInteger(0, titleName, OBJPROP_YDISTANCE, panelY + 15);
      ObjectSetInteger(0, titleName, OBJPROP_COLOR, actualTextColor);
      ObjectSetInteger(0, titleName, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, titleName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, titleName, OBJPROP_ZORDER, 100); // 确保文本在最上层
      ObjectSetString(0, titleName, OBJPROP_FONT, DefaultFont);
      ObjectSetString(0, titleName, OBJPROP_TEXT, "交易区间分析");
      
      // 获取当前价格
      double currentPrice = GetCurrentPrice();
      
      // 如果交易分析器有有效数据，添加区间分析信息
      if(CTradeAnalyzer::IsValid())
        {
         // 创建区间分析文本
         string rangeName = actualPanelName + "_Range";
         ObjectCreate(0, rangeName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, rangeName, OBJPROP_XDISTANCE, panelX + 10);
         ObjectSetInteger(0, rangeName, OBJPROP_YDISTANCE, panelY + 40);
         ObjectSetInteger(0, rangeName, OBJPROP_COLOR, actualTextColor);
         ObjectSetInteger(0, rangeName, OBJPROP_FONTSIZE, DefaultFontSize);
         ObjectSetInteger(0, rangeName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, rangeName, OBJPROP_ZORDER, 100); // 确保文本在最上层
         ObjectSetString(0, rangeName, OBJPROP_FONT, DefaultFont);
         ObjectSetString(0, rangeName, OBJPROP_TEXT, StringFormat("区间: %s - %s", 
                                                                DoubleToString(CTradeAnalyzer::GetRangeLow(), _Digits),
                                                                DoubleToString(CTradeAnalyzer::GetRangeHigh(), _Digits)));
         
         // 创建趋势方向文本
         string trendName = actualPanelName + "_Trend";
         ObjectCreate(0, trendName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, trendName, OBJPROP_XDISTANCE, panelX + 10);
         ObjectSetInteger(0, trendName, OBJPROP_YDISTANCE, panelY + 60);
         ObjectSetInteger(0, trendName, OBJPROP_COLOR, actualTextColor);
         ObjectSetInteger(0, trendName, OBJPROP_FONTSIZE, DefaultFontSize);
         ObjectSetInteger(0, trendName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, trendName, OBJPROP_ZORDER, 100); // 确保文本在最上层
         ObjectSetString(0, trendName, OBJPROP_FONT, DefaultFont);
         ObjectSetString(0, trendName, OBJPROP_TEXT, StringFormat("趋势方向: %s", 
                                                                CTradeAnalyzer::GetTrendDirection()));
         
         // 创建区间位置文本
         string positionName = actualPanelName + "_Position";
         ObjectCreate(0, positionName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, positionName, OBJPROP_XDISTANCE, panelX + 10);
         ObjectSetInteger(0, positionName, OBJPROP_YDISTANCE, panelY + 80);
         ObjectSetInteger(0, positionName, OBJPROP_COLOR, actualTextColor);
         ObjectSetInteger(0, positionName, OBJPROP_FONTSIZE, DefaultFontSize);
         ObjectSetInteger(0, positionName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, positionName, OBJPROP_ZORDER, 100); // 确保文本在最上层
         ObjectSetString(0, positionName, OBJPROP_FONT, DefaultFont);
         ObjectSetString(0, positionName, OBJPROP_TEXT, StringFormat("当前位置: 区间的 %s%%", 
                                                                   DoubleToString(CTradeAnalyzer::GetPricePositionInRange(currentPrice), 2)));
         
         // 创建距离高低点文本
         string distanceName = actualPanelName + "_Distance";
         ObjectCreate(0, distanceName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, distanceName, OBJPROP_XDISTANCE, panelX + 10);
         ObjectSetInteger(0, distanceName, OBJPROP_YDISTANCE, panelY + 100);
         ObjectSetInteger(0, distanceName, OBJPROP_COLOR, actualTextColor);
         ObjectSetInteger(0, distanceName, OBJPROP_FONTSIZE, DefaultFontSize);
         ObjectSetInteger(0, distanceName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, distanceName, OBJPROP_ZORDER, 100); // 确保文本在最上层
         ObjectSetString(0, distanceName, OBJPROP_FONT, DefaultFont);
         ObjectSetString(0, distanceName, OBJPROP_TEXT, StringFormat("距高点: %s%%, 距低点: %s%%", 
                                                                    DoubleToString(CTradeAnalyzer::GetDistanceToHigh(currentPrice), 2),
                                                                    DoubleToString(CTradeAnalyzer::GetDistanceToLow(currentPrice), 2)));
        }
      else
        {
         // 如果没有有效数据，显示提示信息
         string noDataName = actualPanelName + "_NoData";
         ObjectCreate(0, noDataName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, noDataName, OBJPROP_XDISTANCE, panelX + 10);
         ObjectSetInteger(0, noDataName, OBJPROP_YDISTANCE, panelY + 60);
         ObjectSetInteger(0, noDataName, OBJPROP_COLOR, actualTextColor);
         ObjectSetInteger(0, noDataName, OBJPROP_FONTSIZE, DefaultFontSize);
         ObjectSetInteger(0, noDataName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, noDataName, OBJPROP_ZORDER, 100); // 确保文本在最上层
         ObjectSetString(0, noDataName, OBJPROP_FONT, DefaultFont);
         ObjectSetString(0, noDataName, OBJPROP_TEXT, "暂无有效的交易区间数据");
        }
     }
     
   // 创建信息面板
   static void CreateInfoPanel(string panelName, CZigzagExtremumPoint &currentPoints[], CZigzagExtremumPoint &h4Points[], 
                              bool hasCurrentPoints, bool has4HPoints, color textColor = NULL, color bgColor = NULL)
     {
      // 使用默认值或传入的参数
      string actualPanelName = (panelName == "") ? DefaultPanelName : panelName;
      color actualTextColor = (textColor == NULL) ? DefaultTextColor : textColor;
      color actualBgColor = (bgColor == NULL) ? DefaultBgColor : bgColor;
      
      // 删除旧的面板
      ObjectDelete(0, actualPanelName);
      
      // 获取图表宽度和高度
      int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
      int chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
      
      // 面板位置和大小
      int panelWidth = 250;
      int panelHeight = 160; // 增加高度以容纳更多文本
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
      
      // 创建面板标题
      string titleName = actualPanelName + "_Title";
      ObjectCreate(0, titleName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, titleName, OBJPROP_XDISTANCE, panelX + 10);
      ObjectSetInteger(0, titleName, OBJPROP_YDISTANCE, panelY + 15);
      ObjectSetInteger(0, titleName, OBJPROP_COLOR, actualTextColor);
      ObjectSetInteger(0, titleName, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, titleName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, titleName, OBJPROP_ZORDER, 100); // 确保文本在最上层
      ObjectSetString(0, titleName, OBJPROP_FONT, DefaultFont);
      ObjectSetString(0, titleName, OBJPROP_TEXT, "4小时周期极点分析");
      
      // 获取当前价格
      double currentPrice = GetCurrentPrice();
      
      // 获取4H周期最近的极点值
      if(has4HPoints && ArraySize(h4Points) >= 1)
        {
         // 获取时间上离现在最近的极点
         CZigzagExtremumPoint lastPoint;
         datetime currentTime = TimeCurrent();
         datetime nearestTime = 0;
         int nearestIndex = -1;
         
         // 遍历所有极点，找到时间上最接近当前时间的点
         for(int i = 0; i < ArraySize(h4Points); i++)
           {
            // 如果这个点的时间比之前找到的点更接近当前时间
            if(nearestIndex == -1 || MathAbs(currentTime - h4Points[i].Time()) < MathAbs(currentTime - nearestTime))
              {
               nearestTime = h4Points[i].Time();
               nearestIndex = i;
              }
           }
         
         // 确保找到了有效的极点
         if(nearestIndex >= 0)
           {
            lastPoint = h4Points[nearestIndex];
           }
         else
           {
            // 如果没有找到有效的极点，使用数组的最后一个元素
            lastPoint = h4Points[ArraySize(h4Points) - 1];
           }
         
         // 计算从最近极点到当前价格的变化
         double priceDiff = currentPrice - lastPoint.Value();
         double pricePercent = 0;
         if(lastPoint.Value() != 0)
            pricePercent = (priceDiff / lastPoint.Value()) * 100.0;
         
         // 根据极点类型确定是回撤还是反弹
         string moveType = "";
         if(lastPoint.IsPeak()) // 如果最近的极点是峰值
           {
            moveType = priceDiff < 0 ? "回撤" : "继续上涨";
           }
         else // 如果最近的极点是谷值
           {
            moveType = priceDiff > 0 ? "反弹" : "继续下跌";
           }
         
         // 创建极点信息文本
         string pointName = actualPanelName + "_Point";
         ObjectCreate(0, pointName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, pointName, OBJPROP_XDISTANCE, panelX + 10);
         ObjectSetInteger(0, pointName, OBJPROP_YDISTANCE, panelY + 40);
         ObjectSetInteger(0, pointName, OBJPROP_COLOR, actualTextColor);
         ObjectSetInteger(0, pointName, OBJPROP_FONTSIZE, DefaultFontSize);
         ObjectSetInteger(0, pointName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, pointName, OBJPROP_ZORDER, 100); // 确保文本在最上层
         ObjectSetString(0, pointName, OBJPROP_FONT, DefaultFont);
         ObjectSetString(0, pointName, OBJPROP_TEXT, StringFormat("最近极点: %s (%s)", 
                                                                DoubleToString(lastPoint.Value(), _Digits),
                                                                lastPoint.IsPeak() ? "峰值" : "谷值"));
         
         // 创建趋势文本
         string trendName = actualPanelName + "_Trend";
         ObjectCreate(0, trendName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, trendName, OBJPROP_XDISTANCE, panelX + 10);
         ObjectSetInteger(0, trendName, OBJPROP_YDISTANCE, panelY + 60);
         ObjectSetInteger(0, trendName, OBJPROP_COLOR, actualTextColor);
         ObjectSetInteger(0, trendName, OBJPROP_FONTSIZE, DefaultFontSize);
         ObjectSetInteger(0, trendName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, trendName, OBJPROP_ZORDER, 100); // 确保文本在最上层
         ObjectSetString(0, trendName, OBJPROP_FONT, DefaultFont);
         ObjectSetString(0, trendName, OBJPROP_TEXT, StringFormat("当前价格: %s (%s)", 
                                                                DoubleToString(currentPrice, _Digits),
                                                                moveType));
         
         // 创建百分比文本
         string percentName = actualPanelName + "_Percent";
         ObjectCreate(0, percentName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, percentName, OBJPROP_XDISTANCE, panelX + 10);
         ObjectSetInteger(0, percentName, OBJPROP_YDISTANCE, panelY + 80);
         ObjectSetInteger(0, percentName, OBJPROP_COLOR, actualTextColor);
         ObjectSetInteger(0, percentName, OBJPROP_FONTSIZE, DefaultFontSize);
         ObjectSetInteger(0, percentName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, percentName, OBJPROP_ZORDER, 100); // 确保文本在最上层
         ObjectSetString(0, percentName, OBJPROP_FONT, DefaultFont);
         ObjectSetString(0, percentName, OBJPROP_TEXT, StringFormat("%s幅度: %s%%", 
                                                                  moveType,
                                                                  DoubleToString(MathAbs(pricePercent), 2)));
         
         // 创建时间文本
         string timeName = actualPanelName + "_Time";
         ObjectCreate(0, timeName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, timeName, OBJPROP_XDISTANCE, panelX + 10);
         ObjectSetInteger(0, timeName, OBJPROP_YDISTANCE, panelY + 100);
         ObjectSetInteger(0, timeName, OBJPROP_COLOR, actualTextColor);
         ObjectSetInteger(0, timeName, OBJPROP_FONTSIZE, DefaultFontSize);
         ObjectSetInteger(0, timeName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, timeName, OBJPROP_ZORDER, 100); // 确保文本在最上层
         ObjectSetString(0, timeName, OBJPROP_FONT, DefaultFont);
         ObjectSetString(0, timeName, OBJPROP_TEXT, StringFormat("极点时间: %s", TimeToString(lastPoint.Time(), TIME_DATE|TIME_MINUTES)));
         
         // 添加额外的区间分析信息（如果需要）
         // 注意：这里不再直接依赖CTradeAnalyzer类，而是通过参数传递或其他方式获取数据
         
         // 创建区间分析文本（示例）
         string rangeName = actualPanelName + "_Range";
         ObjectCreate(0, rangeName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, rangeName, OBJPROP_XDISTANCE, panelX + 10);
         ObjectSetInteger(0, rangeName, OBJPROP_YDISTANCE, panelY + 120);
         ObjectSetInteger(0, rangeName, OBJPROP_COLOR, actualTextColor);
         ObjectSetInteger(0, rangeName, OBJPROP_FONTSIZE, DefaultFontSize);
         ObjectSetInteger(0, rangeName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, rangeName, OBJPROP_ZORDER, 100); // 确保文本在最上层
         ObjectSetString(0, rangeName, OBJPROP_FONT, DefaultFont);
         ObjectSetString(0, rangeName, OBJPROP_TEXT, "区间分析 (见交易分析器)");
        }
      else
        {
         // 如果没有足够的极点，显示提示信息
         string noDataName = actualPanelName + "_NoData";
         ObjectCreate(0, noDataName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, noDataName, OBJPROP_XDISTANCE, panelX + 10);
         ObjectSetInteger(0, noDataName, OBJPROP_YDISTANCE, panelY + 40);
         ObjectSetInteger(0, noDataName, OBJPROP_COLOR, actualTextColor);
         ObjectSetInteger(0, noDataName, OBJPROP_FONTSIZE, DefaultFontSize);
         ObjectSetInteger(0, noDataName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, noDataName, OBJPROP_ZORDER, 100); // 确保文本在最上层
         ObjectSetString(0, noDataName, OBJPROP_FONT, DefaultFont);
         ObjectSetString(0, noDataName, OBJPROP_TEXT, "暂无足够的极点数据");
        }
     }
     
   // 创建简单信息面板（无数据版本）
   static void CreateSimpleInfoPanel(string panelName, string message, color textColor = NULL, color bgColor = NULL)
     {
      // 使用默认值或传入的参数
      string actualPanelName = (panelName == "") ? DefaultPanelName : panelName;
      color actualTextColor = (textColor == NULL) ? DefaultTextColor : textColor;
      color actualBgColor = (bgColor == NULL) ? DefaultBgColor : bgColor;
      
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
      ObjectSetInteger(0, noDataName, OBJPROP_FONTSIZE, DefaultFontSize);
      ObjectSetInteger(0, noDataName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, noDataName, OBJPROP_ZORDER, 100); // 确保文本在最上层
      ObjectSetString(0, noDataName, OBJPROP_FONT, DefaultFont);
      ObjectSetString(0, noDataName, OBJPROP_TEXT, message);
     }
     
   // 删除面板
   static void DeletePanel(string panelName = "")
     {
      string actualPanelName = (panelName == "") ? DefaultPanelName : panelName;
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

// 初始化静态成员变量
string CInfoPanelManager::DefaultPanelName = "InfoPanel";
color CInfoPanelManager::DefaultTextColor = clrWhite;
color CInfoPanelManager::DefaultBgColor = clrNavy;
int CInfoPanelManager::DefaultFontSize = 9;
string CInfoPanelManager::DefaultFont = "Arial";


//+------------------------------------------------------------------+
//| 标签管理静态类                                                   |
//+------------------------------------------------------------------+
class CLabelManager
  {
private:
   // 默认标签属性
   static string  DefaultFont;
   static int     DefaultFontSize;
   static color   DefaultColor;      // 当前周期标签颜色(默认对应中周期)
   static color   Default4HColor;    // 4小时周期标签颜色(大周期)
   static int     DefaultWidth;
   static bool    DefaultSelectable;

public:
   // 初始化静态变量
   static void Init(color labelColor = clrWhite, color label4HColor = clrOrange)
     {
      DefaultFont = "Arial";
      DefaultFontSize = 8;
      DefaultColor = labelColor;     // 当前周期(中周期)
      Default4HColor = label4HColor; // 大周期
      DefaultWidth = 1;
      DefaultSelectable = false;
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
         actualColor = Default4HColor;
      else
         actualColor = DefaultColor; // 当前周期(中周期)
         
      string actualFont = (font == NULL) ? DefaultFont : font;
      int actualFontSize = (fontSize == 0) ? DefaultFontSize : fontSize;
      
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
      ObjectSetInteger(0, name, OBJPROP_WIDTH, DefaultWidth);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, DefaultSelectable);
      
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

// 初始化静态成员变量
string CLabelManager::DefaultFont = "Arial";
int CLabelManager::DefaultFontSize = 8;
color CLabelManager::DefaultColor = clrWhite;    // 当前周期(中周期)
color CLabelManager::Default4HColor = clrOrange; // 大周期
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