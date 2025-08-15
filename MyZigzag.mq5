//+------------------------------------------------------------------+
//|                                                    MyZigzag.mq5 |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

//--- 包含文件
#include "ZigzagCalculator.mqh"
#include "GraphicsUtils.mqh"

//--- 指标设置
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   2
#property indicator_type1   DRAW_COLOR_ZIGZAG  // 当前周期
#property indicator_color1  clrDodgerBlue,clrRed
#property indicator_type2   DRAW_COLOR_ZIGZAG  // 4小时周期
#property indicator_color2  clrLime,clrMagenta

//--- 输入参数
input int InpDepth    =12;  // 深度
input int InpDeviation=5;   // 偏差
input int InpBackstep =3;   // 回溯步数
input bool InpShowLabels=true; // 显示峰谷值文本标签
input color InpLabelColor=clrWhite; // 标签文本颜色
input bool InpShow4H=true;  // 显示4小时周期ZigZag
input color InpLabel4HColor=clrYellow; // 4小时周期标签颜色

//--- 声明ZigZag计算器指针
CZigzagCalculator *calculator = NULL;      // 当前周期计算器
CZigzagCalculator *calculator4H = NULL;    // 4H周期计算器

//+------------------------------------------------------------------+
//| 自定义指标初始化函数                                             |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- 初始化ZigZag计算器
   calculator = new CZigzagCalculator(InpDepth, InpDeviation, InpBackstep, 3, PERIOD_CURRENT); // 当前周期
   calculator4H = new CZigzagCalculator(InpDepth, InpDeviation, InpBackstep, 3, PERIOD_H4);    // 4H周期
   
//--- 初始化标签管理器 - 传入两种不同的颜色
   CLabelManager::Init(InpLabelColor, InpLabel4HColor);
   
//--- 指标缓冲区 mapping
   SetIndexBuffer(0, calculator.ZigzagPeakBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, calculator.ZigzagBottomBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, calculator.ColorBuffer, INDICATOR_COLOR_INDEX);
   
//--- 设置精度
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
//--- DataWindow和指标子窗口标签的名称
   string short_name = StringFormat("MyZigzag(%d,%d,%d)", InpDepth, InpDeviation, InpBackstep);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   PlotIndexSetString(0, PLOT_LABEL, short_name);
//--- 设置空值
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);  
//--- 关闭图表网格
   ChartSetInteger(0, CHART_SHOW_GRID, 0);   
//--- 关闭图表交易水平线显示
   ChartSetInteger(0, CHART_SHOW_TRADE_LEVELS, false);
  }

//+------------------------------------------------------------------+
//| 自定义指标释放函数                                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // 释放计算器对象
   if(calculator != NULL)
     {
      delete calculator;
      calculator = NULL;
     }
   
   // 释放4H周期计算器对象
   if(calculator4H != NULL)
     {
      delete calculator4H;
      calculator4H = NULL;
     }
     
   // 删除所有文本标签
   CLabelManager::DeleteAllLabels("ZigzagLabel_");
   CLabelManager::DeleteAllLabels("ZigzagLabel4H_"); // 添加删除4H周期标签
   
   // 清理图表对象和自定义图形
   ObjectsDeleteAll(0, "ZigzagLabel_");
   ObjectsDeleteAll(0, "ZigzagLabel4H_");
 
  }

