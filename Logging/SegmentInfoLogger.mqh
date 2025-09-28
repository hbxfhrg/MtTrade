#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Files/File.mqh>
#include "..\TradeBasePoint.mqh"
#include "..\ZigzagSegment.mqh"
// 添加ENUM_TRADE_ACTION枚举的包含
#include "..\EnumDefinitions.mqh"

// 添加将交易动作枚举转换为字符串的函数
string TradeActionToString(ENUM_TRADE_ACTION action)
{
   switch(action)
   {
      case TRADE_ACTION_PENDING_ORDER: return "挂单";
      case TRADE_ACTION_ENTRY:         return "入场";
      case TRADE_ACTION_EXIT:          return "出场";
      case TRADE_ACTION_MODIFY_ORDER:  return "改价";
      case TRADE_ACTION_CANCEL:        return "取消";
      default:                         return "未知";
   }
}

// 线段信息CSV记录器
class CSegmentInfoLogger
{
private:
   string m_filename;
   bool m_initialized;

public:
   CSegmentInfoLogger(string filename = "segment_info.csv")
   {
      m_filename = filename;
      m_initialized = false;
      Initialize();
   }
   
   void Initialize()
   {
      if(!m_initialized)
      {
         int file_handle = FileOpen(m_filename, FILE_WRITE|FILE_CSV|FILE_COMMON);
         if(file_handle != INVALID_HANDLE)
         {
            // 检查文件是否包含表头，如果没有则写入表头
            bool hasHeader = false;
            if(FileSize(file_handle) > 0)
            {
               // 读取第一行检查是否包含表头
               FileSeek(file_handle, 0, SEEK_SET);
               string firstLine = FileReadString(file_handle);
               if(StringFind(firstLine, "TradeTime") != -1 && StringFind(firstLine, "Timeframe") != -1)
               {
                  hasHeader = true;
               }
            }
            
            // 如果文件为空或不包含表头，则写入表头
            if(!hasHeader)
            {
               // 写入CSV头部
               FileSeek(file_handle, 0, SEEK_END);
               
               // 写入CSV头部
               FileWriteString(file_handle, "TradeTime");
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "OrderTicket");
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "PositionId");
               FileWriteString(file_handle, ";");
               
               // 参考点信息
               FileWriteString(file_handle, "ReferencePrice");
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "ReferenceTime");
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "ReferenceBarIndex");
               FileWriteString(file_handle, ";");
               
               // 时间周期信息
               FileWriteString(file_handle, "Timeframe");
               FileWriteString(file_handle, ";");
               
