#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Files/File.mqh>
#include "..\TradeBasePoint.mqh"
#include "..\ZigzagSegment.mqh"

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