//+------------------------------------------------------------------+
//| ZigZag计算                                                      |
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
   if(rates_total < 100)
      return(0);
      
   // 初始化缓冲区
   if(prev_calculated == 0)
     {
      ArrayInitialize(calculator.ZigzagPeakBuffer, 0.0);
      ArrayInitialize(calculator.ZigzagBottomBuffer, 0.0);
      ArrayInitialize(calculator.ColorBuffer, 0.0);
     }
   
   // 计算当前周期ZigZag
   if(calculator != NULL)
     {
      calculator.Calculate(high, low, rates_total, prev_calculated);
      
      // 声明4H周期极值点数组（提升作用域到整个函数）
      CZigzagExtremumPoint points4H[];
      bool has4HPoints = false;
      
      // 计算4H周期ZigZag
      if(calculator4H != NULL && InpShow4H)
        {
         // 使用CalculateForSymbol方法直接计算4H周期数据
         int result = calculator4H.CalculateForSymbol(Symbol(), PERIOD_H4, 100);
         
         // 检查计算结果
         if(result < 0)
           {
            Print("无法计算4H周期ZigZag，错误代码: ", result);
           }
         else
           {
            // 获取4H周期极值点
            has4HPoints = calculator4H.GetExtremumPoints(points4H);
            if(!has4HPoints)
              {
               Print("无法获取4H周期极值点");
              }
           }
        }
         
      // 如果需要显示文本标签
      if(InpShowLabels)
        {
         // 清除旧标签
         if(prev_calculated == 0)
           {
            CLabelManager::DeleteAllLabels("ZigzagLabel_");
            CLabelManager::DeleteAllLabels("ZigzagLabel4H_");
           }
            
         // 获取当前周期极值点数组
         CZigzagExtremumPoint points[];
         if(calculator.GetExtremumPoints(points))
           {          
            
            // 添加当前周期的标签
            for(int i = 0; i < ArraySize(points); i++)
              {
               //检查这个值是否在4H小时周期峰谷值列表中出现
               bool foundIn4H = false;
               double tolerance = 0.0001; // 价格匹配的容差
               
               // 如果4H周期计算器存在且已启用4H显示且有4H点位数据
               if(calculator4H != NULL && InpShow4H && has4HPoints && ArraySize(points4H) > 0)
                 {
                  // 遍历4H周期的所有极值点
                  for(int j = 0; j < ArraySize(points4H); j++)
                    {
                     // 如果价格在容差范围内匹配，则认为是同一个价格点
                     if(MathAbs(points[i].Value() - points4H[j].Value()) < tolerance)
                       {
                        foundIn4H = true;
                        break;
                       }
                    }
                 }
               
               string labelName = "ZigzagLabel_" + IntegerToString(i);
               string labelText;
               
               // 如果这个价格出现在4H周期中则将标签文本变成H4:价格
               if(foundIn4H)
                 {
                  labelText = StringFormat("H4: %s", 
                     DoubleToString(points[i].Value(), _Digits));
                  labelText += "\n序号: " + IntegerToString(points[i].BarIndex());
                 }
               else
                 {
                  // 将周期名称转换为简写形式
                  string periodShort = "";
                  ENUM_TIMEFRAMES currentPeriod = Period();
                  
                  switch(currentPeriod)
                    {
                     case PERIOD_M1:  periodShort = "M1"; break;
                     case PERIOD_M5:  periodShort = "M5"; break;
                     case PERIOD_M15: periodShort = "M15"; break;
                     case PERIOD_M30: periodShort = "M30"; break;
                     case PERIOD_H1:  periodShort = "H1"; break;
                     case PERIOD_H4:  periodShort = "H4"; break;
                     case PERIOD_D1:  periodShort = "D1"; break;
                     case PERIOD_W1:  periodShort = "W1"; break;
                     case PERIOD_MN1: periodShort = "MN"; break;
                     default: periodShort = EnumToString(currentPeriod); break;
                    }
                  
                  labelText = StringFormat("%s: %s",
                     periodShort,              
                     DoubleToString(points[i].Value(), _Digits));
                  labelText += "\n序号: " + IntegerToString(points[i].BarIndex());
                 }

               // 创建价格标签
               string priceLabel = "";
               
               // 将周期名称转换为简写形式
               string periodShort = "";
               ENUM_TIMEFRAMES currentPeriod = Period();
               
               switch(currentPeriod)
                 {
                  case PERIOD_M1:  periodShort = "M1"; break;
                  case PERIOD_M5:  periodShort = "M5"; break;
                  case PERIOD_M15: periodShort = "M15"; break;
                  case PERIOD_M30: periodShort = "M30"; break;
                  case PERIOD_H1:  periodShort = "H1"; break;
                  case PERIOD_H4:  periodShort = "H4"; break;
                  case PERIOD_D1:  periodShort = "D1"; break;
                  case PERIOD_W1:  periodShort = "W1"; break;
                  case PERIOD_MN1: periodShort = "MN"; break;
                  default: periodShort = EnumToString(currentPeriod); break;
                 }
               
               if(foundIn4H)
                  priceLabel = StringFormat("H4: %s", DoubleToString(points[i].Value(), _Digits));
               else
                  priceLabel = StringFormat("%s: %s", periodShort, DoubleToString(points[i].Value(), _Digits));
               
               // 创建工具提示内容，显示线序和时间
               string tooltipText = StringFormat("线序: %d\n时间: %s\n价格: %s\n类型: %s", 
                                               points[i].BarIndex(),
                                               TimeToString(points[i].Time(), TIME_DATE|TIME_MINUTES|TIME_SECONDS),
                                               DoubleToString(points[i].Value(), _Digits),
                                               points[i].IsPeak() ? "峰值" : "谷值");
               
               // 只创建价格标签，不再创建序号标签，但添加工具提示
               CLabelManager::CreateTextLabel(
                  labelName,
                  priceLabel,
                  points[i].Time(),
                  points[i].Value(),
                  points[i].IsPeak(),
                  foundIn4H,
                  NULL,    // 使用默认颜色
                  NULL,    // 使用默认字体
                  0,       // 使用默认字体大小
                  0,       // X轴偏移量为0（居中显示时不需要偏移）
                  true,    // 启用居中显示
                  tooltipText  // 添加工具提示
               );
              }
           }
        }
     }
   
   // 返回计算的柱数
   return(rates_total);
  }

//+------------------------------------------------------------------+