               // 线段信息
               FileWriteString(file_handle, "SegmentSide");  // 线段方向（Left/Right）
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "SegmentIndex"); // 线段序号
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "StartPrice");   // 起始价格
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "EndPrice");     // 结束价格
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "Amplitude");    // 幅度
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "Direction");    // 方向
               FileWriteString(file_handle, ";");
               
               // 交易操作信息
               FileWriteString(file_handle, "TradeAction");  // 交易操作类型
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "TradePrice");   // 交易价格
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "TradeVolume");  // 交易量
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "TradeComment"); // 交易注释
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "TradeStatus"); // 交易状态
               FileWriteString(file_handle, "\n");
            }
            
            FileClose(file_handle);
            m_initialized = true;
            Print("SegmentInfoLogger: 文件初始化成功 - ", m_filename);
         }
         else
         {
            Print("SegmentInfoLogger: 文件打开失败 - ", m_filename, ", 错误: ", GetLastError());
         }
      }
   }
   
   // 记录线段信息
   bool LogSegmentInfo(datetime tradeTime, ulong orderTicket, long positionId, 
                      CTradeBasePoint &tradeBasePoint)
   {
      // 定义时间周期数组
      string timeframeNames[] = {"M5", "M15", "M30", "H1"};
      ENUM_TIMEFRAMES timeframes[] = {PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1};
      
      // 为每个时间周期记录信息
      for(int i = 0; i < ArraySize(timeframes); i++)
      {
         CZigzagSegment* leftSegments[];
         CZigzagSegment* rightSegments[];
         
         // 获取指定时间周期的缓存线段（从已缓存的数据中获取）
         if(tradeBasePoint.GetTimeframeCachedSegments(timeframes[i], leftSegments, rightSegments))
         {
            // 写入CSV文件
            if(!WriteSegmentInfoToCSV(tradeTime, orderTicket, positionId, tradeBasePoint, 
                                    timeframes[i], timeframeNames[i], leftSegments, rightSegments))
            {
               Print("SegmentInfoLogger: 写入线段信息失败 - 时间周期: ", timeframeNames[i]);
               return false;
            }
         }
      }
      
      return true;
   }
   
   // 记录交易操作动作（挂单、入场、出场、改价、取消）
   bool LogTradeAction(ENUM_TRADE_ACTION action, datetime actionTime, 
                      ulong orderTicket, long positionId, string symbol,
                      double price, double volume, string comment)
   {
      // 生成唯一的ID（使用时间戳+订单号）
      string id = StringFormat("%d_%d", (int)TimeCurrent(), (int)orderTicket);
      
      // 将动作枚举转换为字符串
      string actionStr = TradeActionToString(action);
      
      int file_handle = FileOpen(m_filename, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON);
      if(file_handle != INVALID_HANDLE)
      {
         FileSeek(file_handle, 0, SEEK_END);
         
         // 写入记录（使用线段信息CSV文件的格式，但只填写相关字段）
         // TradeTime
         FileWriteString(file_handle, TimeToString(actionTime, TIME_DATE|TIME_SECONDS));
         FileWriteString(file_handle, ";");
         
         // OrderTicket
         FileWriteString(file_handle, IntegerToString((int)orderTicket));
         FileWriteString(file_handle, ";");
         
         // PositionId
         FileWriteString(file_handle, IntegerToString((int)positionId));
         FileWriteString(file_handle, ";");
         
         // ReferencePrice (使用交易价格作为参考价格)
         FileWriteString(file_handle, DoubleToString(price, (int)_Digits));
         FileWriteString(file_handle, ";");
         
         // ReferenceTime (使用动作时间作为参考时间)
         FileWriteString(file_handle, TimeToString(actionTime, TIME_DATE|TIME_SECONDS));
         FileWriteString(file_handle, ";");
         
         // ReferenceBarIndex (设为-1表示不适用)
         FileWriteString(file_handle, "-1");
         FileWriteString(file_handle, ";");
         
         // Timeframe (设为空表示不适用)
         FileWriteString(file_handle, "");
         FileWriteString(file_handle, ";");
         
         // SegmentSide (使用动作类型作为线段方向)
         FileWriteString(file_handle, actionStr);
         FileWriteString(file_handle, ";");
         
         // SegmentIndex (设为0表示不适用)
         FileWriteString(file_handle, "0");
         FileWriteString(file_handle, ";");
         
         // StartPrice (使用交易价格作为起始价格)
         FileWriteString(file_handle, DoubleToString(price, (int)_Digits));
         FileWriteString(file_handle, ";");
         
         // EndPrice (设为空表示不适用)
         FileWriteString(file_handle, "");
         FileWriteString(file_handle, ";");
         
         // Amplitude (设为空表示不适用)
         FileWriteString(file_handle, "");
         FileWriteString(file_handle, ";");
         
         // Direction (设为空表示不适用)
         FileWriteString(file_handle, "");
         FileWriteString(file_handle, ";");
         
         // TradeStatus (设为空表示不适用)
         FileWriteString(file_handle, "");
         FileWriteString(file_handle, "\n");
         
         FileClose(file_handle);
         Print("SegmentInfoLogger: 交易动作记录已写入 - 动作: ", actionStr, ", PositionId: ", positionId);
         return true;
      }
      else
      {
         Print("SegmentInfoLogger: 交易动作记录写入失败 - 文件: ", m_filename, ", 错误: ", GetLastError());
         return false;
      }
   }
   
   // 记录交易操作动作和线段信息到同一行记录中
   bool LogTradeActionWithSegmentInfo(ENUM_TRADE_ACTION action, datetime actionTime, 
                                    ulong orderTicket, long positionId, string symbol,
                                    double price, double volume, string comment,
                                    CTradeBasePoint &tradeBasePoint,
                                    ENUM_TIMEFRAMES timeframe = PERIOD_H1, string tradeStatus = "")
   {
      // 获取指定时间周期的缓存线段
      CZigzagSegment* leftSegments[];
      CZigzagSegment* rightSegments[];
      
      if(!tradeBasePoint.GetTimeframeCachedSegments(timeframe, leftSegments, rightSegments))
      {
         Print("SegmentInfoLogger: 获取线段信息失败 - 时间周期: ", IntegerToString((int)timeframe));
         return false;
      }
      
      // 将动作枚举转换为字符串
      string actionStr = TradeActionToString(action);
      
      // 获取时间周期名称
      string timeframeName = "";
      switch(timeframe)
      {
         case PERIOD_M5:  timeframeName = "M5"; break;
         case PERIOD_M15: timeframeName = "M15"; break;
         case PERIOD_M30: timeframeName = "M30"; break;
         case PERIOD_H1:  timeframeName = "H1"; break;
         default: timeframeName = "Unknown"; break;
      }
      
      int file_handle = FileOpen(m_filename, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON);
      if(file_handle != INVALID_HANDLE)
      {
         FileSeek(file_handle, 0, SEEK_END);
         
         // 对于每个线段，创建一条包含交易操作信息的记录
         int leftCount = ArraySize(leftSegments);
         int rightCount = ArraySize(rightSegments);
         
         // 记录左侧线段信息
         for(int i = 0; i < leftCount && i < 10; i++)
         {
            if(leftSegments[i] != NULL)
            {
               // 基本交易信息
               FileWriteString(file_handle, TimeToString(actionTime, TIME_DATE|TIME_SECONDS));
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, IntegerToString((int)orderTicket));
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, IntegerToString((int)positionId));
               FileWriteString(file_handle, ";");
               
               // 参考点信息
               FileWriteString(file_handle, DoubleToString(tradeBasePoint.GetBasePrice(), (int)_Digits));
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, TimeToString(tradeBasePoint.GetBaseTime(), TIME_DATE|TIME_SECONDS));
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, IntegerToString(tradeBasePoint.GetBarIndex()));
               FileWriteString(file_handle, ";");
               
               // 时间周期信息
               FileWriteString(file_handle, timeframeName);
               FileWriteString(file_handle, ";");
               
               // 线段信息
               FileWriteString(file_handle, "Left");  // 线段方向
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, IntegerToString(i + 1)); // 线段序号
               FileWriteString(file_handle, ";");
               
               // 起始价格
               FileWriteString(file_handle, DoubleToString(leftSegments[i].m_start_point.value, (int)_Digits));
               FileWriteString(file_handle, ";");
               
               // 结束价格
               FileWriteString(file_handle, DoubleToString(leftSegments[i].m_end_point.value, (int)_Digits));
               FileWriteString(file_handle, ";");
               
               // 幅度（结束价格 - 起始价格）
               double amplitude = leftSegments[i].m_end_point.value - leftSegments[i].m_start_point.value;
               FileWriteString(file_handle, DoubleToString(amplitude, (int)_Digits));
               FileWriteString(file_handle, ";");
               
               // 方向
               FileWriteString(file_handle, leftSegments[i].IsUptrend() ? "UP" : "DOWN");
               FileWriteString(file_handle, ";");
               
               // 交易状态（默认为空）
               FileWriteString(file_handle, "");
               FileWriteString(file_handle, "\n");
            }
         }
         
         // 记录右侧线段信息
         for(int i = 0; i < rightCount && i < 10; i++)
         {
            if(rightSegments[i] != NULL)
            {
               // 基本交易信息
               FileWriteString(file_handle, TimeToString(actionTime, TIME_DATE|TIME_SECONDS));
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, IntegerToString((int)orderTicket));
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, IntegerToString((int)positionId));
               FileWriteString(file_handle, ";");
               
               // 参考点信息
               FileWriteString(file_handle, DoubleToString(tradeBasePoint.GetBasePrice(), (int)_Digits));
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, TimeToString(tradeBasePoint.GetBaseTime(), TIME_DATE|TIME_SECONDS));
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, IntegerToString(tradeBasePoint.GetBarIndex()));
               FileWriteString(file_handle, ";");
               
               // 时间周期信息
               FileWriteString(file_handle, timeframeName);
               FileWriteString(file_handle, ";");
               
               // 线段信息
               FileWriteString(file_handle, "Right");  // 线段方向
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, IntegerToString(i + 1)); // 线段序号
               FileWriteString(file_handle, ";");
               
               // 起始价格
               FileWriteString(file_handle, DoubleToString(rightSegments[i].m_start_point.value, (int)_Digits));
               FileWriteString(file_handle, ";");
               
               // 结束价格
               FileWriteString(file_handle, DoubleToString(rightSegments[i].m_end_point.value, (int)_Digits));
               FileWriteString(file_handle, ";");
               
               // 幅度（结束价格 - 起始价格）
               double amplitude = rightSegments[i].m_end_point.value - rightSegments[i].m_start_point.value;
               FileWriteString(file_handle, DoubleToString(amplitude, (int)_Digits));
               FileWriteString(file_handle, ";");
               
               // 方向
               FileWriteString(file_handle, rightSegments[i].IsUptrend() ? "UP" : "DOWN");
               FileWriteString(file_handle, ";");
               
               // 交易状态
               FileWriteString(file_handle, tradeStatus);
               FileWriteString(file_handle, "\n");
            }
         }
         
         // 如果没有线段信息，至少记录一条包含交易操作信息的记录
         if(leftCount == 0 && rightCount == 0)
         {
            // 基本交易信息
            FileWriteString(file_handle, TimeToString(actionTime, TIME_DATE|TIME_SECONDS));
            FileWriteString(file_handle, ";");
            FileWriteString(file_handle, IntegerToString((int)orderTicket));
            FileWriteString(file_handle, ";");
            FileWriteString(file_handle, IntegerToString((int)positionId));
            FileWriteString(file_handle, ";");
            
            // 参考点信息
            FileWriteString(file_handle, DoubleToString(tradeBasePoint.GetBasePrice(), (int)_Digits));
            FileWriteString(file_handle, ";");
            FileWriteString(file_handle, TimeToString(tradeBasePoint.GetBaseTime(), TIME_DATE|TIME_SECONDS));
            FileWriteString(file_handle, ";");
            FileWriteString(file_handle, IntegerToString(tradeBasePoint.GetBarIndex()));
            FileWriteString(file_handle, ";");
            
            // 时间周期信息
            FileWriteString(file_handle, timeframeName);
            FileWriteString(file_handle, ";");
            
            // 线段信息（无）
            FileWriteString(file_handle, "");
            FileWriteString(file_handle, ";");
            FileWriteString(file_handle, "0");
            FileWriteString(file_handle, ";");
            FileWriteString(file_handle, "");
            FileWriteString(file_handle, ";");
            FileWriteString(file_handle, "");
            FileWriteString(file_handle, ";");
            FileWriteString(file_handle, "");
            FileWriteString(file_handle, ";");
            FileWriteString(file_handle, "");
            FileWriteString(file_handle, ";");
            
            // 交易操作信息
            FileWriteString(file_handle, actionStr);
            FileWriteString(file_handle, ";");
            FileWriteString(file_handle, DoubleToString(price, (int)_Digits));
            FileWriteString(file_handle, ";");
            FileWriteString(file_handle, DoubleToString(volume, 2));
            FileWriteString(file_handle, ";");
            FileWriteString(file_handle, comment);
            FileWriteString(file_handle, ";");
            FileWriteString(file_handle, tradeStatus);
            FileWriteString(file_handle, "\n");
         }
         
         FileClose(file_handle);
         Print("SegmentInfoLogger: 交易操作和线段信息记录完成 - 动作: ", actionStr, ", PositionId: ", positionId);
         return true;
      }
      else
      {
         Print("SegmentInfoLogger: 文件打开失败 - ", m_filename, ", 错误: ", GetLastError());
         return false;
      }
   }
   
   // 记录交易操作动作和线段信息到同一行记录中（所有时间周期）
   bool LogTradeActionWithAllSegments(ENUM_TRADE_ACTION action, datetime actionTime, 
                                    ulong orderTicket, long positionId, string symbol,
                                    double price, double volume, string comment,
                                    CTradeBasePoint &tradeBasePoint, string tradeStatus = "")
   {
      // 定义时间周期数组
      string timeframeNames[] = {"M5", "M15", "M30", "H1"};
      ENUM_TIMEFRAMES timeframes[] = {PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1};
      
      bool success = true;
      
      // 为每个时间周期记录信息
      for(int i = 0; i < ArraySize(timeframes); i++)
      {
         if(!LogTradeActionWithSegmentInfo(action, actionTime, orderTicket, positionId, symbol,
                                         price, volume, comment, tradeBasePoint, timeframes[i], tradeStatus))
         {
            Print("SegmentInfoLogger: 写入线段信息失败 - 时间周期: ", timeframeNames[i]);
            success = false;
         }
      }
      
      return success;
   }
   
   // 同时记录交易操作动作和线段信息（保持原有方法以确保向后兼容性）
   bool LogTradeActionWithSegments(ENUM_TRADE_ACTION action, datetime actionTime, 
                                  ulong orderTicket, long positionId, string symbol,
                                  double price, double volume, string comment,
                                  CTradeBasePoint &tradeBasePoint)
   {
      // 首先记录交易操作动作
      if(!LogTradeAction(action, actionTime, orderTicket, positionId, symbol, price, volume, comment))
      {
         Print("SegmentInfoLogger: 记录交易操作动作失败");
         return false;
      }
      
      // 然后记录线段信息
      if(!LogSegmentInfo(actionTime, orderTicket, positionId, tradeBasePoint))
      {
         Print("SegmentInfoLogger: 记录线段信息失败");
         return false;
      }
      
      Print("SegmentInfoLogger: 交易操作动作和线段信息记录完成 - 动作: ", TradeActionToString(action), ", PositionId: ", positionId);
      return true;
   }
   
