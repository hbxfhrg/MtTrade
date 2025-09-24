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
         // 写入CSV文件
         bool csvSuccess = record.WriteToCSV(m_filename);
         
         // 如果有数据库管理器，也写入数据库
         bool dbSuccess = true;
         if(m_dbManager != NULL)
         {
            dbSuccess = record.WriteToMySQL(m_dbManager);
         }
         
         bool success = csvSuccess && dbSuccess;
         
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
         // 获取文件大小
         ulong fileSize = FileSize(file_handle);
         
         // 从文件末尾开始向前搜索，找到最后一行有效数据
         string lastLine = "";
         int searchPos = (int)fileSize - 1;
         int maxSearchBytes = 1000; // 最多向前搜索1000字节
         int searchCount = 0;
         
         while(searchPos >= 0 && searchCount < maxSearchBytes)
         {
            // 设置文件指针位置
            FileSeek(file_handle, searchPos, SEEK_SET);
            
            // 读取一行
            string line = FileReadString(file_handle);
            
            // 检查是否是有效数据行（不是表头且不为空）
            if(line != "" && line != "\n" && line != "\r" && line != "\r\n")
            {
               // 检查是否为表头（通过检查是否包含特定字段名）
               if(StringFind(line, "EntryTime") == -1 && StringFind(line, "ExitTime") == -1)
               {
                  lastLine = line;
                  break;
               }
            }
            
            // 如果已经到达文件开头，停止搜索
            if(searchPos == 0)
               break;
               
            // 向前移动搜索位置
            searchPos = MathMax(0, searchPos - 100); // 每次向前移动100字节
            searchCount += 100;
         }
         
         // 如果没有找到有效行，使用原来的逐行读取方法
         if(lastLine == "")
         {
            FileSeek(file_handle, 0, SEEK_SET);
            // 跳过表头行
            string header = FileReadString(file_handle);
            
            // 逐行读取文件，获取最后一行有效数据
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
   
   // 从CSV文件中读取指定PositionId的完整交易记录
   CTradeRecord* GetCompleteTradeRecord(long positionId)
   {
      CTradeRecord* record = NULL;
      
      // 检查文件是否存在
      if(!FileIsExist(m_filename, FILE_COMMON))
      {
         return record;
      }
      
      // 打开文件读取
      int file_handle = FileOpen(m_filename, FILE_READ|FILE_CSV|FILE_COMMON);
      if(file_handle != INVALID_HANDLE)
      {
         // 跳过表头行
         string header = FileReadString(file_handle);
         
         // 逐行读取文件，查找匹配的PositionId
         while(!FileIsEnding(file_handle))
         {
            string line = FileReadString(file_handle);
            // 跳过空行
            if(line == "" || line == "\n" || line == "\r" || line == "\r\n")
               continue;
               
            // 解析行数据
            string fields[];
            int fieldCount = StringSplit(line, ';', fields);
            
            // 检查字段数量是否足够
            if(fieldCount >= 18)
            {
               // PositionId在索引13位置
               long recordPositionId = (long)StringToInteger(fields[13]);
               
               // 检查是否匹配
               if(recordPositionId == positionId)
               {
                  // 创建新的交易记录对象
                  record = new CTradeRecord();
                  
                  // 解析并填充数据
                  record.ID = fields[0];
                  record.EntryTime = StringToTime(fields[1]);
                  record.ExitTime = StringToTime(fields[2]);
                  record.EventType = fields[3];
                  record.Symbol = fields[4];
                  record.OrderType = fields[5];
                  record.Volume = StringToDouble(fields[6]);
                  record.EntryPrice = StringToDouble(fields[7]);
                  record.StopLoss = StringToDouble(fields[8]);
                  record.TakeProfit = StringToDouble(fields[9]);
                  record.ExitPrice = StringToDouble(fields[10]);
                  record.Profit = StringToDouble(fields[11]);
                  record.OrderTicket = (ulong)StringToInteger(fields[12]);
                  record.PositionId = recordPositionId;
                  record.MagicNumber = (long)StringToInteger(fields[14]);
                  record.Comment = fields[15];
                  record.Result = fields[16];
                  record.ErrorCode = (int)StringToInteger(fields[17]);
                  if(fieldCount > 18)
                     record.DealEntry = fields[18];
                  
                  break; // 找到匹配记录后退出循环
               }
            }
            else if(fieldCount >= 14)
            {
               // 处理旧格式的记录（字段较少）
               // PositionId在索引13位置
               long recordPositionId = (long)StringToInteger(fields[13]);
               
               // 检查是否匹配
               if(recordPositionId == positionId)
               {
                  // 创建新的交易记录对象
                  record = new CTradeRecord();
                  
                  // 解析并填充数据
                  record.ID = fields[0];
                  record.EntryTime = StringToTime(fields[1]);
                  record.ExitTime = StringToTime(fields[2]);
                  record.EventType = fields[3];
                  record.Symbol = fields[4];
                  record.OrderType = fields[5];
                  record.Volume = StringToDouble(fields[6]);
                  record.EntryPrice = StringToDouble(fields[7]);
                  record.StopLoss = StringToDouble(fields[8]);
                  record.TakeProfit = StringToDouble(fields[9]);
                  record.ExitPrice = StringToDouble(fields[10]);
                  record.Profit = StringToDouble(fields[11]);
                  record.OrderTicket = (ulong)StringToInteger(fields[12]);
                  record.PositionId = recordPositionId;
                  // 其他字段使用默认值
                  
                  break; // 找到匹配记录后退出循环
               }
            }
         }
         
         FileClose(file_handle);
      }
      
      return record;
   }
};