#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Files/File.mqh>
#include "TradeRecord.mqh"

// 简化版CSV记录器，只使用插入操作
class CSimpleCSVLogger
{
private:
   string m_filename;
   bool m_initialized;
   CTradeRecord* m_pendingRecord; // 存储待处理的入场记录

public:
   CSimpleCSVLogger(string filename = "order_log.csv")
   {
      m_filename = filename;
      m_initialized = false;
      m_pendingRecord = NULL;
      Initialize();
   }
   
   // 析构函数
   ~CSimpleCSVLogger()
   {
      ClearPendingRecords();
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
               if(StringFind(firstLine, "EntryTime") != -1 && StringFind(firstLine, "ExitTime") != -1)
               {
                  hasHeader = true;
               }
            }
            
            // 如果文件为空或不包含表头，则写入表头
            if(!hasHeader)
            {
               // 写入CSV头部，包含更多字段以匹配数据库结构
               FileSeek(file_handle, 0, SEEK_END);
               FileWriteString(file_handle, "ID");
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "EntryTime");
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "ExitTime");
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "EventType");
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "Symbol");
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "OrderType");
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "Volume");
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "EntryPrice");
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "StopLoss");
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "TakeProfit");
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "ExitPrice");
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "Profit");
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "OrderTicket");
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "PositionId");
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "MagicNumber");
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "Comment");
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "Result");
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "ErrorCode");
               FileWriteString(file_handle, ";");
               FileWriteString(file_handle, "DealEntry");
               FileWriteString(file_handle, "\n");
            }
            
            FileClose(file_handle);
            m_initialized = true;
            Print("SimpleCSVLogger: 文件初始化成功 - ", m_filename);
         }
         else
         {
            Print("SimpleCSVLogger: 文件打开失败 - ", m_filename, ", 错误: ", GetLastError());
         }
      }
   }
   
   // 记录入场交易
   bool LogEntry(string eventType, string symbol, string orderType, double volume,
                 double entryPrice, double stopLoss, double takeProfit,
                 datetime entryTime, ulong orderTicket, long positionId, long magicNumber,
                 string comment, string result, int errorCode, string dealEntry)
   {
      // 清空之前的记录
      ClearPendingRecords();
      
      // 创建新的交易记录对象并存储
      m_pendingRecord = new CTradeRecord(eventType, symbol, orderType, volume,
                                        entryPrice, stopLoss, takeProfit,
                                        entryTime, orderTicket, positionId, magicNumber,
                                        comment, result, errorCode, dealEntry);
      
      Print("SimpleCSVLogger: 入场记录已缓存 - PositionId: ", positionId);
      return true;
   }
   
   // 记录出场交易并写入完整记录
   bool LogExit(long positionId, double exitPrice, double profit, datetime exitTime, 
                string dealEntry, string comment)
   {
      // 检查是否存在待处理的入场记录
      if(m_pendingRecord != NULL)
      {
         // 检查是否为对应的入场记录
         if(m_pendingRecord.PositionId == positionId)
         {
            // 更新记录
            m_pendingRecord.SetExitData(exitPrice, profit, exitTime, dealEntry, comment);
            
            // 检查入场时间和出场时间是否都存在，只有都存在才写入
            if(m_pendingRecord.EntryTime > 0 && m_pendingRecord.ExitTime > 0)
            {
               // 写入CSV文件
               bool success = m_pendingRecord.WriteToCSV(m_filename);
               
               if(success)
               {
                  Print("SimpleCSVLogger: 完整交易记录已写入 - PositionId: ", positionId);
                  // 成功写入后清空待处理记录
                  ClearPendingRecords();
               }
               else
               {
                  Print("SimpleCSVLogger: 写入交易记录失败 - PositionId: ", positionId);
                  // 写入失败也清空待处理记录
                  ClearPendingRecords();
               }
               
               return success;
            }
            else
            {
               Print("SimpleCSVLogger: 入场时间或出场时间为空，不写入记录 - PositionId: ", positionId);
               // 清空待处理记录
               ClearPendingRecords();
               return true; // 返回true表示处理成功，只是没有写入
            }
         }
      }
      
      // 如果没有找到对应的入场记录，创建一个新的完整记录并写入
      Print("SimpleCSVLogger: 未找到入场记录，创建完整记录 - PositionId: ", positionId);
      CTradeRecord* record = new CTradeRecord();
      record.PositionId = positionId;
      record.SetExitData(exitPrice, profit, exitTime, dealEntry, comment);
      
      // 检查入场时间和出场时间是否都存在，只有都存在才写入
      if(record.EntryTime > 0 && record.ExitTime > 0)
      {
         bool success = record.WriteToCSV(m_filename);
         
         if(success)
         {
            Print("SimpleCSVLogger: 完整交易记录已写入 - PositionId: ", positionId);
         }
         else
         {
            Print("SimpleCSVLogger: 写入完整交易记录失败 - PositionId: ", positionId);
         }
         
         delete record;
         return success;
      }
      else
      {
         Print("SimpleCSVLogger: 入场时间或出场时间为空，不写入记录 - PositionId: ", positionId);
         delete record;
         return true; // 返回true表示处理成功，只是没有写入
      }
   }
   
   // 直接写入完整记录（用于只有出场记录的情况）
   bool LogCompleteRecord(string eventType, string symbol, string orderType, double volume,
                         double entryPrice, double stopLoss, double takeProfit,
                         double exitPrice, double profit,
                         datetime entryTime, datetime exitTime,
                         ulong orderTicket, long positionId, long magicNumber,
                         string comment, string result, int errorCode, string dealEntry)
   {
      // 创建记录对象
      CTradeRecord* record = new CTradeRecord(eventType, symbol, orderType, volume,
                                             entryPrice, stopLoss, takeProfit,
                                             entryTime, orderTicket, positionId, magicNumber,
                                             comment, result, errorCode, dealEntry);
      record.SetExitData(exitPrice, profit, exitTime, dealEntry, comment);
      
      // 检查入场时间和出场时间是否都存在，只有都存在才写入
      if(entryTime > 0 && exitTime > 0)
      {
         bool success = record.WriteToCSV(m_filename);
         
         if(success)
         {
            Print("SimpleCSVLogger: 完整交易记录已写入 - PositionId: ", positionId);
         }
         else
         {
            Print("SimpleCSVLogger: 写入完整交易记录失败 - PositionId: ", positionId);
         }
         
         delete record;
         return success;
      }
      else
      {
         Print("SimpleCSVLogger: 入场时间或出场时间为空，不写入记录 - PositionId: ", positionId);
         delete record;
         return true; // 返回true表示处理成功，只是没有写入
      }
   }
   
   // 从CSV文件中获取最后同步时间
   datetime GetLastSyncTime()
   {
      datetime lastTime = 0;
      
      // 检查文件是否存在
      if(!FileIsExist(m_filename, FILE_COMMON))
      {
         return lastTime;
      }
      
      // 打开文件并直接跳到最后一行
      int file_handle = FileOpen(m_filename, FILE_READ|FILE_CSV|FILE_COMMON);
      if(file_handle != INVALID_HANDLE)
      {
         // 逐行读取文件，获取最后一行有效数据
         string lastLine = "";
         while(!FileIsEnding(file_handle))
         {
            string line = FileReadString(file_handle);
            // 跳过空行和表头行
            if(line != "" && line != "\n" && line != "\r" && line != "\r\n")
            {
               // 检查是否为表头（通过检查是否包含特定字段名）
               if(StringFind(line, "EntryTime") == -1 && StringFind(line, "ExitTime") == -1)
               {
                  lastLine = line;
               }
            }
         }
         
         // 解析最后一行的时间字段
         string fields[];
         int fieldCount = StringSplit(lastLine, ';', fields);
         
         // 检查字段数量是否足够
         if(fieldCount > 2)
         {
            // 检查入场时间（索引1）和出场时间（索引2）
            datetime entryTime = StringToTime(fields[1]);
            datetime exitTime = StringToTime(fields[2]);
            
            // 使用较大的时间
            lastTime = (exitTime > entryTime) ? exitTime : entryTime;
         }
         
         FileClose(file_handle);
      }
      
      return lastTime;
   }
   
   // 清空待处理记录
   void ClearPendingRecords()
   {
      if(m_pendingRecord != NULL)
      {
         // 删除待处理记录
         delete m_pendingRecord;
         m_pendingRecord = NULL;
      }
   }
};