private:
   // 将线段信息写入CSV文件
   bool WriteSegmentInfoToCSV(datetime tradeTime, ulong orderTicket, long positionId,
                             CTradeBasePoint &tradeBasePoint,
                             ENUM_TIMEFRAMES timeframe, string timeframeName,
                             CZigzagSegment* &leftSegments[], CZigzagSegment* &rightSegments[])
   {
      int file_handle = FileOpen(m_filename, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON);
      if(file_handle != INVALID_HANDLE)
      {
         FileSeek(file_handle, 0, SEEK_END);
         
         // 左侧线段信息（每条线段一行）
         int leftCount = ArraySize(leftSegments);
         for(int i = 0; i < leftCount && i < 10; i++)
         {
            if(leftSegments[i] != NULL)
            {
               // 基本交易信息
               FileWriteString(file_handle, TimeToString(tradeTime, TIME_DATE|TIME_SECONDS));
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, IntegerToString((int)orderTicket));
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, IntegerToString((int)positionId));
               FileWriteString(file_handle, ";");
               
               // 参考点信息
               FileWriteString(file_handle, DoubleToString(tradeBasePoint.GetBasePrice(), (int)_Digits));
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, TimeToString(tradeBasePoint.GetBaseTime(), TIME_DATE|TIME_SECONDS));
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, IntegerToString(tradeBasePoint.GetBarIndex()));
               FileWriteString(file_handle, ";");
               
               // 时间周期信息
               FileWriteString(file_handle, timeframeName);
               FileWriteString(file_handle, ";");
               
               // 线段信息
               FileWriteString(file_handle, "Left");  // 线段方向
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, IntegerToString(i + 1)); // 线段序号
               FileWriteString(file_handle, ";");
               
               // 起始价格
               FileWriteString(file_handle, DoubleToString(leftSegments[i].m_start_point.value, (int)_Digits));
               FileWriteString(file_handle, ";");
               
               // 结束价格
               FileWriteString(file_handle, DoubleToString(leftSegments[i].m_end_point.value, (int)_Digits));
               FileWriteString(file_handle, ";");
               
               // 幅度（结束价格 - 起始价格）
               double amplitude = leftSegments[i].m_end_point.value - leftSegments[i].m_start_point.value;
               FileWriteString(file_handle, DoubleToString(amplitude, (int)_Digits));
               FileWriteString(file_handle, ";");
               
               // 方向
               FileWriteString(file_handle, leftSegments[i].IsUptrend() ? "UP" : "DOWN");
               FileWriteString(file_handle, "\n");
            }
         }
         
         // 右侧线段信息（每条线段一行）
         int rightCount = ArraySize(rightSegments);
         for(int i = 0; i < rightCount && i < 10; i++)
         {
            if(rightSegments[i] != NULL)
            {
               // 基本交易信息
               FileWriteString(file_handle, TimeToString(tradeTime, TIME_DATE|TIME_SECONDS));
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, IntegerToString((int)orderTicket));
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, IntegerToString((int)positionId));
               FileWriteString(file_handle, ";");
               
               // 参考点信息
               FileWriteString(file_handle, DoubleToString(tradeBasePoint.GetBasePrice(), (int)_Digits));
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, TimeToString(tradeBasePoint.GetBaseTime(), TIME_DATE|TIME_SECONDS));
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, IntegerToString(tradeBasePoint.GetBarIndex()));
               FileWriteString(file_handle, ";");
               
               // 时间周期信息
               FileWriteString(file_handle, timeframeName);
               FileWriteString(file_handle, ";");
               
               // 线段信息
               FileWriteString(file_handle, "Right");  // 线段方向
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, IntegerToString(i + 1)); // 线段序号
               FileWriteString(file_handle, ";");
               
               // 起始价格
               FileWriteString(file_handle, DoubleToString(rightSegments[i].m_start_point.value, (int)_Digits));
               FileWriteString(file_handle, ";");
               
               // 结束价格
               FileWriteString(file_handle, DoubleToString(rightSegments[i].m_end_point.value, (int)_Digits));
               FileWriteString(file_handle, ";");
               
               // 幅度（结束价格 - 起始价格）
               double amplitude = rightSegments[i].m_end_point.value - rightSegments[i].m_start_point.value;
               FileWriteString(file_handle, DoubleToString(amplitude, (int)_Digits));
               FileWriteString(file_handle, ";");
               
               // 方向
               FileWriteString(file_handle, rightSegments[i].IsUptrend() ? "UP" : "DOWN");
               FileWriteString(file_handle, ";");
               
               // 交易状态（默认为空）
               FileWriteString(file_handle, "");
               FileWriteString(file_handle, "\n");
            }
         }
         
         FileClose(file_handle);
         return true;
      }
      else
      {
         Print("SegmentInfoLogger: 文件打开失败 - ", m_filename, ", 错误: ", GetLastError());
         return false;
      }
   }
};