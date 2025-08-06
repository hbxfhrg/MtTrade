//+------------------------------------------------------------------+
//|                                       ZigzagExtremumPointTest.mq5 |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property script_show_inputs

// 引入ZigzagCalculator类
#include "ZigzagCalculator.mqh"

// 输入参数
input int InpDepth     = 12;  // 深度
input int InpDeviation = 5;   // 偏差
input int InpBackstep  = 3;   // 回溯步数
input int InpPointsCount = 10; // 显示的极值点数量
input int InpMarkerSize = 5;   // 标记大小(1-10)

//+------------------------------------------------------------------+
//| 脚本程序起始函数                                                   |
//+------------------------------------------------------------------+
// 删除所有标签
void DeleteAllLabels()
{
   // 删除所有图表对象 - 使用更彻底的方法
   ObjectsDeleteAll(0, "ExtremumPoint_", -1, -1);
   
   // 强制刷新图表
   ChartRedraw();
   
   Print("已清除所有之前的图表标记");
}

void OnStart()
{
   // 显示操作提示
   MessageBox("将在图表上标记ZigZag极值点，请确保图表已打开并可见。\n如果看不到标记，请尝试调整标记大小参数。", "ZigZag极值点标记", MB_ICONINFORMATION);
   
   // 清理之前的标签
   DeleteAllLabels();
   
   // 确保图表处于正确状态
   long chart_id = ChartID();
   ChartSetInteger(chart_id, CHART_AUTOSCROLL, false);  // 禁用自动滚动
   ChartSetInteger(chart_id, CHART_FOREGROUND, false);  // 确保价格在前景
   
   // 强制刷新图表，确保之前的对象被清除
   ChartRedraw();
   
   // 创建ZigzagCalculator实例
   CZigzagCalculator zigzag(InpDepth, InpDeviation, InpBackstep);
   
   // 为当前图表计算ZigZag值
   if(!zigzag.CalculateForCurrentChart(1000))
   {
      Print("计算ZigZag值失败");
      return;
   }
   
   // 获取极值点对象
   CZigzagExtremumPoint points[];
   
   if(zigzag.GetRecentExtremumPoints(points, InpPointsCount))
   {
      // 显示极值点信息
      Print("最近的", InpPointsCount, "个极值点:");
      
      // 首先创建一个ZigZag线条连接所有点
      for(int i = 1; i < ArraySize(points); i++)
      {
         string line_name = StringFormat("ExtremumPoint_Line_%d", i);
         ObjectCreate(0, line_name, OBJ_TREND, 0, 
                     points[i-1].Time(), points[i-1].Value(),
                     points[i].Time(), points[i].Value());
         
         color line_color = clrMagenta;
         ObjectSetInteger(0, line_name, OBJPROP_COLOR, line_color);
         ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, line_name, OBJPROP_BACK, true);
      }
      
      // 然后为每个点创建标记
      for(int i = 0; i < ArraySize(points); i++)
      {
         string point_info = StringFormat(
            "#%d: %s, 时间周期: %s, 时间: %s, 序号: %d, 值: %s", 
            i+1,
            points[i].TypeAsString(),
            EnumToString(points[i].Timeframe()),
            TimeToString(points[i].Time()),
            points[i].BarIndex(),
            DoubleToString(points[i].Value(), _Digits)
         );
         
         Print(point_info);
         
         // 在图表上添加标签
         string label_name = StringFormat("ExtremumPoint_%d", i);
         string label_type = points[i].IsPeak() ? "峰值" : "谷值";
         color label_color = points[i].IsPeak() ? clrDodgerBlue : clrRed;
         
         // 获取K线序号
         int bar_index = points[i].BarIndex();
         
         // 创建标签 - 使用买卖箭头对象，这是MT5中最明显的图表对象
         ENUM_OBJECT obj_type = points[i].IsPeak() ? OBJ_ARROW_SELL : OBJ_ARROW_BUY;
         ObjectCreate(0, label_name, obj_type, 0, points[i].Time(), points[i].Value());
         
         // 设置文本颜色更加鲜明
         color bright_color = points[i].IsPeak() ? clrDeepSkyBlue : clrCrimson;
         
         // 设置鼠标悬停时的提示文本 - 详细信息
         // 获取当前品种的点值
         double point_value = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         // 计算当前点与相邻点的价格差
         double price_diff = 0;
         int points_diff = 0;
         int bars_diff = 0;
         string tooltip;
         
         if (i > 0) {
            // 与前一个点比较
            price_diff = MathAbs(points[i].Value() - points[i-1].Value());
            // 转换为点数
            points_diff = (int)(price_diff / point_value);
            
            // 获取当前K线与前一个极值点K线之间的距离
            bars_diff = MathAbs(points[i].BarIndex() - points[i-1].BarIndex());
            
            tooltip = StringFormat("K线序号: %d\n时间: %s\n类型: %s\n价格: %s\n与前点价差: %d点\nK线距离: %d根", 
                                  bar_index, 
                                  TimeToString(points[i].Time(), TIME_DATE|TIME_MINUTES),
                                  label_type,
                                  DoubleToString(points[i].Value(), _Digits),
                                  points_diff,
                                  bars_diff);
         } else {
            // 第一个点没有前一个点，只显示基本信息
            tooltip = StringFormat("K线序号: %d\n时间: %s\n类型: %s\n价格: %s", 
                                 bar_index, 
                                 TimeToString(points[i].Time(), TIME_DATE|TIME_MINUTES),
                                 label_type,
                                 DoubleToString(points[i].Value(), _Digits));
         }
         // 确保tooltip已设置并可见
         ObjectSetString(0, label_name, OBJPROP_TOOLTIP, tooltip);
         ObjectSetInteger(0, label_name, OBJPROP_SELECTABLE, true); // 临时设置为可选择以测试tooltip
         ObjectSetInteger(0, label_name, OBJPROP_HIDDEN, false);   // 确保不隐藏
         ObjectSetInteger(0, label_name, OBJPROP_BACK, false);     // 确保在前景显示
         
         // 设置其他属性
         ObjectSetInteger(0, label_name, OBJPROP_COLOR, bright_color);
         ObjectSetInteger(0, label_name, OBJPROP_WIDTH, InpMarkerSize);  // 使用用户定义的大小
         ObjectSetInteger(0, label_name, OBJPROP_ANCHOR, ANCHOR_CENTER);
         ObjectSetInteger(0, label_name, OBJPROP_SELECTABLE, false); // 不可选择
         ObjectSetInteger(0, label_name, OBJPROP_HIDDEN, false);     // 在对象列表中显示
         ObjectSetInteger(0, label_name, OBJPROP_BACK, false);       // 确保在前景显示
         ObjectSetInteger(0, label_name, OBJPROP_ZORDER, 100);       // 设置高Z顺序，确保在最前面显示
         
         // 额外添加一个文本标签，确保即使箭头不显示，文本也会显示
         string text_label_name = StringFormat("ExtremumPoint_Text_%d", i);
         string text_content = points[i].IsPeak() ? "P" : "B";
         ObjectCreate(0, text_label_name, OBJ_TEXT, 0, points[i].Time(), points[i].Value());
         ObjectSetString(0, text_label_name, OBJPROP_TEXT, text_content);
         ObjectSetInteger(0, text_label_name, OBJPROP_COLOR, bright_color);
         ObjectSetInteger(0, text_label_name, OBJPROP_FONTSIZE, 14);
         ObjectSetInteger(0, text_label_name, OBJPROP_ANCHOR, ANCHOR_CENTER);
         ObjectSetInteger(0, text_label_name, OBJPROP_ZORDER, 101);  // 确保文本在箭头上面
         
         // 添加调试信息
         PrintFormat("已创建对象 %s，tooltip内容: %s", label_name, tooltip);
         
         // 立即刷新当前对象
         ChartRedraw(0);
      }
      
      // 强制刷新图表
      ChartRedraw();
      
      // 检查对象是否成功创建
      int created_objects = 0;
      for(int i = 0; i < ObjectsTotal(0); i++)
      {
         string name = ObjectName(0, i);
         if(StringFind(name, "ExtremumPoint_") == 0)
         {
            created_objects++;
         }
      }
      
      // 输出确认信息
      Print("已在图表上创建 ", created_objects, " 个图表对象，预期数量: ", ArraySize(points) * 2);
      
      // 确保图表处于前台
      long chart_id = ChartID();
      ChartSetInteger(chart_id, CHART_BRING_TO_TOP, true);
      
      // 再次刷新图表
      ChartRedraw();
   }
   else
   {
      Print("无法获取极值点对象");
   }
}
//+------------------------------------------------------------------+