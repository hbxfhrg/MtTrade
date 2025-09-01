//+------------------------------------------------------------------+
//|                                              InfoPanelManager.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

#include "../GlobalInstances.mqh"
#include "../Strategies/StrategyManager.mqh"
#include "LabelManager.mqh"

// 全局面板属性
string  g_InfoPanelName = "InfoPanel";
color   g_InfoPanelTextColor = clrWhite;
color   g_InfoPanelBgColor = clrNavy;
int     g_InfoPanelFontSize = 9;
string  g_InfoPanelFont = "Arial";
int g_InfoPanelX = 10;  // 面板X坐标
int g_InfoPanelY = 10;  // 面板Y坐标
bool g_InfoPanelVisible = true; // 面板可见性控制

//+------------------------------------------------------------------+
//| 信息面板管理类                                                   |
//+------------------------------------------------------------------+
class CInfoPanelManager
{
private:
    // 静态变量记录上次计算时间
    static datetime s_lastCalcTime;
    
    // 构建面板内容
    static string BuildPanelContent()
    {
        string content = "";
        
        if(g_tradeAnalyzer.IsValid())
        {
            // 核心交易信息
            content += "区间: " + DoubleToString(g_tradeAnalyzer.GetRangeLow(), _Digits) + 
                      " - " + DoubleToString(g_tradeAnalyzer.GetRangeHigh(), _Digits) + "\n";
            
            content += "趋势方向: " + g_tradeAnalyzer.GetTrendDirection() + "\n";
            
            g_tradeAnalyzer.CalculateRetracement();
            content += g_tradeAnalyzer.GetRetraceDescription() + "\n";
            
            content += "参考价: " + DoubleToString(g_tradeAnalyzer.GetTradeBasePrice(), _Digits) + "\n";
            
            // 线段信息
            string segmentInfo = BuildSegmentInfo();
            if(segmentInfo != "")
            {
                content += segmentInfo;
            }
            else
            {
                content += "5分钟线段(左): 加载中...\n";
                content += "5分钟线段(右): 加载中...\n"; 
                content += "1小时线段(左): 加载中...\n";
                content += "1小时线段(右): 加载中...";
            }
        }
        else
        {
            content = "暂无有效数据";
        }
        
        Print("面板内容构建完成:\n", content);
        return content;
    }

    // 构建线段信息
    static string BuildSegmentInfo()
    {
        string segmentInfo = "";
        CZigzagSegment* currentMainSegment = g_tradeAnalyzer.GetCurrentSegment();
        
        if(currentMainSegment != NULL)
        {
            double tradeBasePrice = g_tradeAnalyzer.GetTradeBasePrice();
            if(tradeBasePrice > 0.0)
            {
                datetime rangeStartTime = currentMainSegment.StartTime();
                
                // 1小时线段信息
                CZigzagSegmentManager* h1Manager = currentMainSegment.GetSmallerTimeframeSegments(PERIOD_H1);
                if(h1Manager != NULL)
                {
                    CZigzagSegment* h1Segments[];
                    if(h1Manager.GetSegments(h1Segments) && ArraySize(h1Segments) > 0)
                    {
                        segmentInfo += BuildSegmentLines("H1左", h1Segments, true, rangeStartTime) + "\n";
                        segmentInfo += BuildSegmentLines("H1右", h1Segments, false, rangeStartTime) + "\n";
                        
                        // 5分钟线段信息
                        CZigzagSegmentManager* m5Manager = h1Segments[0].GetSmallerTimeframeSegments(PERIOD_M5);
                        if(m5Manager != NULL)
                        {
                            CZigzagSegment* m5Segments[];
                            if(m5Manager.GetSegments(m5Segments) && ArraySize(m5Segments) > 0)
                            {
                                segmentInfo += BuildSegmentLines("M5左", m5Segments, true, rangeStartTime) + "\n";
                                segmentInfo += BuildSegmentLines("M5右", m5Segments, false, rangeStartTime);
                            }
                            
                            // 释放资源
                            for(int i = 0; i < ArraySize(m5Segments); i++)
                            {
                                if(m5Segments[i] != NULL)
                                {
                                    delete m5Segments[i];
                                }
                            }
                            delete m5Manager;
                        }
                    }
                    
                    // 释放资源
                    for(int i = 0; i < ArraySize(h1Segments); i++)
                    {
                        if(h1Segments[i] != NULL)
                        {
                            delete h1Segments[i];
                        }
                    }
                    delete h1Manager;
                }
            }
        }
        
        return segmentInfo;
    }

