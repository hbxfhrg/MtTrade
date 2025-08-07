//+------------------------------------------------------------------+
//|                                   ZigzagExtremumPointIndicator.mq5 |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "ZigZag极值点标记"
#property indicator_chart_window  // 在主图表窗口显示
#property indicator_buffers 0
#property indicator_plots 0

// 引入ZigzagCalculator类
#include "ZigzagCalculator.mqh"

// 输入参数
input int InpDepth     = 12;  // 深度
input int InpDeviation = 5;   // 偏差
input int InpBackstep  = 3;   // 回溯步数
input int InpPointsCount = 10; // 显示的极值点数量
input int InpMarkerSize = 5;   // 标记大小(1-10)
input color InpInfoPanelColor = clrWhite;  // 信息面板背景色
input color InpInfoTextColor = clrBlack;   // 信息面板文字颜色

//+------------------------------------------------------------------+
// 全局变量
//+------------------------------------------------------------------+
// 信息面板对象名称
string g_infoPanelName = "ExtremumPoint_InfoPanel";
string g_infoTextName = "ExtremumPoint_InfoText";
// 存储极值点数组，用于鼠标事件处理
CZigzagExtremumPoint g_points[];
// 当前选中的点索引
int g_selectedPointIndex = -1;

//+------------------------------------------------------------------+
//| 脚本程序起始函数                                                   |
//+------------------------------------------------------------------+
// 删除所有标签
void DeleteAllLabels()
{
   // 删除所有图表对象 - 使用更彻底的方法
   int deleted = ObjectsDeleteAll(0, "ExtremumPoint_", -1, -1);
   
   // 强制刷新图表
   ChartRedraw();
   
   Print("已清除所有之前的图表标记，共删除 ", deleted, " 个对象");
}

