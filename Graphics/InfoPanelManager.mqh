//+------------------------------------------------------------------+
//|                                              InfoPanelManager.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

#include "../GlobalInstances.mqh"
#include "../Strategies/StrategyManager.mqh"

// 全局面板属性
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
    // 初始化面板属性
    static void Init(string panelName="InfoPanel", color textColor=clrWhite, color bgColor=clrNavy, int fontSize=9)
    {
        g_InfoPanelName = panelName;
        g_InfoPanelTextColor = textColor;
        g_InfoPanelBgColor = bgColor;
        g_InfoPanelFontSize = fontSize;
        g_InfoPanelFont = "Arial";
    }

    // 创建交易信息面板（主方法）
    static void CreateTradeInfoPanel(string panelName="", color textColor=NULL, color bgColor=NULL)
    {
        string actualPanelName = (panelName == "") ? g_InfoPanelName : panelName;
        color actualTextColor = (textColor == NULL) ? g_InfoPanelTextColor : textColor;
        color actualBgColor = (bgColor == NULL) ? g_InfoPanelBgColor : bgColor;

        // 删除旧面板
        ObjectDelete(0, actualPanelName);

        // 面板基础设置
        int panelWidth = 250;
        int panelHeight = 320;  // 增加高度容纳所有线段信息
        int panelX = 10;
        int panelY = 10;

        // 创建面板背景
        CreatePanelBackground(actualPanelName, panelX, panelY, panelWidth, panelHeight, actualBgColor);

        // 显示交易数据
        if(g_tradeAnalyzer.IsValid())
        {
            // 显示核心交易信息
            DisplayCoreInfo(actualPanelName, panelX, panelY, actualTextColor);
            
            // 显示线段信息
            DisplaySegmentInfo(actualPanelName, panelX, panelY, actualTextColor);
        }
        else
        {
            DisplayNoDataMessage(actualPanelName, panelX, panelY, actualTextColor);
        }
    }

    // 创建简单信息面板（无数据版本）
    static void CreateSimpleInfoPanel(string panelName, string message, color textColor=NULL, color bgColor=NULL)
    {
        string actualPanelName = (panelName == "") ? g_InfoPanelName : panelName;
        color actualTextColor = (textColor == NULL) ? g_InfoPanelTextColor : textColor;
        color actualBgColor = (bgColor == NULL) ? g_InfoPanelBgColor : bgColor;

        // 删除旧面板
        ObjectDelete(0, actualPanelName);

        // 创建面板背景
        int panelWidth = 250;
        int panelHeight = 60;
        int panelX = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) - panelWidth - 10;
        int panelY = 10;

        ObjectCreate(0, actualPanelName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, actualPanelName, OBJPROP_XDISTANCE, panelX);
        ObjectSetInteger(0, actualPanelName, OBJPROP_YDISTANCE, panelY);
        ObjectSetInteger(0, actualPanelName, OBJPROP_XSIZE, panelWidth);
        ObjectSetInteger(0, actualPanelName, OBJPROP_YSIZE, panelHeight);
        ObjectSetInteger(0, actualPanelName, OBJPROP_BGCOLOR, actualBgColor);

        // 显示消息
        string labelName = actualPanelName + "_Message";
        ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, panelX + 10);
        ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, panelY + 20);
        ObjectSetInteger(0, labelName, OBJPROP_COLOR, actualTextColor);
        ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, g_InfoPanelFontSize);
        ObjectSetString(0, labelName, OBJPROP_FONT, g_InfoPanelFont);
        ObjectSetString(0, labelName, OBJPROP_TEXT, message);
    }

    // 删除面板
    static void DeletePanel(string panelName="")
    {
        string actualPanelName = (panelName == "") ? g_InfoPanelName : panelName;
        ObjectsDeleteAll(0, actualPanelName);
    }

    // 获取当前价格
    static double GetCurrentPrice()
    {
        MqlTick last_tick;
        if(SymbolInfoTick(Symbol(), last_tick))
        {
            return (last_tick.last != 0) ? last_tick.last : (last_tick.bid + last_tick.ask)/2;
        }
        return 0.0;
    }

