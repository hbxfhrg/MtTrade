//+------------------------------------------------------------------+
//|                                                SegmentDrawer.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

// 包含必要的头文件
#include "..\ZigzagSegment.mqh"
#include "..\ZigzagExtremumPoint.mqh"
#include "LabelManager.mqh"
#include "LineManager.mqh"
#include "..\CommonUtils.mqh"
#include "ExtremumPointDrawer.mqh"

//+------------------------------------------------------------------+
//| 线段绘制类                                                        |
//+------------------------------------------------------------------+
class CSegmentDrawer
{
public:
   // 绘制1小时子线段
   static void Draw1HSubSegments(CZigzagSegment* &validSegments[], int validCount, CZigzagExtremumPoint &points4H[]);
};



//+------------------------------------------------------------------+
//| 绘制1小时子线段                                                   |
//+------------------------------------------------------------------+
void CSegmentDrawer::Draw1HSubSegments(CZigzagSegment* &validSegments[], int validCount, CZigzagExtremumPoint &points4H[])
{
   // 统计绘制的线段数量
   int drawnCount = 0;
   int drawnUptrendCount = 0;
   int drawnDowntrendCount = 0;
   
   for(int i = 0; i < validCount; i++)
   {
      if(validSegments[i] != NULL)
      {
         string lineName = StringFormat("ZigzagLine_1H_%d", i);
         
         // 确定线段颜色：上涨用蓝色，下跌用红色
         color lineColor;
         if(validSegments[i].IsUptrend())
         {
            // 上涨线段 - 蓝色
            lineColor = clrBlue;
            drawnUptrendCount++;
         }
         else
         {
            // 下跌线段 - 红色
            lineColor = clrRed;
            drawnDowntrendCount++;
         }
         
         // 输出调试信息
         Print(StringFormat("准备绘制1H线段 %d: %s - %s, 价格: %.5f - %.5f, 趋势: %s", 
                          i,
                          TimeToString(validSegments[i].StartTime(), TIME_DATE|TIME_MINUTES),
                          TimeToString(validSegments[i].EndTime(), TIME_DATE|TIME_MINUTES),
                          validSegments[i].StartPrice(),
                          validSegments[i].EndPrice(),
                          validSegments[i].IsUptrend() ? "上涨" : "下跌"));
         
         // 创建连接线 - 绕过防闪烁机制，强制更新
         // 先删除可能存在的同名对象
         ObjectDelete(0, lineName);
         
         // 创建趋势线
         bool lineCreated = ObjectCreate(0, lineName, OBJ_TREND, 0, 
                                       validSegments[i].StartTime(), validSegments[i].StartPrice(),
                                       validSegments[i].EndTime(), validSegments[i].EndPrice());
         
         if(!lineCreated)
         {
            Print(StringFormat("警告: 线段%d创建失败", i));
         }
         else
         {
            // 设置线条属性 - 线宽改为2，使线条更粗一些
            ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);
            ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);  // 线宽改为2
            ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, lineName, OBJPROP_RAY_LEFT, false);
            ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, lineName, OBJPROP_BACK, false); // 确保线条在前景显示
            ObjectSetInteger(0, lineName, OBJPROP_ZORDER, 1); // 设置Z顺序
            
            drawnCount++;
            Print(StringFormat("线段%d创建成功", i));
         }
         
         // 只在线段起点和终点绘制标签
         string startLabelName = StringFormat("ZigzagLabel_1H_%d_Start", i);
         string endLabelName = StringFormat("ZigzagLabel_1H_%d_End", i);
         
         string startLabelText = StringFormat("1H: %s", DoubleToString(validSegments[i].StartPrice(), _Digits));
         string endLabelText = StringFormat("1H: %s", DoubleToString(validSegments[i].EndPrice(), _Digits));
         
         // 检查起点标签是否与4小时标签重叠
         bool startOverlapsWith4H = CExtremumPointDrawer::IsLabelOverlappingWith4HLabels(validSegments[i].StartTime(), points4H);
         datetime startTime = validSegments[i].StartTime();
         
         // 创建起点标签
         ObjectDelete(0, startLabelName);
         bool startLabelCreated = ObjectCreate(0, startLabelName, OBJ_TEXT, 0, 
                                              startTime, validSegments[i].StartPrice());
         
         if(startLabelCreated)
         {
            // 根据是否重叠设置不同的标签文本和颜色
            string actualStartLabelText = startLabelText;
            color actualStartLabelColor = clrWhite;  // 默认白色
            
            if(startOverlapsWith4H)
            {
               // 重叠时修改文本为4H标签格式
               actualStartLabelText = StringFormat("4H: %s", DoubleToString(validSegments[i].StartPrice(), _Digits));
               actualStartLabelColor = clrOrange;  // 重叠时使用橙色（4H标签颜色）
            }
            
            // 设置标签属性
            ObjectSetString(0, startLabelName, OBJPROP_TEXT, actualStartLabelText);
            ObjectSetString(0, startLabelName, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, startLabelName, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, startLabelName, OBJPROP_COLOR, actualStartLabelColor);
            ObjectSetInteger(0, startLabelName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, startLabelName, OBJPROP_SELECTABLE, false);
            ObjectSetDouble(0, startLabelName, OBJPROP_ANGLE, 0);
            
            // 设置标签位置和锚点
            if(validSegments[i].StartPoint().IsPeak())
               ObjectSetInteger(0, startLabelName, OBJPROP_ANCHOR, ANCHOR_LOWER);
            else
               ObjectSetInteger(0, startLabelName, OBJPROP_ANCHOR, ANCHOR_UPPER);
            
            // 设置X轴偏移量
            ObjectSetInteger(0, startLabelName, OBJPROP_XOFFSET, 0);
            
            Print(StringFormat("线段%d起点标签创建成功", i));
         }
         else
         {
            Print(StringFormat("警告: 线段%d起点标签创建失败", i));
         }
         
         // 检查终点标签是否与4小时标签重叠
         bool endOverlapsWith4H = CExtremumPointDrawer::IsLabelOverlappingWith4HLabels(validSegments[i].EndTime(), points4H);
         datetime endTime = validSegments[i].EndTime();
         
         // 创建终点标签
         ObjectDelete(0, endLabelName);
         bool endLabelCreated = ObjectCreate(0, endLabelName, OBJ_TEXT, 0, 
                                            endTime, validSegments[i].EndPrice());
         
         if(endLabelCreated)
         {
            // 根据是否重叠设置不同的标签文本和颜色
            string actualEndLabelText = endLabelText;
            color actualEndLabelColor = clrWhite;  // 默认白色
            
            if(endOverlapsWith4H)
            {
               // 重叠时修改文本为4H标签格式
               actualEndLabelText = StringFormat("4H: %s", DoubleToString(validSegments[i].EndPrice(), _Digits));
               actualEndLabelColor = clrOrange;  // 重叠时使用橙色（4H标签颜色）
            }
            
            // 设置标签属性
            ObjectSetString(0, endLabelName, OBJPROP_TEXT, actualEndLabelText);
            ObjectSetString(0, endLabelName, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, endLabelName, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, endLabelName, OBJPROP_COLOR, actualEndLabelColor);
            ObjectSetInteger(0, endLabelName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, endLabelName, OBJPROP_SELECTABLE, false);
            ObjectSetDouble(0, endLabelName, OBJPROP_ANGLE, 0);
            
            // 设置标签位置和锚点
            if(validSegments[i].EndPoint().IsPeak())
               ObjectSetInteger(0, endLabelName, OBJPROP_ANCHOR, ANCHOR_LOWER);
            else
               ObjectSetInteger(0, endLabelName, OBJPROP_ANCHOR, ANCHOR_UPPER);
            
            // 设置X轴偏移量
            ObjectSetInteger(0, endLabelName, OBJPROP_XOFFSET, 0);
            
            Print(StringFormat("线段%d终点标签创建成功", i));
         }
         else
         {
            Print(StringFormat("警告: 线段%d终点标签创建失败", i));
         }
      }
   }
   
   Print(StringFormat("成功绘制线段数量：%d个 (上涨: %d个, 下跌: %d个)", drawnCount, drawnUptrendCount, drawnDowntrendCount));
}