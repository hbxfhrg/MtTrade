#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

// 交易记录类，用于管理CSV文件中的交易记录
class CTradeRecord : public CObject
{
public:
   string ID;
   datetime EntryTime;
   datetime ExitTime;
   string EventType;
   string Symbol;
   string OrderType;
   double Volume;
   double EntryPrice;
   double StopLoss;
   double TakeProfit;
   double ExitPrice;
   double Profit;
   ulong OrderTicket;
   long PositionId;
   long MagicNumber;
   string Comment;
   string Result;
   int ErrorCode;
   string DealEntry;
   
   // 构造函数
   CTradeRecord()
   {
      Initialize();
   }
   
   // 带参数的构造函数（用于入场交易）
   CTradeRecord(string eventType, string symbol, string orderType, double volume,
                double entryPrice, double stopLoss, double takeProfit,
                datetime entryTime, ulong orderTicket, long positionId, long magicNumber,
                string comment, string result, int errorCode, string dealEntry)
   {
      Initialize();
      SetEntryData(eventType, symbol, orderType, volume, entryPrice, stopLoss, takeProfit,
                   entryTime, orderTicket, positionId, magicNumber, comment, result, errorCode, dealEntry);
   }
   
   // 初始化方法
   void Initialize()
   {
      ID = "";
      EntryTime = 0;
      ExitTime = 0;
      EventType = "";
      Symbol = "";
      OrderType = "";
      Volume = 0.0;
      EntryPrice = 0.0;
      StopLoss = 0.0;
      TakeProfit = 0.0;
      ExitPrice = 0.0;
      Profit = 0.0;
      OrderTicket = 0;
      PositionId = 0;
      MagicNumber = 0;
      Comment = "";
      Result = "";
      ErrorCode = 0;
      DealEntry = "";
   }
   
   // 设置入场数据
   void SetEntryData(string eventType, string symbol, string orderType, double volume,
                     double entryPrice, double stopLoss, double takeProfit,
                     datetime entryTime, ulong orderTicket, long positionId, long magicNumber,
                     string comment, string result, int errorCode, string dealEntry)
   {
      // 生成唯一的ID（使用时间戳+订单号）
      ID = StringFormat("%d_%d", (int)TimeCurrent(), (int)orderTicket);
      
      EntryTime = entryTime;
      EventType = eventType;
      Symbol = symbol;
      OrderType = orderType;
      Volume = volume;
      EntryPrice = entryPrice;
      StopLoss = stopLoss;
      TakeProfit = takeProfit;
      OrderTicket = orderTicket;
      PositionId = positionId;
      MagicNumber = magicNumber;
      Comment = comment;
      Result = result;
      ErrorCode = errorCode;
      DealEntry = dealEntry;
   }
   
   // 设置出场数据
   void SetExitData(double exitPrice, double profit, datetime exitTime, string dealEntry, string comment)
   {
      ExitPrice = exitPrice;
      Profit = profit;
      ExitTime = exitTime;
      DealEntry = dealEntry;
      
      if(comment != "")
      {
         if(Comment != "")
            Comment = Comment + " " + comment;
         else
            Comment = comment;
      }
   }
   
   // 将记录写入CSV文件
   bool WriteToCSV(string filename)
   {
      int file_handle = FileOpen(filename, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON);
      if(file_handle != INVALID_HANDLE)
      {
         FileSeek(file_handle, 0, SEEK_END);
         
         // 写入记录
         FileWriteString(file_handle, ID);
         FileWriteString(file_handle, ";");
         FileWriteString(file_handle, TimeToString(EntryTime, TIME_DATE|TIME_SECONDS));
         FileWriteString(file_handle, ";");
         FileWriteString(file_handle, TimeToString(ExitTime, TIME_DATE|TIME_SECONDS));
         FileWriteString(file_handle, ";");
         FileWriteString(file_handle, EventType);
         FileWriteString(file_handle, ";");
         FileWriteString(file_handle, Symbol);
         FileWriteString(file_handle, ";");
         FileWriteString(file_handle, OrderType);
         FileWriteString(file_handle, ";");
         FileWriteString(file_handle, DoubleToString(Volume, 2));
         FileWriteString(file_handle, ";");
         FileWriteString(file_handle, DoubleToString(EntryPrice, (int)_Digits));
         FileWriteString(file_handle, ";");
         FileWriteString(file_handle, DoubleToString(StopLoss, (int)_Digits));
         FileWriteString(file_handle, ";");
         FileWriteString(file_handle, DoubleToString(TakeProfit, (int)_Digits));
         FileWriteString(file_handle, ";");
         FileWriteString(file_handle, DoubleToString(ExitPrice, (int)_Digits));
         FileWriteString(file_handle, ";");
         FileWriteString(file_handle, DoubleToString(Profit, 2));
         FileWriteString(file_handle, ";");
         FileWriteString(file_handle, IntegerToString((int)OrderTicket));
         FileWriteString(file_handle, ";");
         FileWriteString(file_handle, IntegerToString((int)PositionId));
         FileWriteString(file_handle, ";");
         FileWriteString(file_handle, IntegerToString((int)MagicNumber));
         FileWriteString(file_handle, ";");
         FileWriteString(file_handle, Comment);
         FileWriteString(file_handle, ";");
         FileWriteString(file_handle, Result);
         FileWriteString(file_handle, ";");
         FileWriteString(file_handle, IntegerToString(ErrorCode));
         FileWriteString(file_handle, ";");
         FileWriteString(file_handle, DealEntry);
         FileWriteString(file_handle, "\n");
         
         FileClose(file_handle);
         Print("TradeRecord: 记录写入成功 - PositionId: ", PositionId, ", 文件: ", filename);
         return true;
      }
      else
      {
         Print("TradeRecord: 记录写入失败 - 文件: ", filename, ", 错误: ", GetLastError());
         return false;
      }
   }
};