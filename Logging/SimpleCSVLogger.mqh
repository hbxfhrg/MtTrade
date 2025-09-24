#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Files/File.mqh>
#include "TradeRecord.mqh"
#include "..\Database\DatabaseManager.mqh"

// 简化版CSV记录器，只使用插入操作
class CSimpleCSVLogger
{
private:
   string m_filename;
   bool m_initialized;
   CTradeRecord* m_pendingRecord; // 存储待处理的入场记录
   CDatabaseManager* m_dbManager; // 数据库管理器

public:
   CSimpleCSVLogger(string filename = "order_log.csv", CDatabaseManager* dbManager = NULL)
   {
      m_filename = filename;
      m_initialized = false;
      m_pendingRecord = NULL;
      m_dbManager = dbManager;
      Initialize();
   }
   
   // 设置数据库管理器
   void SetDatabaseManager(CDatabaseManager* dbManager)
   {
      m_dbManager = dbManager;
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
               bool csvSuccess = m_pendingRecord.WriteToCSV(m_filename);
               
               // 如果有数据库管理器，也写入数据库
               bool dbSuccess = true;
               if(m_dbManager != NULL)
               {
                  dbSuccess = m_pendingRecord.WriteToMySQL(m_dbManager);
               }
               
               bool success = csvSuccess && dbSuccess;
               
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
      
      // 如果没有找到对应的入场记录，记录警告信息并返回false
      Print("SimpleCSVLogger: 未找到PositionId为", positionId, "的入场记录，无法写入完整交易记录");
      return false;
   }
   

   
   // 从CSV文件中获取最后同步时间
   datetime GetLastSyncTime()
   {
      datetime lastTime = 0;
      
      // 检查文件是否存在
      if(!FileIsExist(m_filename, FILE_COMMON))
      {
         Print("SimpleCSVLogger: 文件不存在 - ", m_filename);
         return lastTime;
      }
      
      // 打开文件
      int file_handle = FileOpen(m_filename, FILE_READ|FILE_CSV|FILE_COMMON);
      if(file_handle != INVALID_HANDLE)
      {
         // 跳过表头行
         string header = FileReadString(file_handle);
         
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
         if(lastLine != "")
         {
            string fields[];
            int fieldCount = StringSplit(lastLine, ';', fields);
            
            // 检查字段数量是否足够
            if(fieldCount > 2)
            {
               // 检查入场时间（索引1）和出场时间（索引2）
               datetime entryTime = StringToTime(fields[1]);
               datetime exitTime = StringToTime(fields[2]);
               
               // 使用较大的时间，但如果其中一个时间为0，则使用另一个时间
               if(entryTime > 0 && exitTime > 0)
               {
                  lastTime = (exitTime > entryTime) ? exitTime : entryTime;
                  Print("SimpleCSVLogger: 成功获取最后同步时间 - EntryTime: ", TimeToString(entryTime), ", ExitTime: ", TimeToString(exitTime), ", 使用时间: ", TimeToString(lastTime));
               }
               else if(entryTime > 0)
               {
                  lastTime = entryTime;
                  Print("SimpleCSVLogger: 只有入场时间 - ", TimeToString(entryTime));
               }
               else if(exitTime > 0)
               {
                  lastTime = exitTime;
                  Print("SimpleCSVLogger: 只有出场时间 - ", TimeToString(exitTime));
               }
               else
               {
                  Print("SimpleCSVLogger: 时间字段无效 - EntryTime: ", TimeToString(entryTime), ", ExitTime: ", TimeToString(exitTime));
               }
            }
            else
            {
               Print("SimpleCSVLogger: 字段数量不足 - ", fieldCount);
            }
         }
         else
         {
            Print("SimpleCSVLogger: 未找到有效数据行");
         }
         
         FileClose(file_handle);
      }
      else
      {
         Print("SimpleCSVLogger: 文件打开失败 - ", m_filename, ", 错误: ", GetLastError());
      }
      
      Print("SimpleCSVLogger: 返回最后同步时间 - ", TimeToString(lastTime));
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