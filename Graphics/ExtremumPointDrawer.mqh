//+------------------------------------------------------------------+
//|                                          ExtremumPointDrawer.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

// 包含必要的头文件
#include "LabelManager.mqh"
#include "LineManager.mqh"
#include "../ZigzagExtremumPoint.mqh"

//+------------------------------------------------------------------+
//| 极值点绘制管理类                                                  |
//+------------------------------------------------------------------+
class CExtremumPointDrawer
{
public:
   // 检查标签是否与4H标签重叠
   static bool IsLabelOverlappingWith4HLabels(datetime time, SZigzagExtremumPoint &fourHourPoints[])
   {
      const int TIME_TOLERANCE = 3600; // 1小时的容差
      
      for(int i = 0; i < ArraySize(fourHourPoints); i++)
      {
         // 检查时间是否接近4H极值点时间
         if(MathAbs((int)time - (int)fourHourPoints[i].time) < TIME_TOLERANCE)
         {
            return true;
         }
      }
      
      return false;
   }

public:
   //+------------------------------------------------------------------+
   //| 绘制极值点标签                                                   |
   //+------------------------------------------------------------------+
   static void DrawExtremumPointLabels(SZigzagExtremumPoint &points[], string source, bool isMain)
   {
      for(int i = 0; i < ArraySize(points); i++)
      {
         string labelName = StringFormat("ZigzagLabel_%s_%d", source, i);
         string labelText = StringFormat("%s: %s", source, DoubleToString(points[i].value, _Digits));
         
         // 确定使用的时间，对于4H极点使用1小时周期的时间
         datetime labelTime = points[i].time;
         if(source == "4H")
         {
            // 对于4小时极点，使用预计算的1小时K线时间
            datetime h1Time = GetH1Time(points[i]);
            if(h1Time > 0)
            {
               labelTime = h1Time;
            }
         }
         
         // 创建工具提示
         string tooltipText = StringFormat("来源: %s\n时间: %s\n价格: %s\n类型: %s", 
                                         source,
                                         TimeToString(points[i].time, TIME_DATE|TIME_MINUTES),
                                         DoubleToString(points[i].value, _Digits),
                                         IsPeak(points[i]) ? "峰值" : "谷值");
         
         // 创建标签
         CLabelManager::CreateTextLabel(
            labelName,
            labelText,
            labelTime,  // 使用修正后的时间
            points[i].value,
            IsPeak(points[i]),
            isMain,  // 4H为主要（大周期），1H为次要
            NULL,    // 使用默认颜色
            NULL,    // 使用默认字体
            0,       // 使用默认字体大小
            0,       // X轴偏移量
            true,    // 启用居中显示
            tooltipText
         );
      }
   }

   //+------------------------------------------------------------------+
   //| 绘制线段                                                         |
   //+------------------------------------------------------------------+
   static void DrawSegmentLines(SZigzagExtremumPoint &points[], string source, bool isMain, color mainColor, color subColor)
   {
      // 至少需要2个点才能绘制线段
      if(ArraySize(points) < 2)
         return;
         
      // 根据来源选择线段颜色
      color lineColor = isMain ? mainColor : subColor;
      
      // 绘制连接线段
      for(int i = 0; i < ArraySize(points) - 1; i++)
      {
         string lineName = StringFormat("ZigzagLine_%s_%d", source, i);
         
         // 创建连接线
         CLineManager::CreateTrendLine(
            lineName,
            points[i].time,
            points[i].value,
            points[i+1].time,
            points[i+1].value,
            lineColor,
            1,  // 线宽
            STYLE_SOLID  // 线型
         );
      }
   }


};