#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Files/File.mqh>
#include <Arrays/ArrayObj.mqh>
#include "TradeRecord.mqh"

// 简化版CSV记录器，只使用插入操作
class CSimpleCSVLogger
{
private:
   string m_filename;
   bool m_initialized;
   CArrayObj* m_pendingRecords; // 存储待处理的入场记录

public:
   CSimpleCSVLogger(string filename = "order_log.csv")
   {
      m_filename = filename;
      m_initialized = false;
      m_pendingRecords = new CArrayObj();
      Initialize();
   }
   
   // 析构函数
   ~CSimpleCSVLogger()
   {
      if(m_pendingRecords != NULL)
      {
         // 清理所有待处理记录
         for(int i = m_pendingRecords.Total() - 1; i >= 0; i--)
         {
            CTradeRecord* record = (CTradeRecord*)m_pendingRecords.At(i);
            delete record;
         }
         m_pendingRecords.Clear();
         delete m_pendingRecords;
         m_pendingRecords = NULL;
      }
   }
   
   void Initialize()
   {
      if(!m_initialized)
      {
         int file_handle = FileOpen(m_filename, FILE_WRITE|FILE_CSV);
         if(file_handle != INVALID_HANDLE)
         {
            // 检查文件是否为空，如果为空则写入表头
            if(FileSize(file_handle) == 0)
            {
               // 写入CSV头部，包含更多字段以匹配数据库结构
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
      // 创建新的交易记录对象并存储在待处理数组中
      CTradeRecord* record = new CTradeRecord(eventType, symbol, orderType, volume,
                                             entryPrice, stopLoss, takeProfit,
                                             entryTime, orderTicket, positionId, magicNumber,
                                             comment, result, errorCode, dealEntry);
      
      m_pendingRecords.Add(record);
      Print("SimpleCSVLogger: 入场记录已缓存 - PositionId: ", positionId);
      return true;
   }
   
   // 记录出场交易并写入完整记录
   bool LogExit(long positionId, double exitPrice, double profit, datetime exitTime, 
                string dealEntry, string comment)
   {
      // 查找对应的入场记录
      for(int i = 0; i < m_pendingRecords.Total(); i++)
      {
         CTradeRecord* record = (CTradeRecord*)m_pendingRecords.At(i);
         if(record.PositionId == positionId)
         {
            // 更新记录
            record.SetExitData(exitPrice, profit, exitTime, dealEntry, comment);
            
            // 写入CSV文件
            bool success = record.WriteToCSV(m_filename);
            
            // 从待处理数组中移除记录
            m_pendingRecords.Delete(i);
            delete record;
            
            if(success)
            {
               Print("SimpleCSVLogger: 完整交易记录已写入 - PositionId: ", positionId);
            }
            else
            {
               Print("SimpleCSVLogger: 写入交易记录失败 - PositionId: ", positionId);
            }
            
            return success;
         }
      }
      
      // 如果没有找到对应的入场记录，创建一个新的完整记录并写入
      Print("SimpleCSVLogger: 未找到入场记录，创建完整记录 - PositionId: ", positionId);
      CTradeRecord* record = new CTradeRecord();
      record.PositionId = positionId;
      record.SetExitData(exitPrice, profit, exitTime, dealEntry, comment);
      bool success = record.WriteToCSV(m_filename);
      delete record;
      
      return success;
   }
   
   // 直接写入完整记录（用于只有出场记录的情况）
   bool LogCompleteRecord(string eventType, string symbol, string orderType, double volume,
                         double entryPrice, double stopLoss, double takeProfit,
                         double exitPrice, double profit,
                         datetime entryTime, datetime exitTime,
                         ulong orderTicket, long positionId, long magicNumber,
                         string comment, string result, int errorCode, string dealEntry)
   {
      CTradeRecord* record = new CTradeRecord(eventType, symbol, orderType, volume,
                                             entryPrice, stopLoss, takeProfit,
                                             entryTime, orderTicket, positionId, magicNumber,
                                             comment, result, errorCode, dealEntry);
      record.SetExitData(exitPrice, profit, exitTime, dealEntry, comment);
      
      bool success = record.WriteToCSV(m_filename);
      delete record;
      
      if(success)
      {
         Print("SimpleCSVLogger: 完整交易记录已写入 - PositionId: ", positionId);
      }
      else
      {
         Print("SimpleCSVLogger: 写入完整交易记录失败 - PositionId: ", positionId);
      }
      
      return success;
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
      
      int file_handle = FileOpen(m_filename, FILE_READ|FILE_CSV|FILE_COMMON);
      if(file_handle != INVALID_HANDLE)
      {
         // 跳过表头
         if(!FileIsEnding(file_handle))
         {
            string headers[20];
            for(int i=0; i<20; i++)
            {
               headers[i] = FileReadString(file_handle);
               if(FileIsLineEnding(file_handle))
                  break;
            }
         }
         
         // 读取所有记录并找到最大的时间
         while(!FileIsEnding(file_handle))
         {
            string fields[20];
            for(int i=0; i<20; i++)
            {
               fields[i] = FileReadString(file_handle);
               if(FileIsLineEnding(file_handle))
                  break;
            }
            
            // 检查字段数量
            if(ArraySize(fields) > 2)
            {
               // 检查入场时间（索引1）和出场时间（索引2）
               datetime entryTime = StringToTime(fields[1]);
               datetime exitTime = StringToTime(fields[2]);
               
               // 使用较大的时间
               datetime recordTime = (exitTime > entryTime) ? exitTime : entryTime;
               if(recordTime > lastTime)
               {
                  lastTime = recordTime;
               }
            }
         }
         
         FileClose(file_handle);
      }
      
      return lastTime;
   }
};