    // 构建线段文本
    static string BuildSegmentLines(string prefix, CZigzagSegment* &segments[], bool isLeft, datetime rangeStartTime)
    {
        string lineText = prefix + ": ";
        CZigzagSegment* filteredSegments[];
        int count = 0;
        
        for(int i = 0; i < ArraySize(segments); i++)
        {
            if(segments[i] != NULL)
            {
                bool condition = isLeft ? 
                    (segments[i].EndTime() <= g_tradeAnalyzer.m_tradeBasePoint.GetBaseTime() && 
                     segments[i].StartTime() >= rangeStartTime) :
                    (segments[i].StartTime() >= g_tradeAnalyzer.m_tradeBasePoint.GetBaseTime());
                
                if(condition)
                {
                    ArrayResize(filteredSegments, count + 1);
                    filteredSegments[count++] = segments[i];
                }
            }
        }
        
        if(count > 0)
        {
            SortSegmentsByTime(filteredSegments, false, true);
            for(int i = 0; i < MathMin(3, count); i++)
            {
                lineText += DoubleToString(filteredSegments[i].StartPrice(), _Digits) + "→";
            }
        }
        else
        {
            lineText += "无数据";
        }
        
        return lineText;
    }

   // 修改CreateMultiLinePanel方法中的标签创建逻辑
static void CreateMultiLinePanel(string panelName, string content, int panelX, int panelY, 
                               int panelWidth, int panelHeight, color textColor, color bgColor)
{
    Print("开始创建面板:", panelName);
    Print("面板位置: X=", panelX, " Y=", panelY);
    Print("面板尺寸: 宽=", panelWidth, " 高=", panelHeight);
    
    // 创建面板背景
    if(!CreatePanelBackground(panelName, panelX, panelY, panelWidth, panelHeight, bgColor))
    {
        Print("创建面板背景失败");
        return;
    }
    
    // 按换行符拆分内容
    string lines[];
    int lineCount = StringSplit(content, '\n', lines);
    int lineHeight = 20;
    
    Print("面板内容行数:", lineCount);
    
    // 创建每行标签
    for(int i = 0; i < lineCount; i++)
    {
        string labelName = panelName + "_Line" + IntegerToString(i);
        
        // 直接创建标签，不检查返回值
        CLabelManager::CreateTextLabel(
            labelName, 
            lines[i], 
            0, 0, 
            false, 
            false,  // 确保不是隐藏状态
            textColor, 
            g_InfoPanelFont, 
            g_InfoPanelFontSize,
            panelX + 10,
            false
        );
        
        // 检查标签是否创建成功
        if(ObjectFind(0, labelName) >= 0)
        {
            if(ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, panelY + 10 + (i * lineHeight)))
            {
                Print("成功创建标签:", labelName, " 内容:", lines[i]);
            }
            else
            {
                Print("设置标签位置失败:", labelName);
            }
        }
        else
        {
            Print("创建标签失败:", labelName);
        }
    }
}

    // 创建面板背景
    static bool CreatePanelBackground(string name, int x, int y, int width, int height, color bgColor)
    {
        if(!ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
        {
            Print("创建背景对象失败:", name, " 错误:", GetLastError());
            return false;
        }
        
        if(!ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x) ||
           !ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y) ||
           !ObjectSetInteger(0, name, OBJPROP_XSIZE, width) ||
           !ObjectSetInteger(0, name, OBJPROP_YSIZE, height))
        {
            Print("设置背景对象属性失败:", name);
            return false;
        }
        
        ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
        ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        // 确保面板可见
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
        
        Print("面板背景创建成功:", name);
        return true;
    }

public:
    // 初始化静态变量
    static void InitStaticVars()
    {
        s_lastCalcTime = 0;
    }
    
    // 初始化面板属性
    static void Init(string panelName="InfoPanel", color textColor=clrWhite, color bgColor=clrNavy, int fontSize=9)
    {
        g_InfoPanelName = panelName;
        g_InfoPanelTextColor = textColor;
        g_InfoPanelBgColor = bgColor;
        g_InfoPanelFontSize = fontSize;
        g_InfoPanelFont = "Arial";
        g_InfoPanelVisible = true;
        InitStaticVars();
        
        // 清除可能存在的旧面板
        DeletePanel();
    }
    
    // 设置面板可见性
    static void SetVisible(bool visible)
    {
        g_InfoPanelVisible = visible;
        
        if(!visible)
        {
            // 如果设置为不可见，删除面板
            DeletePanel();
        }
        else
        {
            // 如果设置为可见，创建面板
            CreateTradeInfoPanel();
        }
    }

    // 创建交易信息面板 - 直接在图表上显示
