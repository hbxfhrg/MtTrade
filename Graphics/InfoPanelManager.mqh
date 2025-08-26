//+------------------------------------------------------------------+
//|                                              InfoPanelManager.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

// 引入交易分析类和全局实例
#include "../GlobalInstances.mqh"
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
      int panelHeight = 150; // 减小高度，因为移除了支撑/压力信息
      int panelX = 10; // 左侧边缘留10像素间距
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
      if(g_tradeAnalyzer.IsValid())
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
         double rangeHigh = g_tradeAnalyzer.GetRangeHigh();
         double rangeLow = g_tradeAnalyzer.GetRangeLow();
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
         if(g_tradeAnalyzer.IsUpTrend())
           {
            // 上涨趋势，显示从低到高
            ObjectSetString(0, rangeName, OBJPROP_TEXT, StringFormat("区间: %s - %s (%s)", 
                                                                   DoubleToString(g_tradeAnalyzer.GetRangeLow(), _Digits),
                                                                   DoubleToString(g_tradeAnalyzer.GetRangeHigh(), _Digits),
                                                                   rangeDiffStr));
           }
         else
           {
            // 下跌趋势，显示从高到低
            ObjectSetString(0, rangeName, OBJPROP_TEXT, StringFormat("区间: %s - %s (%s)", 
                                                                   DoubleToString(g_tradeAnalyzer.GetRangeHigh(), _Digits),
                                                                   DoubleToString(g_tradeAnalyzer.GetRangeLow(), _Digits),
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
                                                                g_tradeAnalyzer.GetTrendDirection()));
         
         // 计算回撤或反弹
         g_tradeAnalyzer.CalculateRetracement();
         
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
         ObjectSetString(0, retraceName, OBJPROP_TEXT, g_tradeAnalyzer.GetRetraceDescription());
         
         // 计算多时间周期支撑和压力 - 虽然不显示，但仍然需要计算，因为可能在图表上绘制
         g_tradeAnalyzer.CalculateSupportResistance();
         
         // 创建区间定义标题文本
         string positionTypeName = actualPanelName + "_PositionType";
         ObjectCreate(0, positionTypeName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, positionTypeName, OBJPROP_XDISTANCE, panelX + 10);
         ObjectSetInteger(0, positionTypeName, OBJPROP_YDISTANCE, panelY + 70); // 调整位置
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
         ObjectSetInteger(0, positionDefName, OBJPROP_YDISTANCE, panelY + 90); // 调整位置
         ObjectSetInteger(0, positionDefName, OBJPROP_COLOR, actualTextColor);
         ObjectSetInteger(0, positionDefName, OBJPROP_FONTSIZE, g_InfoPanelFontSize);
         ObjectSetInteger(0, positionDefName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, positionDefName, OBJPROP_ZORDER, 100); // 确保文本在最上层
         ObjectSetString(0, positionDefName, OBJPROP_FONT, g_InfoPanelFont);
         ObjectSetString(0, positionDefName, OBJPROP_TEXT, "高位(0-33.3%) 中位(33.3-66.6%) 低位(66.6-100%)");
         
         // 获取当前回撤/反弹百分比
         double retracePercent = g_tradeAnalyzer.GetRetracePercent();
         
         // 确定当前所处区间
         string currentPosition = "";
         string strategyName = "";
         
         if(retracePercent >= 0.0 && retracePercent < 33.3)
         {
            currentPosition = "高位区间";
            strategyName = "高位策略";
         }
         else if(retracePercent >= 33.3 && retracePercent <= 66.6)
         {
            currentPosition = "中位区间";
            strategyName = "中位策略";
         }
         else if(retracePercent > 66.6 && retracePercent <= 100.0)
         {
            currentPosition = "低位区间";
            strategyName = "低位策略";
         }
         else
         {
            currentPosition = "未知区间";
            strategyName = "无适用策略";
         }
         
         // 创建当前区间位置文本
         string currentPosName = actualPanelName + "_CurrentPos";
         ObjectCreate(0, currentPosName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, currentPosName, OBJPROP_XDISTANCE, panelX + 10);
         ObjectSetInteger(0, currentPosName, OBJPROP_YDISTANCE, panelY + 110); // 调整位置
         ObjectSetInteger(0, currentPosName, OBJPROP_COLOR, actualTextColor);
         ObjectSetInteger(0, currentPosName, OBJPROP_FONTSIZE, g_InfoPanelFontSize);
         ObjectSetInteger(0, currentPosName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, currentPosName, OBJPROP_ZORDER, 100); // 确保文本在最上层
         ObjectSetString(0, currentPosName, OBJPROP_FONT, g_InfoPanelFont);
         ObjectSetString(0, currentPosName, OBJPROP_TEXT, StringFormat("当前位置: %s (%.2f%%)", currentPosition, retracePercent));
         
         // 创建当前策略描述文本
         string strategyDescName = actualPanelName + "_StrategyDesc";
         ObjectCreate(0, strategyDescName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, strategyDescName, OBJPROP_XDISTANCE, panelX + 10);
         ObjectSetInteger(0, strategyDescName, OBJPROP_YDISTANCE, panelY + 130); // 调整位置
         ObjectSetInteger(0, strategyDescName, OBJPROP_COLOR, actualTextColor);
         ObjectSetInteger(0, strategyDescName, OBJPROP_FONTSIZE, g_InfoPanelFontSize);
         ObjectSetInteger(0, strategyDescName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, strategyDescName, OBJPROP_ZORDER, 100); // 确保文本在最上层
         ObjectSetString(0, strategyDescName, OBJPROP_FONT, g_InfoPanelFont);
         ObjectSetString(0, strategyDescName, OBJPROP_TEXT, StringFormat("适用策略: %s (%s)", 
                                                                      strategyName, 
                                                                      g_tradeAnalyzer.IsUpTrend() ? "上涨趋势" : "下跌趋势"));
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
     
   // 在现有面板上添加线段信息
   static void AddSegmentInfo(string panelName, CZigzagSegment* &uptrendSegments[], CZigzagSegment* &downtrendSegments[], color textColor = NULL)
     {
      // 使用默认值或传入的参数
      string actualPanelName = (panelName == "") ? g_InfoPanelName : panelName;
      color actualTextColor = (textColor == NULL) ? g_InfoPanelTextColor : textColor;
      
      // 获取面板位置和大小
      int panelX = (int)ObjectGetInteger(0, actualPanelName, OBJPROP_XDISTANCE);
      int panelY = (int)ObjectGetInteger(0, actualPanelName, OBJPROP_YDISTANCE);
      int panelWidth = (int)ObjectGetInteger(0, actualPanelName, OBJPROP_XSIZE);
      int panelHeight = (int)ObjectGetInteger(0, actualPanelName, OBJPROP_YSIZE);
      
      // 增加面板高度以容纳线段信息
      ObjectSetInteger(0, actualPanelName, OBJPROP_YSIZE, panelHeight + 80);
      
      // 创建线段信息标题
      string segmentTitleName = actualPanelName + "_SegmentTitle";
      ObjectCreate(0, segmentTitleName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, segmentTitleName, OBJPROP_XDISTANCE, panelX + 10);
      ObjectSetInteger(0, segmentTitleName, OBJPROP_YDISTANCE, panelY + panelHeight + 10);
      ObjectSetInteger(0, segmentTitleName, OBJPROP_COLOR, actualTextColor);
      ObjectSetInteger(0, segmentTitleName, OBJPROP_FONTSIZE, g_InfoPanelFontSize);
      ObjectSetInteger(0, segmentTitleName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, segmentTitleName, OBJPROP_ZORDER, 100);
      ObjectSetString(0, segmentTitleName, OBJPROP_FONT, g_InfoPanelFont);
      ObjectSetString(0, segmentTitleName, OBJPROP_TEXT, StringFormat("1小时线段: 上涨%d个, 下跌%d个", 
                                                                    ArraySize(uptrendSegments), 
                                                                    ArraySize(downtrendSegments)));
      
      // 创建上涨线段信息
      string uptrendName = actualPanelName + "_UptrendSegments";
      ObjectCreate(0, uptrendName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, uptrendName, OBJPROP_XDISTANCE, panelX + 10);
      ObjectSetInteger(0, uptrendName, OBJPROP_YDISTANCE, panelY + panelHeight + 30);
      ObjectSetInteger(0, uptrendName, OBJPROP_COLOR, actualTextColor);
      ObjectSetInteger(0, uptrendName, OBJPROP_FONTSIZE, g_InfoPanelFontSize);
      ObjectSetInteger(0, uptrendName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, uptrendName, OBJPROP_ZORDER, 100);
      ObjectSetString(0, uptrendName, OBJPROP_FONT, g_InfoPanelFont);
      
      // 构建上涨线段信息文本
      string uptrendText = "上涨线段: ";
      int maxUptrend = MathMin(3, ArraySize(uptrendSegments)); // 最多显示3个上涨线段
      
      for(int i = 0; i < maxUptrend; i++)
      {
         if(uptrendSegments[i] != NULL)
         {
            // 线段方向是从过去向未来，所以起点是过去，终点是未来
            uptrendText += StringFormat("%s→%s ", 
                           DoubleToString(uptrendSegments[i].StartPrice(), _Digits),
                           DoubleToString(uptrendSegments[i].EndPrice(), _Digits));
         }
      }
      
      ObjectSetString(0, uptrendName, OBJPROP_TEXT, uptrendText);
      
      // 创建下跌线段信息
      string downtrendName = actualPanelName + "_DowntrendSegments";
      ObjectCreate(0, downtrendName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, downtrendName, OBJPROP_XDISTANCE, panelX + 10);
      ObjectSetInteger(0, downtrendName, OBJPROP_YDISTANCE, panelY + panelHeight + 50);
      ObjectSetInteger(0, downtrendName, OBJPROP_COLOR, actualTextColor);
      ObjectSetInteger(0, downtrendName, OBJPROP_FONTSIZE, g_InfoPanelFontSize);
      ObjectSetInteger(0, downtrendName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, downtrendName, OBJPROP_ZORDER, 100);
      ObjectSetString(0, downtrendName, OBJPROP_FONT, g_InfoPanelFont);
      
      // 构建下跌线段信息文本
      string downtrendText = "下跌线段: ";
      int maxDowntrend = MathMin(3, ArraySize(downtrendSegments)); // 最多显示3个下跌线段
      
      for(int i = 0; i < maxDowntrend; i++)
      {
         if(downtrendSegments[i] != NULL)
         {
            // 线段方向是从过去向未来，所以起点是过去，终点是未来
            downtrendText += StringFormat("%s→%s ", 
                            DoubleToString(downtrendSegments[i].StartPrice(), _Digits),
                            DoubleToString(downtrendSegments[i].EndPrice(), _Digits));
         }
      }
      
      ObjectSetString(0, downtrendName, OBJPROP_TEXT, downtrendText);
     }
  };
