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
color   g_InfoPanelBgColor = clrNavy;  // 添加回背景颜色变量
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
    // 静态变量记录上次更新时间（用于节流）
    static datetime s_lastUpdateTime;
    
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
        
        // 减少日志输出
        // Print("面板内容构建完成:\n", content);
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

public:
    // 初始化静态变量
    static void InitStaticVars()
    {
        s_lastCalcTime = 0;
        s_lastUpdateTime = 0;
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
        
        // 清除可能存在的旧标签
        DeletePanel();
    }
    
    // 设置面板可见性
    static void SetVisible(bool visible)
    {
        g_InfoPanelVisible = visible;
        
        if(!visible)
        {
            // 如果设置为不可见，删除标签
            DeletePanel();
        }
        else
        {
            // 如果设置为可见，创建标签
            CreateTradeInfoPanel();
        }
    }

    // 创建交易信息标签 - 直接在图表上显示
    static void CreateTradeInfoPanel(string panelName="", color textColor=NULL)
    {
        if(!g_InfoPanelVisible) return; // 如果不可见，直接返回
        
        string actualPanelName = (panelName == "") ? g_InfoPanelName : panelName;
        color actualTextColor = (textColor == NULL) ? g_InfoPanelTextColor : textColor;

        Print("创建交易信息标签:", actualPanelName);
        
        // 清除所有相关对象
        ObjectsDeleteAll(0, actualPanelName + "_");
        
        // 构建内容
        string content = BuildPanelContent();
        
        // 按换行符拆分内容
        string lines[];
        int lineCount = StringSplit(content, '\n', lines);
        
        // 减少日志输出
        // Print("信息行数:", lineCount);
        
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
            ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, g_InfoPanelX);
            ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, g_InfoPanelY + i * 20);
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, actualTextColor);
            ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, g_InfoPanelFontSize);
            ObjectSetString(0, labelName, OBJPROP_FONT, g_InfoPanelFont);
            ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
            ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, false);
            ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
            
            // 减少日志输出
            // Print("创建标签:", labelName, " 内容:", lines[i]);
        }
        
        // 强制刷新图表
        ChartRedraw(0);
        // 减少日志输出
        Print("信息标签创建完成");
    }

    // 删除面板
    static void DeletePanel(string panelName="")
    {
        string actualPanelName = (panelName == "") ? g_InfoPanelName : panelName;
        // 删除所有相关标签
        ObjectsDeleteAll(0, actualPanelName + "_");
        
        // 强制刷新图表
        ChartRedraw(0);
        Print("标签已删除:", actualPanelName);
    }

    // 更新面板内容
    static void UpdatePanelContent()
    {
        if(!g_InfoPanelVisible) return; // 如果不可见，直接返回
        
        // 添加节流机制，避免频繁更新
        datetime currentTickTime = TimeCurrent();
        if(currentTickTime - CInfoPanelManager::s_lastUpdateTime < 1) // 至少间隔1秒
        {
            return;
        }
        CInfoPanelManager::s_lastUpdateTime = currentTickTime;
        
        // 只在1分钟收线时重新计算交易区间
        datetime currentTime = iTime(NULL, PERIOD_M1, 0);
        if(CInfoPanelManager::s_lastCalcTime != currentTime)
        {
            CInfoPanelManager::s_lastCalcTime = currentTime;
            Print("1分钟收线，重新计算交易区间");
            
            // 获取新内容
            string content = BuildPanelContent();
            string panelName = g_InfoPanelName;
            
            // 按换行符拆分内容
            string lines[];
            int lineCount = StringSplit(content, '\n', lines);
            
            // 检查标签是否存在，不存在则创建
            bool needsCreation = false;
            for(int i = 0; i < lineCount; i++)
            {
                string labelName = panelName + "_Line" + IntegerToString(i);
                if(ObjectFind(0, labelName) < 0)
                {
                    needsCreation = true;
                    break;
                }
            }
            
            if(needsCreation)
            {
                // 如果有标签不存在，创建所有标签
                Print("部分标签不存在，创建所有标签");
                CreateTradeInfoPanel();
            }
            else
            {
                // 所有标签都存在，只更新内容
                Print("更新标签内容");
                for(int i = 0; i < lineCount; i++)
                {
                    string labelName = panelName + "_Line" + IntegerToString(i);
                    string currentText = ObjectGetString(0, labelName, OBJPROP_TEXT);
                    
                    // 只有当文本内容变化时才更新
                    if(currentText != lines[i])
                    {
                        ObjectSetString(0, labelName, OBJPROP_TEXT, lines[i]);
                        // 减少日志输出
                        // Print("更新标签:", labelName, " 新内容:", lines[i]);
                    }
                }
                
                // 删除多余的标签
                int i = lineCount;
                while(true)
                {
                    string labelName = panelName + "_Line" + IntegerToString(i);
                    if(ObjectFind(0, labelName) >= 0)
                    {
                        ObjectDelete(0, labelName);
                        // 减少日志输出
                        // Print("删除多余标签:", labelName);
                        i++;
                    }
                    else
                    {
                        break;
                    }
                }
                
                // 强制刷新图表
                ChartRedraw(0);
            }
        }
        else
        {
            // 非收线时间，只更新标签内容，不重新计算
            string panelName = g_InfoPanelName;
            string content = BuildPanelContent();
            
            // 按换行符拆分内容
            string lines[];
            int lineCount = StringSplit(content, '\n', lines);
            
            // 更新每行文本标签
            for(int i = 0; i < lineCount; i++)
            {
                string labelName = panelName + "_Line" + IntegerToString(i);
                
                if(ObjectFind(0, labelName) >= 0)
                {
                    string currentText = ObjectGetString(0, labelName, OBJPROP_TEXT);
                    
                    // 只有当文本内容变化时才更新
                    if(currentText != lines[i])
                    {
                        ObjectSetString(0, labelName, OBJPROP_TEXT, lines[i]);
                        // 减少日志输出
                        // Print("更新标签:", labelName, " 新内容:", lines[i]);
                    }
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
datetime CInfoPanelManager::s_lastUpdateTime = 0;