static void CreateTradeInfoPanel(string panelName="", color textColor=NULL, color bgColor=NULL)
{
    if(!g_InfoPanelVisible) return; // 如果面板不可见，直接返回
    
    string actualPanelName = (panelName == "") ? g_InfoPanelName : panelName;
    color actualTextColor = (textColor == NULL) ? g_InfoPanelTextColor : textColor;
    color actualBgColor = (bgColor == NULL) ? g_InfoPanelBgColor : bgColor;

    Print("创建交易信息面板:", actualPanelName);
    
    // 清除所有相关对象
    ObjectsDeleteAll(0, actualPanelName + "_");
    
    // 构建面板内容
    string panelContent = BuildPanelContent();
    
    // 按换行符拆分内容
    string lines[];
    int lineCount = StringSplit(panelContent, '\n', lines);
    
    Print("信息行数:", lineCount);
    
    // 计算面板尺寸
    int panelWidth = 250;
    int panelHeight = 30 + lineCount * 20;
    
    // 创建面板背景
    if(!CreatePanelBackground(actualPanelName, g_InfoPanelX, g_InfoPanelY, panelWidth, panelHeight, actualBgColor))
    {
        Print("面板背景创建失败");
        return;
    }
    
    // 创建每行文本标签
    for(int i = 0; i < lineCount; i++)
    {
        string labelName = actualPanelName + "_Line" + IntegerToString(i);
        
        // 创建文本标签
        if(!ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0))
        {
            Print("创建标签失败:", labelName, " 错误:", GetLastError());
            continue;
        }
        
        // 设置标签属性
        ObjectSetString(0, labelName, OBJPROP_TEXT, lines[i]);
        ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, g_InfoPanelX + 10);
        ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, g_InfoPanelY + 15 + i * 20);
        ObjectSetInteger(0, labelName, OBJPROP_COLOR, actualTextColor);
        ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, g_InfoPanelFontSize);
        ObjectSetString(0, labelName, OBJPROP_FONT, g_InfoPanelFont);
        ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
        ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, false);
        ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
        
        Print("创建标签:", labelName, " 内容:", lines[i]);
    }
    
    // 强制刷新图表
    ChartRedraw(0);
    Print("信息面板创建完成");
}

    // 创建简单信息面板
    static void CreateSimpleInfoPanel(string panelName, string message, color textColor=NULL, color bgColor=NULL)
    {
        string actualPanelName = (panelName == "") ? g_InfoPanelName : panelName;
        color actualTextColor = (textColor == NULL) ? g_InfoPanelTextColor : textColor;
        color actualBgColor = (bgColor == NULL) ? g_InfoPanelBgColor : bgColor;

        // 删除旧面板
        DeletePanel(actualPanelName);

        // 创建面板背景
        int panelWidth = 250;
        int panelHeight = 60;
        int panelX = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) - panelWidth - 10;
        int panelY = 10;

        // 创建单行面板
        CreateMultiLinePanel(actualPanelName, message, panelX, panelY, 
                           panelWidth, panelHeight, actualTextColor, actualBgColor);
    }

    // 删除面板
    static void DeletePanel(string panelName="")
    {
        string actualPanelName = (panelName == "") ? g_InfoPanelName : panelName;
        // 删除面板背景
        ObjectDelete(0, actualPanelName);
        // 删除所有相关标签
        ObjectsDeleteAll(0, actualPanelName + "_");
        
        // 强制刷新图表
        ChartRedraw(0);
        Print("面板已删除:", actualPanelName);
    }

   // 更新面板内容 - 简化版本，直接重新创建面板
static void UpdatePanelContent()
{
    if(!g_InfoPanelVisible) return; // 如果面板不可见，直接返回
    
    // 只在1分钟收线时重新计算交易区间
    datetime currentTime = iTime(NULL, PERIOD_M1, 0);
    if(CInfoPanelManager::s_lastCalcTime != currentTime)
    {
        CInfoPanelManager::s_lastCalcTime = currentTime;
        Print("1分钟收线，重新计算交易区间");
        
        // 直接重新创建面板
        CreateTradeInfoPanel();
    }
    else
    {
        // 非收线时间，只更新标签内容，不重新计算
        string panelName = g_InfoPanelName;
        string panelContent = BuildPanelContent();
        
        // 按换行符拆分内容
        string lines[];
        int lineCount = StringSplit(panelContent, '\n', lines);
        
        // 更新每行文本标签
        for(int i = 0; i < lineCount; i++)
        {
            string labelName = panelName + "_Line" + IntegerToString(i);
            
            if(ObjectFind(0, labelName) >= 0)
            {
                ObjectSetString(0, labelName, OBJPROP_TEXT, lines[i]);
            }
        }
        
        // 强制刷新图表
        ChartRedraw(0);
    }
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
};

// 定义静态变量
datetime CInfoPanelManager::s_lastCalcTime = 0;