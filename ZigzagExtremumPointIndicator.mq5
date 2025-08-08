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
#include <Object.mqh>
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

//+------------------------------------------------------------------+
// 全局变量
//+------------------------------------------------------------------+
// 存储极值点数组，用于鼠标事件处理
CZigzagExtremumPoint g_points[];
// 保存上一次的图表周期，用于检测周期变化
ENUM_TIMEFRAMES g_lastTimeframe = PERIOD_CURRENT;

//+------------------------------------------------------------------+
//| 脚本程序起始函数                                                   |
//+------------------------------------------------------------------+
// 删除所有标签
void DeleteAllLabels()
{
   // 删除所有图表对象 - 使用更彻底的方法
   int deleted = ObjectsDeleteAll(0, "ExtremumPoint_", -1, -1);
   
   // 强制刷新图表
   ChartRedraw(0);
   
   Print("已清除所有之前的图表标记，共删除 ", deleted, " 个对象");
}

//+------------------------------------------------------------------+
//| 图表事件处理                                                      |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   // 处理鼠标移动事件
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
      
      // 如果找到了点，显示提示信息
      if(found_index >= 0)
      {
         // 获取当前品种的点值
         double point_value = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         
         // 构建详细信息文本
         string info_text = "";
         info_text += "类型: " + g_points[found_index].TypeAsString() + "\n";
         info_text += "时间: " + TimeToString(g_points[found_index].Time(), TIME_DATE|TIME_MINUTES) + "\n";
         info_text += "价格: " + DoubleToString(g_points[found_index].Value(), _Digits) + "\n";
         info_text += "K线序号: " + IntegerToString(g_points[found_index].BarIndex()) + "\n";
         
         // 计算与相邻点的差异
         if(found_index > 0)
         {
            // 与前一个点比较
            double price_diff = MathAbs(g_points[found_index].Value() - g_points[found_index-1].Value());
            int points_diff = (int)(price_diff / point_value);
            int bars_diff = MathAbs(g_points[found_index].BarIndex() - g_points[found_index-1].BarIndex());
            
            info_text += "与前点价差: " + IntegerToString(points_diff) + "点\n";
            info_text += "K线距离: " + IntegerToString(bars_diff) + "根\n";
         }
         
         if(found_index < ArraySize(g_points) - 1)
         {
            // 与后一个点比较
            double price_diff = MathAbs(g_points[found_index].Value() - g_points[found_index+1].Value());
            int points_diff = (int)(price_diff / point_value);
            int bars_diff = MathAbs(g_points[found_index].BarIndex() - g_points[found_index+1].BarIndex());
            
            info_text += "与后点价差: " + IntegerToString(points_diff) + "点\n";
            info_text += "K线距离: " + IntegerToString(bars_diff) + "根\n";
         }
         
         // 显示提示信息
         Comment(info_text);
      }
      else
      {
         // 没有选中任何点，清除提示信息
         Comment("");
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
   
   // 清理之前的标签和数据
   DeleteAllLabels();
   ArrayFree(g_points); // 清空全局数组
   
   // 确保图表处于正确状态
   long chart_id = ChartID();
   ChartSetInteger(chart_id, CHART_AUTOSCROLL, false);  // 禁用自动滚动
   ChartSetInteger(chart_id, CHART_FOREGROUND, false);  // 确保价格在前景
   ChartSetInteger(chart_id, CHART_SHOW_OBJECT_DESCR, true); // 显示对象描述
   
   // 启用图表事件处理
   ChartSetInteger(chart_id, CHART_EVENT_MOUSE_MOVE, true);
   
   // 保存当前周期
   g_lastTimeframe = (ENUM_TIMEFRAMES)Period();
   
   // 添加短暂延迟确保图表准备就绪
   Sleep(50);
   
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
   // 检查周期是否发生变化
   ENUM_TIMEFRAMES current_timeframe = (ENUM_TIMEFRAMES)Period();
   if(g_lastTimeframe != current_timeframe)
   {
      Print("图表周期已更改，从 ", EnumToString(g_lastTimeframe), " 到 ", EnumToString(current_timeframe));
      Print("周期切换前清除所有现有标记");
      DeleteAllLabels(); // 切换周期时清除所有标记，确保重新计算
      ArrayFree(g_points); // 清空全局数组
      g_lastTimeframe = current_timeframe;
      // 重新计算并显示极值点
      Print("开始重新计算极值点...");
      CalculateAndDisplayPoints();
      Print("周期切换后计算完成");
      return(rates_total);
   }
   
   // 检查是否需要重新计算
   static int recalc_counter = 0;
   static bool first_calculation = true;
   
   // 如果是首次计算或者每隔一定周期重新计算
   // 注意：切换周期时prev_calculated会变为0，但我们不希望清除已有标记
   if((prev_calculated == 0 && first_calculation) || recalc_counter >= 10)
   {
      Print("触发重新计算，prev_calculated=", prev_calculated, ", recalc_counter=", recalc_counter);
      // 重新计算并显示极值点
      CalculateAndDisplayPoints();
      recalc_counter = 0;
      first_calculation = false;
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
   
   // 确保图表已准备就绪
   Sleep(20);
   
   // 检查是否已经有极值点对象
   int existing_objects = 0;
   for(int i = 0; i < ObjectsTotal(0); i++)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, "ExtremumPoint_") == 0)
      {
         existing_objects++;
      }
   }
   
   // 只有在没有现有对象时才清除标签
   if(existing_objects == 0)
   {
      Print("没有找到现有极值点对象，清理并重新创建...");
      DeleteAllLabels();
      
      // 强制刷新图表，确保之前的对象被清除
      ChartRedraw(0);
   }
   else
   {
      Print("找到", existing_objects, "个现有极值点对象，保留现有标记...");
   }
   
   // 清空全局极值点数组
   ArrayFree(g_points);
   
   // 创建ZigzagCalculator实例
   CZigzagCalculator zigzag(InpDepth, InpDeviation, InpBackstep);
   
   // 为当前图表计算ZigZag值
   Print("正在计算ZigZag值...");
   // 只传递当前图表的品种和时间周期，数据由ZigzagCalculator类获取
   if(!zigzag.CalculateForCurrentChart(1000))
   {
      Print("计算ZigZag值失败");
      return;
   }
   
   // 获取极值点对象
   Print("正在获取极值点...");
   Print("当前周期: ", EnumToString((ENUM_TIMEFRAMES)Period()));
   if(zigzag.GetRecentExtremumPoints(g_points, InpPointsCount))
   {
      // 调试信息：显示所有获取到的点的时间
      Print("获取到的极值点总数: ", ArraySize(g_points));
      for(int i = 0; i < ArraySize(g_points) && i < 5; i++) {
         // 获取正确的价格点位
         double point_price = g_points[i].Value();
         // 根据当前品种的点值进行调整
         double adjusted_price = NormalizeDouble(point_price, _Digits);
         // 更新价格值
         g_points[i].Value(adjusted_price);
         
         Print("点#", i, " 时间: ", TimeToString(g_points[i].Time()), 
               " 类型: ", g_points[i].TypeAsString(),
               " 价格: ", DoubleToString(g_points[i].Value(), _Digits),
               " K线索引: ", g_points[i].BarIndex());
      }
      
      // 注意：GetRecentExtremumPoints方法已经实现了按时间降序排序
      // 极值点已经按照从最近到最远的顺序排列，无需再次排序
      // 确保在所有时间周期下都保持一致的排序顺序
      
      // 调试信息：显示排序后的前几个点
      Print("排序后的前5个点:");
      for(int i = 0; i < ArraySize(g_points) && i < 5; i++) {
         // 确保价格正确显示
         double point_price = g_points[i].Value();
         // 根据当前品种的点值进行调整
         double adjusted_price = NormalizeDouble(point_price, _Digits);
         // 更新价格值
         g_points[i].Value(adjusted_price);
         
         Print("点#", i, " 时间: ", TimeToString(g_points[i].Time()), 
               " 类型: ", g_points[i].TypeAsString(),
               " 价格: ", DoubleToString(g_points[i].Value(), _Digits),
               " K线索引: ", g_points[i].BarIndex());
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
         
         // 检查时间值是否有效
         datetime time1 = g_points[i-1].Time();
         datetime time2 = g_points[i].Time();
         double price1 = g_points[i-1].Value();
         double price2 = g_points[i].Value();
         
         // 验证数据有效性
         if(time1 == 0 || time1 == WRONG_VALUE || time2 == 0 || time2 == WRONG_VALUE ||
            price1 == 0 || price2 == 0 || 
            !MathIsValidNumber(price1) || !MathIsValidNumber(price2))
         {
            Print("无效的数据值，跳过创建线条: ", line_name, 
                  " time1=", time1, " time2=", time2, 
                  " price1=", price1, " price2=", price2);
            continue;
         }
         
         // 确保时间顺序正确（time1应该早于time2）
         if(time1 > time2) {
            // 交换数据
            datetime temp_time = time1;
            time1 = time2;
            time2 = temp_time;
            
            double temp_price = price1;
            price1 = price2;
            price2 = temp_price;
         }
         
         // 创建新的线条对象
         bool created = ObjectCreate(0, line_name, OBJ_TREND, 0, 
                     time1, price1,
                     time2, price2);
         
         if(!created)
         {
            int error = GetLastError();
            // 添加重试机制
            if(error == 4101) // ERR_CHART_NOREPLY
            {
               Sleep(10); // 短暂等待
               created = ObjectCreate(0, line_name, OBJ_TREND, 0, time1, price1, time2, price2);
               if(!created)
               {
                  error = GetLastError();
                  Print("重试后仍创建线条失败: ", line_name, ", 错误码: ", error);
               }
            }
            else
            {
               Print("创建线条失败: ", line_name, ", 错误码: ", error);
            }
            
            if(!created) continue;
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
         
         Print("已创建线条: ", line_name, " 从 ", TimeToString(time1), " 到 ", TimeToString(time2),
               " 价格从 ", DoubleToString(price1, _Digits), " 到 ", DoubleToString(price2, _Digits));
      }
      
      // 强制刷新图表
      ChartRedraw(0);
      
      // 然后为每个点创建标记
      Print("开始创建极值点标记...");
      for(int i = 0; i < points_to_show; i++)
      {
         // 在图表上添加标签
         string label_name = StringFormat("ExtremumPoint_%d", i);
         string label_type = g_points[i].IsPeak() ? "峰值" : "谷值";
         color label_color = g_points[i].IsPeak() ? clrDodgerBlue : clrRed;
         
         // 获取K线序号
         int bar_index = g_points[i].BarIndex();
         
         // 确保删除可能存在的旧对象
         ObjectDelete(0, label_name);
         
         // 检查时间值是否有效
         datetime point_time = g_points[i].Time();
         double point_price = g_points[i].Value();
         
         // 验证数据有效性
         if(point_time == 0 || point_time == WRONG_VALUE ||
            point_price == 0 || !MathIsValidNumber(point_price))
         {
            Print("无效的数据值，跳过创建标记: ", label_name, 
                  " time=", point_time, " price=", point_price);
            continue;
         }
         
         // 创建标签 - 使用买卖箭头对象，这是MT5中最明显的图表对象
         ENUM_OBJECT obj_type = g_points[i].IsPeak() ? OBJ_ARROW_SELL : OBJ_ARROW_BUY;
         bool created = ObjectCreate(0, label_name, obj_type, 0, point_time, point_price);
         
         if(!created)
         {
            int error = GetLastError();
            // 添加重试机制
            if(error == 4101) // ERR_CHART_NOREPLY
            {
               Sleep(10); // 短暂等待
               created = ObjectCreate(0, label_name, obj_type, 0, point_time, point_price);
               if(!created)
               {
                  error = GetLastError();
                  Print("重试后仍创建标记失败: ", label_name, ", 错误码: ", error);
               }
            }
            else
            {
               Print("创建标记失败: ", label_name, ", 错误码: ", error);
            }
            
            if(!created) continue;
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
         
         bool text_created = ObjectCreate(0, text_label_name, OBJ_TEXT, 0, point_time, point_price);
         if(text_created) {
            ObjectSetInteger(0, text_label_name, OBJPROP_TIMEFRAMES, PERIOD_D1);
         }
         
         if(!text_created)
         {
            int error = GetLastError();
            // 添加重试机制
            if(error == 4101) // ERR_CHART_NOREPLY
            {
               Sleep(10); // 短暂等待
               text_created = ObjectCreate(0, text_label_name, OBJ_TEXT, 0, point_time, point_price);
               if(!text_created)
               {
                  error = GetLastError();
                  Print("重试后仍创建文本标签失败: ", text_label_name, ", 错误码: ", error);
               }
            }
            else
            {
               Print("创建文本标签失败: ", text_label_name, ", 错误码: ", error);
            }
         }
         
         if(text_created)
         {
            ObjectSetString(0, text_label_name, OBJPROP_TEXT, text_content);
            ObjectSetInteger(0, text_label_name, OBJPROP_COLOR, bright_color);
            ObjectSetInteger(0, text_label_name, OBJPROP_FONTSIZE, 14);
            ObjectSetInteger(0, text_label_name, OBJPROP_ANCHOR, ANCHOR_CENTER);
            ObjectSetInteger(0, text_label_name, OBJPROP_ZORDER, 101);  // 确保文本在箭头上面
            ObjectSetInteger(0, text_label_name, OBJPROP_SELECTABLE, true);
            ObjectSetInteger(0, text_label_name, OBJPROP_HIDDEN, false);
            
            Print("已创建文本标签: ", text_label_name, " 在位置 ", TimeToString(point_time), ", ", DoubleToString(point_price, _Digits));
         }
         
         // 添加调试信息
         PrintFormat("已创建对象 %s，tooltip内容: %s", label_name, tooltip);
         
         // 立即刷新当前对象
         ChartRedraw(0);
      }
      
      // 强制刷新图表
      ChartRedraw(0);
      
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
      ChartRedraw(0);
      
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
      ChartRedraw(0);
   }
   else
   {
      Print("无法获取极值点对象");
   }
}
//+------------------------------------------------------------------+