private:
    // 创建面板背景
    static void CreatePanelBackground(string name, int x, int y, int width, int height, color bgColor)
    {
        ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
        ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
        ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
        ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
    }

    // 显示核心交易信息
    static void DisplayCoreInfo(string panelName, int panelX, int panelY, color textColor)
    {
        // 区间信息
        string rangeName = panelName + "_Range";
        CreateInfoLabel(rangeName, panelX + 10, panelY + 10, textColor,
                      StringFormat("区间: %s - %s",
                                  DoubleToString(g_tradeAnalyzer.GetRangeLow(), _Digits),
                                  DoubleToString(g_tradeAnalyzer.GetRangeHigh(), _Digits)));

        // 趋势信息
        string trendName = panelName + "_Trend";
        CreateInfoLabel(trendName, panelX + 10, panelY + 30, textColor,
                      "趋势方向: " + g_tradeAnalyzer.GetTrendDirection());

        // 回撤信息
        g_tradeAnalyzer.CalculateRetracement();
        string retraceName = panelName + "_Retrace";
        CreateInfoLabel(retraceName, panelX + 10, panelY + 50, textColor,
                      g_tradeAnalyzer.GetRetraceDescription());

        // 参考价格
        string priceName = panelName + "_Price";
        CreateInfoLabel(priceName, panelX + 10, panelY + 70, textColor,
                      "参考价: " + DoubleToString(g_tradeAnalyzer.GetTradeBasePrice(), _Digits));
    }

    // 显示线段信息
    static void DisplaySegmentInfo(string panelName, int panelX, int panelY, color textColor)
    {
        // 5分钟线段（左侧）
        string m5LeftName = panelName + "_M5_Left";
        CreateInfoLabel(m5LeftName, panelX + 10, panelY + 90, textColor, "5分钟线段(左): 加载中...");

        // 5分钟线段（右侧）
        string m5RightName = panelName + "_M5_Right";
        CreateInfoLabel(m5RightName, panelX + 10, panelY + 110, textColor, "5分钟线段(右): 加载中...");

        // 1小时线段（左侧）
        string h1LeftName = panelName + "_H1_Left";
        CreateInfoLabel(h1LeftName, panelX + 10, panelY + 130, textColor, "1小时线段(左): 加载中...");

        // 1小时线段（右侧）
        string h1RightName = panelName + "_H1_Right";
        CreateInfoLabel(h1RightName, panelX + 10, panelY + 150, textColor, "1小时线段(右): 加载中...");

        // 更新线段数据
        UpdateSegmentData(panelName);
    }

    // 更新线段数据
    static void UpdateSegmentData(string panelName)
    {
        // 获取当前4小时主交易线段
        CZigzagSegment* currentMainSegment = g_tradeAnalyzer.GetCurrentSegment();
        if(currentMainSegment == NULL)
            return;
            
        // 获取交易基准价格
        double tradeBasePrice = g_tradeAnalyzer.GetTradeBasePrice();
        if(tradeBasePrice <= 0.0)
            return;
            
        // 获取4小时线段的开始时间，作为左线段时间限制
        datetime rangeStartTime = currentMainSegment.StartTime();
        
        // 1. 从4小时主交易区间计算1小时线段
        CZigzagSegmentManager* h1SegmentManager = currentMainSegment.GetSmallerTimeframeSegments(PERIOD_H1);
        if(h1SegmentManager != NULL)
        {
            CZigzagSegment* h1Segments[];
            if(h1SegmentManager.GetSegments(h1Segments) && ArraySize(h1Segments) > 0)
            {
                // 筛选左侧1小时线段（结束时间早于交易基准价格时间且开始时间不早于4小时线段开始时间）
                CZigzagSegment* leftH1Segments[];
                int leftH1Count = 0;
                
                for(int i = 0; i < ArraySize(h1Segments); i++)
                {
                    if(h1Segments[i] != NULL && 
                       h1Segments[i].EndTime() <= g_tradeAnalyzer.m_tradeBasePoint.GetBaseTime() && 
                       h1Segments[i].StartTime() >= rangeStartTime)
                    {
                        ArrayResize(leftH1Segments, leftH1Count + 1);
                        leftH1Segments[leftH1Count++] = h1Segments[i];
                    }
                }
                
                // 按时间排序（最近的在前）
                ::SortSegmentsByTime(leftH1Segments, false, true);
                
                // 显示左侧1小时线段
                if(leftH1Count > 0)
                {
                    string h1LeftText = "H1左: ";
                    for(int i = 0; i < MathMin(3, leftH1Count); i++)
                    {
                        h1LeftText += StringFormat("%s→", DoubleToString(leftH1Segments[i].StartPrice(), _Digits));
                    }
                    ObjectSetString(0, panelName+"_H1_Left", OBJPROP_TEXT, h1LeftText);
                }
                
                // 筛选右侧1小时线段（开始时间晚于交易基准价格时间）
                CZigzagSegment* rightH1Segments[];
                int rightH1Count = 0;
                
                for(int i = 0; i < ArraySize(h1Segments); i++)
                {
                    if(h1Segments[i] != NULL && 
                       h1Segments[i].StartTime() >= g_tradeAnalyzer.m_tradeBasePoint.GetBaseTime())
                    {
                        ArrayResize(rightH1Segments, rightH1Count + 1);
                        rightH1Segments[rightH1Count++] = h1Segments[i];
                    }
                }
                
                // 按时间排序（最近的在前）
                ::SortSegmentsByTime(rightH1Segments, false, true);
                
                // 显示右侧1小时线段
                if(rightH1Count > 0)
                {
                    string h1RightText = "H1右: ";
                    for(int i = 0; i < MathMin(3, rightH1Count); i++)
                    {
                        h1RightText += StringFormat("%s→", DoubleToString(rightH1Segments[i].StartPrice(), _Digits));
                    }
                    ObjectSetString(0, panelName+"_H1_Right", OBJPROP_TEXT, h1RightText);
                }
                
                // 2. 从1小时线段计算5分钟线段（使用第一个1小时线段）
                if(ArraySize(h1Segments) > 0)
                {
                    CZigzagSegmentManager* m5SegmentManager = h1Segments[0].GetSmallerTimeframeSegments(PERIOD_M5);
                    if(m5SegmentManager != NULL)
                    {
                        CZigzagSegment* m5Segments[];
                        if(m5SegmentManager.GetSegments(m5Segments) && ArraySize(m5Segments) > 0)
                        {
                            // 筛选左侧5分钟线段（结束时间早于交易基准价格时间且开始时间不早于4小时线段开始时间）
                            CZigzagSegment* leftM5Segments[];
                            int leftM5Count = 0;
                            
                            for(int i = 0; i < ArraySize(m5Segments); i++)
                            {
                                if(m5Segments[i] != NULL && 
                                   m5Segments[i].EndTime() <= g_tradeAnalyzer.m_tradeBasePoint.GetBaseTime() && 
                                   m5Segments[i].StartTime() >= rangeStartTime)
                                {
                                    ArrayResize(leftM5Segments, leftM5Count + 1);
                                    leftM5Segments[leftM5Count++] = m5Segments[i];
                                }
                            }
                            
                            // 按时间排序（最近的在前）
                            ::SortSegmentsByTime(leftM5Segments, false, true);
                            
                            // 显示左侧5分钟线段
                            if(leftM5Count > 0)
                            {
                                string m5LeftText = "M5左: ";
                                for(int i = 0; i < MathMin(3, leftM5Count); i++)
                                {
                                    m5LeftText += StringFormat("%s→", DoubleToString(leftM5Segments[i].StartPrice(), _Digits));
                                }
                                ObjectSetString(0, panelName+"_M5_Left", OBJPROP_TEXT, m5LeftText);
                            }
                            
                            // 筛选右侧5分钟线段（开始时间晚于交易基准价格时间）
                            CZigzagSegment* rightM5Segments[];
                            int rightM5Count = 0;
                            
                            for(int i = 0; i < ArraySize(m5Segments); i++)
                            {
                                if(m5Segments[i] != NULL && 
                                   m5Segments[i].StartTime() >= g_tradeAnalyzer.m_tradeBasePoint.GetBaseTime())
                                {
                                    ArrayResize(rightM5Segments, rightM5Count + 1);
                                    rightM5Segments[rightM5Count++] = m5Segments[i];
                                }
                            }
                            
                            // 按时间排序（最近的在前）
                            ::SortSegmentsByTime(rightM5Segments, false, true);
                            
                            // 显示右侧5分钟线段
                            if(rightM5Count > 0)
                            {
                                string m5RightText = "M5右: ";
                                for(int i = 0; i < MathMin(3, rightM5Count); i++)
                                {
                                    m5RightText += StringFormat("%s→", DoubleToString(rightM5Segments[i].StartPrice(), _Digits));
                                }
                                ObjectSetString(0, panelName+"_M5_Right", OBJPROP_TEXT, m5RightText);
                            }
                            
                            // 释放5分钟线段数组中的对象
                            for(int i = 0; i < ArraySize(m5Segments); i++)
                            {
                                if(m5Segments[i] != NULL)
                                {
                                    delete m5Segments[i];
                                    m5Segments[i] = NULL;
                                }
                            }
                        }
                        // 释放5分钟线段管理器
                        delete m5SegmentManager;
                    }
                }
                
                // 释放1小时线段数组中的对象
                for(int i = 0; i < ArraySize(h1Segments); i++)
                {
                    if(h1Segments[i] != NULL)
                    {
                        delete h1Segments[i];
                        h1Segments[i] = NULL;
                    }
                }
            }
            // 释放1小时线段管理器
            delete h1SegmentManager;
        }
    }

    // 创建信息标签（辅助方法）
    static void CreateInfoLabel(string name, int x, int y, color clr, string text)
    {
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, g_InfoPanelFontSize);
        ObjectSetString(0, name, OBJPROP_FONT, g_InfoPanelFont);
        ObjectSetString(0, name, OBJPROP_TEXT, text);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_ZORDER, 100);
    }

    // 无数据提示
    static void DisplayNoDataMessage(string panelName, int panelX, int panelY, color textColor)
    {
        CreateInfoLabel(panelName + "_NoData", panelX + 10, panelY + 30, textColor, "暂无有效数据");
    }
};