//+------------------------------------------------------------------+
//| 创建信息面板                                                      |
//+------------------------------------------------------------------+
void CreateInfoPanel()
{
   // 删除可能存在的旧面板
   ObjectDelete(0, g_infoPanelName);
   ObjectDelete(0, g_infoTextName);
   
   // 获取图表尺寸
   int chart_width = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chart_height = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   
   // 面板尺寸和位置
   int panel_width = 200;
   int panel_height = 150;
   int panel_x = 10;
   int panel_y = 10;
   
   // 创建面板背景
   if(!ObjectCreate(0, g_infoPanelName, OBJ_RECTANGLE_LABEL, 0, 0, 0))
   {
      Print("创建信息面板失败!");
      return;
   }
   
   // 设置面板属性
   ObjectSetInteger(0, g_infoPanelName, OBJPROP_XDISTANCE, panel_x);
   ObjectSetInteger(0, g_infoPanelName, OBJPROP_YDISTANCE, panel_y);
   ObjectSetInteger(0, g_infoPanelName, OBJPROP_XSIZE, panel_width);
   ObjectSetInteger(0, g_infoPanelName, OBJPROP_YSIZE, panel_height);
   ObjectSetInteger(0, g_infoPanelName, OBJPROP_BGCOLOR, InpInfoPanelColor);
   ObjectSetInteger(0, g_infoPanelName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, g_infoPanelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, g_infoPanelName, OBJPROP_ZORDER, 0);
   
   // 创建文本标签
   if(!ObjectCreate(0, g_infoTextName, OBJ_LABEL, 0, 0, 0))
   {
      Print("创建信息文本失败!");
      return;
   }
   
   // 设置文本属性
   ObjectSetInteger(0, g_infoTextName, OBJPROP_XDISTANCE, panel_x + 10);
   ObjectSetInteger(0, g_infoTextName, OBJPROP_YDISTANCE, panel_y + 10);
   ObjectSetInteger(0, g_infoTextName, OBJPROP_COLOR, InpInfoTextColor);
   ObjectSetInteger(0, g_infoTextName, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, g_infoTextName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, g_infoTextName, OBJPROP_TEXT, "移动鼠标到P/B点\n查看详细信息");
   ObjectSetInteger(0, g_infoTextName, OBJPROP_ZORDER, 1);
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| 更新信息面板内容                                                  |
//+------------------------------------------------------------------+
void UpdateInfoPanel(int pointIndex)
{
   if(pointIndex < 0 || pointIndex >= ArraySize(g_points))
   {
      // 如果没有选中点，显示默认信息
      ObjectSetString(0, g_infoTextName, OBJPROP_TEXT, "移动鼠标到P/B点\n查看详细信息");
      return;
   }
   
   // 获取当前品种的点值
   double point_value = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // 构建详细信息文本
   string info_text = "";
   info_text += "类型: " + g_points[pointIndex].TypeAsString() + "\n";
   info_text += "时间: " + TimeToString(g_points[pointIndex].Time(), TIME_DATE|TIME_MINUTES) + "\n";
   info_text += "价格: " + DoubleToString(g_points[pointIndex].Value(), _Digits) + "\n";
   info_text += "K线序号: " + IntegerToString(g_points[pointIndex].BarIndex()) + "\n";
   
   // 计算与相邻点的差异
   if(pointIndex > 0)
   {
      // 与前一个点比较
      double price_diff = MathAbs(g_points[pointIndex].Value() - g_points[pointIndex-1].Value());
      int points_diff = (int)(price_diff / point_value);
      int bars_diff = MathAbs(g_points[pointIndex].BarIndex() - g_points[pointIndex-1].BarIndex());
      
      info_text += "与前点价差: " + IntegerToString(points_diff) + "点\n";
      info_text += "K线距离: " + IntegerToString(bars_diff) + "根\n";
   }
   
   if(pointIndex < ArraySize(g_points) - 1)
   {
      // 与后一个点比较
      double price_diff = MathAbs(g_points[pointIndex].Value() - g_points[pointIndex+1].Value());
      int points_diff = (int)(price_diff / point_value);
      int bars_diff = MathAbs(g_points[pointIndex].BarIndex() - g_points[pointIndex+1].BarIndex());
      
      info_text += "与后点价差: " + IntegerToString(points_diff) + "点\n";
      info_text += "K线距离: " + IntegerToString(bars_diff) + "根\n";
   }
   
   // 更新信息面板文本
   ObjectSetString(0, g_infoTextName, OBJPROP_TEXT, info_text);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| 鼠标移动事件处理                                                  |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   // 只处理鼠标移动事件
   if(id == CHARTEVENT_MOUSE_MOVE)
   {
      // 获取鼠标位置
      int x = (int)lparam;
      int y = (int)dparam;
      
      // 检查鼠标是否在任何极值点对象上
      int found_index = -1;
      
      for(int i = 0; i < ArraySize(g_points); i++)
      {
         string label_name = StringFormat("ExtremumPoint_%d", i);
         
         // 检查对象是否存在
         if(!ObjectFind(0, label_name))
            continue;
            
         // 获取对象屏幕坐标
         int obj_x, obj_y;
         datetime obj_time = g_points[i].Time();
         double obj_price = g_points[i].Value();
         
         // 将对象坐标转换为屏幕坐标
         if(!ChartTimePriceToXY(0, 0, obj_time, obj_price, obj_x, obj_y))
            continue;
            
         // 检查鼠标是否在对象附近(允许一定的误差范围)
         int tolerance = 10; // 像素误差范围
         if(MathAbs(x - obj_x) <= tolerance && MathAbs(y - obj_y) <= tolerance)
         {
            found_index = i;
            break;
         }
      }
      
      // 如果找到了点，或者选中的点发生变化，更新信息面板
      if(found_index != g_selectedPointIndex)
      {
         g_selectedPointIndex = found_index;
         UpdateInfoPanel(g_selectedPointIndex);
      }
   }
}

//+------------------------------------------------------------------+
//| 指标初始化函数                                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // 设置指标名称
   IndicatorSetString(INDICATOR_SHORTNAME, "ZigZag极值点标记");
   
   // 清理之前的标签
   DeleteAllLabels();
   
   // 创建信息面板
   CreateInfoPanel();
   
   // 确保图表处于正确状态
   long chart_id = ChartID();
   ChartSetInteger(chart_id, CHART_AUTOSCROLL, false);  // 禁用自动滚动
   ChartSetInteger(chart_id, CHART_FOREGROUND, false);  // 确保价格在前景
   ChartSetInteger(chart_id, CHART_SHOW_OBJECT_DESCR, true); // 显示对象描述
   
   // 启用图表事件处理
   ChartSetInteger(chart_id, CHART_EVENT_MOUSE_MOVE, true);
   
   Print("开始计算并显示极值点...");
   // 计算并显示极值点
   CalculateAndDisplayPoints();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| 指标计算函数                                                      |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   // 检查是否需要重新计算
   static int recalc_counter = 0;
   
   // 如果是首次计算或者每隔一定周期重新计算
   if(prev_calculated == 0 || recalc_counter >= 10)
   {
      Print("触发重新计算，prev_calculated=", prev_calculated, ", recalc_counter=", recalc_counter);
      // 重新计算并显示极值点
      CalculateAndDisplayPoints();
      recalc_counter = 0;
   }
   else
   {
      recalc_counter++;
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| 指标清理函数                                                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // 清理所有创建的对象
   DeleteAllLabels();
   Print("指标已移除，所有对象已清理");
}

//+------------------------------------------------------------------+
//| 计算并显示极值点                                                  |
//+------------------------------------------------------------------+
void CalculateAndDisplayPoints()
{
   Print("开始计算和显示极值点...");
   
   // 清理之前的标签
   DeleteAllLabels();
   
   // 创建信息面板
   CreateInfoPanel();
   
   // 强制刷新图表，确保之前的对象被清除
   ChartRedraw();
   
   // 创建ZigzagCalculator实例
   CZigzagCalculator zigzag(InpDepth, InpDeviation, InpBackstep);
   
   // 为当前图表计算ZigZag值
   Print("正在计算ZigZag值...");
   if(!zigzag.CalculateForCurrentChart(1000))
   {
      Print("计算ZigZag值失败");
      return;
   }
   
   // 获取极值点对象
   ArrayFree(g_points); // 清空全局数组
   
   Print("正在获取极值点...");
   // 强制重新计算数据
   if(!zigzag.CalculateForCurrentChart(1000)) {
      Print("重新计算ZigZag数据失败");
      return;
   }
   if(zigzag.GetRecentExtremumPoints(g_points, InpPointsCount))
   {
      // 调试信息：显示所有获取到的点的时间
      Print("获取到的极值点总数: ", ArraySize(g_points));
      for(int i = 0; i < ArraySize(g_points) && i < 5; i++) {
         Print("点#", i, " 时间: ", TimeToString(g_points[i].Time()), 
               " 类型: ", g_points[i].TypeAsString(),
               " 价格: ", DoubleToString(g_points[i].Value(), _Digits));
      }
      
      // 按时间降序排序，确保最近的极值点优先显示
      // 提取时间到临时数组
      datetime times[];
      ArrayResize(times, ArraySize(g_points));
      for(int i = 0; i < ArraySize(g_points); i++)
         times[i] = g_points[i].Time();
      
      // 对时间数组进行排序并获取索引
      int indices[];
      ArrayResize(indices, ArraySize(times));
      for(int i = 0; i < ArraySize(times); i++)
         indices[i] = i;
      
      // 手动实现冒泡排序 (按时间降序排列，最近的时间在前)
      for(int i = 0; i < ArraySize(times)-1; i++) {
         for(int j = i+1; j < ArraySize(times); j++) {
            if(times[i] < times[j]) {  // 改为 < 以实现降序排列
               // 交换时间
               datetime temp_time = times[i];
               times[i] = times[j];
               times[j] = temp_time;
               // 同步交换索引
               int temp_index = indices[i];
               indices[i] = indices[j];
               indices[j] = temp_index;
            }
         }
      }
      
      // 根据索引重新排列 g_points
      CZigzagExtremumPoint temp_points[];
      ArrayResize(temp_points, ArraySize(g_points));
      for(int i = 0; i < ArraySize(g_points); i++)
         temp_points[i] = g_points[indices[i]];
      
      // 复制回原数组
      for(int i = 0; i < ArraySize(temp_points); i++)
         g_points[i] = temp_points[i];
      
      // 调试信息：显示排序后的前几个点
      Print("排序后的前5个点:");
      for(int i = 0; i < ArraySize(g_points) && i < 5; i++) {
         Print("点#", i, " 时间: ", TimeToString(g_points[i].Time()), 
               " 类型: ", g_points[i].TypeAsString(),
               " 价格: ", DoubleToString(g_points[i].Value(), _Digits));
      }
      
      // 只取前10个点
      int points_to_show = MathMin(ArraySize(g_points), 10);
      
      // 显示极值点信息
      Print("成功获取最近的", InpPointsCount, "个极值点，实际显示:", points_to_show, "个");
      
      // 首先创建一个ZigZag线条连接所有点
      Print("开始创建连接线...");
      for(int i = 1; i < points_to_show; i++)
      {
         string line_name = StringFormat("ExtremumPoint_Line_%d", i);
         
         // 确保删除可能存在的旧对象
         ObjectDelete(0, line_name);
         
         // 创建新的线条对象
         bool created = ObjectCreate(0, line_name, OBJ_TREND, 0, 
                     g_points[i-1].Time(), g_points[i-1].Value(),
                     g_points[i].Time(), g_points[i].Value());
         
         if(!created)
         {
            Print("创建线条失败: ", line_name, ", 错误码: ", GetLastError());
            continue;
         }
         
         color line_color = clrMagenta;
         ObjectSetInteger(0, line_name, OBJPROP_COLOR, line_color);
         ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, line_name, OBJPROP_BACK, false); // 改为前景显示
         ObjectSetInteger(0, line_name, OBJPROP_SELECTABLE, true);
         ObjectSetInteger(0, line_name, OBJPROP_HIDDEN, false);
         ObjectSetInteger(0, line_name, OBJPROP_ZORDER, 50);
         
         Print("已创建线条: ", line_name, " 从 ", TimeToString(g_points[i-1].Time()), " 到 ", TimeToString(g_points[i].Time()));
      }
      
      // 强制刷新图表
      ChartRedraw();
      
      // 然后为每个点创建标记
      Print("开始创建极值点标记...");
      for(int i = 0; i < points_to_show; i++)
      {
         string point_info = StringFormat(
            "#%d: %s, 时间周期: %s, 时间: %s, 序号: %d, 值: %s", 
            i+1,
            g_points[i].TypeAsString(),
            EnumToString(g_points[i].Timeframe()),
            TimeToString(g_points[i].Time()),
            TimeToString(g_points[i].Time(), TIME_DATE|TIME_MINUTES),
            g_points[i].BarIndex(),
            DoubleToString(g_points[i].Value(), _Digits)
         );
         
         Print(point_info);
         
         // 在图表上添加标签
         string label_name = StringFormat("ExtremumPoint_%d", i);
         string label_type = g_points[i].IsPeak() ? "峰值" : "谷值";
         color label_color = g_points[i].IsPeak() ? clrDodgerBlue : clrRed;
         
         // 获取K线序号
         int bar_index = g_points[i].BarIndex();
         
         // 确保删除可能存在的旧对象
         ObjectDelete(0, label_name);
         
         // 创建标签 - 使用买卖箭头对象，这是MT5中最明显的图表对象
         ENUM_OBJECT obj_type = g_points[i].IsPeak() ? OBJ_ARROW_SELL : OBJ_ARROW_BUY;
         bool created = ObjectCreate(0, label_name, obj_type, 0, g_points[i].Time(), g_points[i].Value());
         
         if(!created)
         {
            Print("创建标记失败: ", label_name, ", 错误码: ", GetLastError());
            continue;
         }
         
         // 设置文本颜色更加鲜明
         color bright_color = g_points[i].IsPeak() ? clrDeepSkyBlue : clrCrimson;
         
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
            price_diff = MathAbs(g_points[i].Value() - g_points[i-1].Value());
            // 转换为点数
            points_diff = (int)(price_diff / point_value);
            
            // 获取当前K线与前一个极值点K线之间的距离
            bars_diff = MathAbs(g_points[i].BarIndex() - g_points[i-1].BarIndex());
            
            tooltip = StringFormat("K线序号: %d\n时间: %s\n类型: %s\n价格: %s\n与前点价差: %d点\nK线距离: %d根", 
                                  bar_index, 
                                  TimeToString(g_points[i].Time(), TIME_DATE|TIME_MINUTES),
                                  label_type,
                                  DoubleToString(g_points[i].Value(), _Digits),
                                  points_diff,
                                  bars_diff);
         } else {
            // 第一个点没有前一个点，只显示基本信息
            tooltip = StringFormat("K线序号: %d\n时间: %s\n类型: %s\n价格: %s", 
                                 bar_index, 
                                 TimeToString(g_points[i].Time(), TIME_DATE|TIME_MINUTES),
                                 label_type,
                                 DoubleToString(g_points[i].Value(), _Digits));
         }
         // 确保tooltip已设置并可见
         ObjectSetString(0, label_name, OBJPROP_TOOLTIP, tooltip);
         ObjectSetInteger(0, label_name, OBJPROP_SELECTABLE, true); // 设置为可选择以便鼠标事件检测
         ObjectSetInteger(0, label_name, OBJPROP_HIDDEN, false);   // 确保不隐藏
         ObjectSetInteger(0, label_name, OBJPROP_BACK, false);     // 确保在前景显示
         
         // 设置其他属性
         ObjectSetInteger(0, label_name, OBJPROP_COLOR, bright_color);
         ObjectSetInteger(0, label_name, OBJPROP_WIDTH, InpMarkerSize);  // 使用用户定义的大小
         ObjectSetInteger(0, label_name, OBJPROP_ANCHOR, ANCHOR_CENTER);
         ObjectSetInteger(0, label_name, OBJPROP_HIDDEN, false);     // 在对象列表中显示
         ObjectSetInteger(0, label_name, OBJPROP_BACK, false);       // 确保在前景显示
         ObjectSetInteger(0, label_name, OBJPROP_ZORDER, 100);       // 设置高Z顺序，确保在最前面显示
         
         // 额外添加一个文本标签，确保即使箭头不显示，文本也会显示
         string text_label_name = StringFormat("ExtremumPoint_Text_%d", i);
         string text_content = g_points[i].IsPeak() ? "P" : "B";
         
         // 确保删除可能存在的旧对象
         ObjectDelete(0, text_label_name);
         
         bool text_created = ObjectCreate(0, text_label_name, OBJ_TEXT, 0, g_points[i].Time(), g_points[i].Value());
         
         if(!text_created)
         {
            Print("创建文本标签失败: ", text_label_name, ", 错误码: ", GetLastError());
         }
         else
         {
            ObjectSetString(0, text_label_name, OBJPROP_TEXT, text_content);
            ObjectSetInteger(0, text_label_name, OBJPROP_COLOR, bright_color);
            ObjectSetInteger(0, text_label_name, OBJPROP_FONTSIZE, 14);
            ObjectSetInteger(0, text_label_name, OBJPROP_ANCHOR, ANCHOR_CENTER);
            ObjectSetInteger(0, text_label_name, OBJPROP_ZORDER, 101);  // 确保文本在箭头上面
            ObjectSetInteger(0, text_label_name, OBJPROP_SELECTABLE, true);
            ObjectSetInteger(0, text_label_name, OBJPROP_HIDDEN, false);
            
            Print("已创建文本标签: ", text_label_name, " 在位置 ", TimeToString(g_points[i].Time()), ", ", DoubleToString(g_points[i].Value(), _Digits));
         }
         
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
            Print("找到对象: ", name);
            
            // 确保对象可见性
            ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
            ObjectSetInteger(0, name, OBJPROP_BACK, false);
            ObjectSetInteger(0, name, OBJPROP_ZORDER, 100);
         }
      }
      
      // 输出确认信息
      Print("已在图表上创建 ", created_objects, " 个图表对象，预期数量: ", points_to_show * 3); // 每个点有线条、箭头和文本
      
      // 确保图表处于前台
      long chart_id = ChartID();
      ChartSetInteger(chart_id, CHART_BRING_TO_TOP, true);
      
      // 启用图表事件处理
      ChartSetInteger(chart_id, CHART_EVENT_MOUSE_MOVE, true);
      
      // 设置图表属性，确保对象可见
      ChartSetInteger(chart_id, CHART_SHOW_OBJECT_DESCR, true); // 显示对象描述
      ChartSetInteger(chart_id, CHART_FOREGROUND, false);       // 确保价格在前景
      
      // 再次刷新图表
      ChartRedraw();
      
      // 添加调试信息
      Print("极值点显示逻辑已完成，请检查图表。");
      
      // 提示用户
      Print("请移动鼠标到P/B点查看详细信息");
      
      // 强制重绘所有对象
      for(int i = 0; i < ObjectsTotal(0); i++)
      {
         string name = ObjectName(0, i);
         if(StringFind(name, "ExtremumPoint_") == 0)
         {
            // 触发对象重绘
            color obj_color = clrNONE;
            long tmp_color;
            if(ObjectGetInteger(0, name, OBJPROP_COLOR, 0, tmp_color))
            {
               obj_color = (color)tmp_color;
               ObjectSetInteger(0, name, OBJPROP_COLOR, obj_color);
            }
         }
      }
      
      // 最终刷新
      ChartRedraw();
   }
   else
   {
      Print("无法获取极值点对象");
   }
}
//+------------------------------------------------------------------+