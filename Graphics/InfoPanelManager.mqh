//+------------------------------------------------------------------+
//|                                              InfoPanelManager.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

// 引入交易分析类
#include "../TradeAnalyzer.mqh"
#include "../Strategies/StrategyManager.mqh"

// 全局变量 - 信息面板管理器默认属性
string  g_InfoPanelName = "InfoPanel";
color   g_InfoPanelTextColor = clrWhite;
color   g_InfoPanelBgColor = clrNavy;
int     g_InfoPanelFontSize = 9;
string  g_InfoPanelFont = "Arial";

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
      int panelHeight = 220; // 增加高度，显示多行支撑/压力信息和策略信息
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
         
         // 计算区间幅度值
         double rangeHigh = CTradeAnalyzer::GetRangeHigh();
         double rangeLow = CTradeAnalyzer::GetRangeLow();
         double rangeDiff = MathAbs(rangeHigh - rangeLow);
         
         // 格式化幅度显示
         string rangeDiffStr = "";
         
         // 根据品种特性选择合适的显示方式
         if(_Digits <= 3) // 对于点差较大的品种（如指数、股票等）
           {
            // 直接显示价格差值
            rangeDiffStr = DoubleToString(rangeDiff, _Digits);
           }
         else // 对于外汇等点差较小的品种
           {
            // 计算点数
            int rangeDiffPoints = (int)(rangeDiff / _Point);
            
            // 如果点数较大，转换为更易读的形式
            if(rangeDiffPoints >= 1000)
               rangeDiffStr = DoubleToString(rangeDiffPoints/1000.0, 1) + "K点";
            else
               rangeDiffStr = IntegerToString(rangeDiffPoints) + "点";
           }
         
         // 根据趋势方向调整区间显示顺序
         if(CTradeAnalyzer::IsUpTrend())
           {
            // 上涨趋势，显示从低到高
            ObjectSetString(0, rangeName, OBJPROP_TEXT, StringFormat("区间: %s - %s (%s)", 
                                                                   DoubleToString(CTradeAnalyzer::GetRangeLow(), _Digits),
                                                                   DoubleToString(CTradeAnalyzer::GetRangeHigh(), _Digits),
                                                                   rangeDiffStr));
           }
         else
           {
            // 下跌趋势，显示从高到低
            ObjectSetString(0, rangeName, OBJPROP_TEXT, StringFormat("区间: %s - %s (%s)", 
                                                                   DoubleToString(CTradeAnalyzer::GetRangeHigh(), _Digits),
                                                                   DoubleToString(CTradeAnalyzer::GetRangeLow(), _Digits),
                                                                   rangeDiffStr));
           }
         
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
            ObjectSetString(0, sr1HValueName, OBJPROP_TEXT, "1H=" + DoubleToString(CTradeAnalyzer::GetSupportPrice(PERIOD_H1), _Digits));
         else
            ObjectSetString(0, sr1HValueName, OBJPROP_TEXT, "1H=" + DoubleToString(CTradeAnalyzer::GetResistancePrice(PERIOD_H1), _Digits));
         
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
         
         // 创建当前区间类型文本
         string positionTypeName = actualPanelName + "_PositionType";
         ObjectCreate(0, positionTypeName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, positionTypeName, OBJPROP_XDISTANCE, panelX + 10);
         ObjectSetInteger(0, positionTypeName, OBJPROP_YDISTANCE, panelY + 150); // 调整到日线下方
         ObjectSetInteger(0, positionTypeName, OBJPROP_COLOR, actualTextColor);
         ObjectSetInteger(0, positionTypeName, OBJPROP_FONTSIZE, g_InfoPanelFontSize);
         ObjectSetInteger(0, positionTypeName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, positionTypeName, OBJPROP_ZORDER, 100); // 确保文本在最上层
         ObjectSetString(0, positionTypeName, OBJPROP_FONT, g_InfoPanelFont);
         ObjectSetString(0, positionTypeName, OBJPROP_TEXT, "区间定义:");
         
         // 创建区间定义文本
         string positionDefName = actualPanelName + "_PositionDef";
         ObjectCreate(0, positionDefName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, positionDefName, OBJPROP_XDISTANCE, panelX + 10);
         ObjectSetInteger(0, positionDefName, OBJPROP_YDISTANCE, panelY + 170); // 调整到区间类型下方
         ObjectSetInteger(0, positionDefName, OBJPROP_COLOR, actualTextColor);
         ObjectSetInteger(0, positionDefName, OBJPROP_FONTSIZE, g_InfoPanelFontSize);
         ObjectSetInteger(0, positionDefName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, positionDefName, OBJPROP_ZORDER, 100); // 确保文本在最上层
         ObjectSetString(0, positionDefName, OBJPROP_FONT, g_InfoPanelFont);
         ObjectSetString(0, positionDefName, OBJPROP_TEXT, "高位(0-33.3%) 中位(33.3-66.6%) 低位(66.6-100%)");
         
         // 创建当前策略描述文本
         string strategyDescName = actualPanelName + "_StrategyDesc";
         ObjectCreate(0, strategyDescName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, strategyDescName, OBJPROP_XDISTANCE, panelX + 10);
         ObjectSetInteger(0, strategyDescName, OBJPROP_YDISTANCE, panelY + 190); // 调整到区间定义下方
         ObjectSetInteger(0, strategyDescName, OBJPROP_COLOR, actualTextColor);
         ObjectSetInteger(0, strategyDescName, OBJPROP_FONTSIZE, g_InfoPanelFontSize);
         ObjectSetInteger(0, strategyDescName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, strategyDescName, OBJPROP_ZORDER, 100); // 确保文本在最上层
         ObjectSetString(0, strategyDescName, OBJPROP_FONT, g_InfoPanelFont);
         ObjectSetString(0, strategyDescName, OBJPROP_TEXT, "当前策略: " + (CTradeAnalyzer::IsUpTrend() ? "上涨趋势" : "下跌趋势"));
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