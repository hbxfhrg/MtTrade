#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Files/File.mqh>

class CCSVLogger
{
private:
   string m_filename;
   bool m_initialized;
   
public:
   CCSVLogger(string filename = "order_log.csv")
   {
      m_filename = filename;
      m_initialized = false;
      Initialize();
   }
   
   void Initialize()
   {
      if(!m_initialized)
      {
         int file_handle = FileOpen(m_filename, FILE_WRITE|FILE_CSV);
         if(file_handle != INVALID_HANDLE)
         {
            // 写入CSV头部
            FileWrite(file_handle, 
                     "Timestamp",
                     "EventType", 
                     "Symbol",
                     "OrderType",
                     "Volume",
                     "EntryPrice",
                     "StopLoss", 
                     "TakeProfit",
                     "ExpiryTime",
                     "OrderTicket",
                     "Comment",
                     "Result",
                     "ErrorCode");
            
            FileClose(file_handle);
            m_initialized = true;
            Print("CSVLogger: 文件初始化成功 - ", m_filename);
         }
         else
         {
            Print("CSVLogger: 文件打开失败 - ", m_filename, ", 错误: ", GetLastError());
         }
      }
   }
   
   void LogOrderEvent(string eventType, string symbol, string orderType, double volume, 
                     double entryPrice, double stopLoss, double takeProfit, datetime expiryTime,
                     ulong orderTicket, string comment, string result, int errorCode = 0)
   {
      int file_handle = FileOpen(m_filename, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON);
      if(file_handle != INVALID_HANDLE)
      {
         FileSeek(file_handle, 0, SEEK_END);
         
         FileWrite(file_handle,
                  TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
                  eventType,
                  symbol,
                  orderType,
                  DoubleToString(volume, 2),
                  DoubleToString(entryPrice, (int)_Digits),
                  DoubleToString(stopLoss, (int)_Digits),
                  DoubleToString(takeProfit, (int)_Digits),
                  TimeToString(expiryTime, TIME_DATE|TIME_SECONDS),
                  IntegerToString((int)orderTicket),
                  comment,
                  result,
                  IntegerToString(errorCode));
         
         FileClose(file_handle);
         Print("CSVLogger: 记录事件 - ", eventType, ", 订单: ", orderTicket, ", 文件: ", m_filename);
      }
      else
      {
         Print("CSVLogger: 记录事件失败 - ", m_filename, ", 错误: ", GetLastError(), ", 路径: ", TerminalInfoString(TERMINAL_DATA_PATH));
      }
   }
   
   // 记录订单超时未成交
   void LogOrderTimeout(ulong orderTicket, string symbol, string orderType, double volume,
                       double entryPrice, double stopLoss, double takeProfit, datetime expiryTime,
                       string comment = "")
   {
      LogOrderEvent("TIMEOUT", symbol, orderType, volume, entryPrice, stopLoss, takeProfit,
                   expiryTime, orderTicket, comment, "Order expired without execution", 0);
   }
   
   // 记录订单止盈
   void LogOrderTakeProfit(ulong orderTicket, string symbol, string orderType, double volume,
                         double entryPrice, double stopLoss, double takeProfit,
                         string comment = "")
   {
      LogOrderEvent("TAKE_PROFIT", symbol, orderType, volume, entryPrice, stopLoss, takeProfit,
                   0, orderTicket, comment, "Take profit triggered", 0);
   }
   
   // 记录订单止损
   void LogOrderStopLoss(ulong orderTicket, string symbol, string orderType, double volume,
                       double entryPrice, double stopLoss, double takeProfit,
                       string comment = "")
   {
      LogOrderEvent("STOP_LOSS", symbol, orderType, volume, entryPrice, stopLoss, takeProfit,
                   0, orderTicket, comment, "Stop loss triggered", 0);
   }
   
   // 记录订单成交
   void LogOrderFilled(ulong orderTicket, string symbol, string orderType, double volume,
                      double entryPrice, double stopLoss, double takeProfit, datetime expiryTime,
                      string comment = "")
   {
      LogOrderEvent("FILLED", symbol, orderType, volume, entryPrice, stopLoss, takeProfit,
                   expiryTime, orderTicket, comment, "Order filled successfully", 0);
   }
};