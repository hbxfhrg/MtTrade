//+------------------------------------------------------------------+
//| DatabaseManager.mqh                                              |
//| 简化的数据库管理器（使用CSV文件作为存储）                        |
//+------------------------------------------------------------------+
class CDatabaseManager
{
private:
   string m_logFile;
   string m_memoryLog;  // 内存日志存储
   
public:
   CDatabaseManager(string host = "localhost", string username = "root", 
                   string password = "", string database = "mttrade", int port = 3306)
   {
      m_logFile = "MtTradeLogs.csv";
      m_memoryLog = "";  // 初始化内存日志
      // 确保表头存在
      EnsureHeaderExists();
   }
   
   // 确保CSV文件有表头
   void EnsureHeaderExists()
   {
      // 检查文件是否存在
      if(!FileIsExist(m_logFile, FILE_COMMON))
      {
         // 文件不存在，创建并写入表头
         int handle = FileOpen(m_logFile, FILE_WRITE|FILE_CSV|FILE_COMMON);
         if(handle != INVALID_HANDLE)
         {
            FileWrite(handle, "Time,Symbol,Type,Volume,Price,SL,TP,Comment");
            FileClose(handle);
         }
      }
      else
      {
         // 文件存在，检查是否已有表头
         int handle = FileOpen(m_logFile, FILE_READ|FILE_CSV|FILE_COMMON);
         if(handle != INVALID_HANDLE)
         {
            string firstLine = "";
            if(!FileIsEnding(handle))
            {
               firstLine = FileReadString(handle);
            }
            FileClose(handle);
            
            // 如果第一行不是表头，则添加表头
            if(firstLine != "Time,Symbol,Type,Volume,Price,SL,TP,Comment")
            {
               // 读取现有内容
               string content = "";
               handle = FileOpen(m_logFile, FILE_READ|FILE_CSV|FILE_COMMON);
               if(handle != INVALID_HANDLE)
               {
                  while(!FileIsEnding(handle))
                  {
                     content += FileReadString(handle) + "\n";
                  }
                  FileClose(handle);
                  
                  // 重新写入文件，先写表头再写内容
                  handle = FileOpen(m_logFile, FILE_WRITE|FILE_CSV|FILE_COMMON);
                  if(handle != INVALID_HANDLE)
                  {
                     FileWrite(handle, "Time,Symbol,Type,Volume,Price,SL,TP,Comment");
                     if(content != "")
                     {
                        // 写入原有内容
                        FileWriteString(handle, content);
                     }
                     FileClose(handle);
                  }
               }
            }
         }
      }
   }
   
   // 将交易记录保存到内存日志
   void LogToMemory(string time, string symbol, string type, 
                   string volume, string price, string sl, string tp, string comment)
   {
      // 将记录添加到内存日志中
      m_memoryLog += StringFormat("[%s] %s,%s,%s,%s,%s,%s,%s,%s\n", 
                                time, symbol, type, volume, price, sl, tp, comment, "");
   }
   
   // 输出内存日志到MT4/5日志窗口
   void OutputMemoryLog()
   {
      if(m_memoryLog != "")
      {
         Print("=== 数据库操作内存日志 ===");
         Print(m_memoryLog);
         Print("=== 内存日志结束 ===");
         
         // 清空内存日志
         m_memoryLog = "";
      }
   }
   
   // 将交易记录保存到文件（模拟数据库存储）
   bool LogTradeToMySQL(int time, string symbol, string type, 
                      string volume, string price, string sl, string tp, string comment)
   {
      string timeStr = TimeToString(time);
      
      // 首先记录到内存日志
      LogToMemory(timeStr, symbol, type, volume, price, sl, tp, comment);
      
      int handle = FileOpen(m_logFile, FILE_WRITE|FILE_READ|FILE_CSV|FILE_COMMON);
      if(handle != INVALID_HANDLE)
      {
         // 移动到文件末尾
         FileSeek(handle, 0, SEEK_END);
         
         // 写入交易记录
         FileWrite(handle, timeStr, symbol, type, volume, price, sl, tp, comment);
         
         FileClose(handle);
         
         // 输出内存日志
         OutputMemoryLog();
         
         return true;
      }
      
      // 如果文件操作失败，仍然输出内存日志
      OutputMemoryLog();
      return false;
   }
   
   // 生成SQL插入语句文件（便于导入到真实数据库）
   bool GenerateSQLFile(string sqlFile = "MtTradeLogs.sql")
   {
      // 打开CSV文件读取数据
      int csvHandle = FileOpen(m_logFile, FILE_READ|FILE_CSV|FILE_COMMON);
      if(csvHandle == INVALID_HANDLE)
         return false;
         
      // 创建SQL文件
      int sqlHandle = FileOpen(sqlFile, FILE_WRITE|FILE_TXT|FILE_COMMON);
      if(sqlHandle == INVALID_HANDLE)
      {
         FileClose(csvHandle);
         return false;
      }
      
      // 写入SQL文件头部
      FileWriteString(sqlHandle, "CREATE TABLE IF NOT EXISTS trade_logs (\n");
      FileWriteString(sqlHandle, "    id INT AUTO_INCREMENT PRIMARY KEY,\n");
      FileWriteString(sqlHandle, "    log_time DATETIME,\n");
      FileWriteString(sqlHandle, "    symbol VARCHAR(20),\n");
      FileWriteString(sqlHandle, "    trade_type VARCHAR(20),\n");
      FileWriteString(sqlHandle, "    volume DECIMAL(10,2),\n");
      FileWriteString(sqlHandle, "    price DECIMAL(20,8),\n");
      FileWriteString(sqlHandle, "    stop_loss DECIMAL(20,8),\n");
      FileWriteString(sqlHandle, "    take_profit DECIMAL(20,8),\n");
      FileWriteString(sqlHandle, "    comment TEXT,\n");
      FileWriteString(sqlHandle, "    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP\n");
      FileWriteString(sqlHandle, ");\n\n");
      
      // 跳过CSV表头
      if(!FileIsEnding(csvHandle))
         FileReadString(csvHandle);
      
      // 逐行读取CSV数据并生成INSERT语句
      while(!FileIsEnding(csvHandle))
      {
         string time = FileReadString(csvHandle);
         string symbol = FileReadString(csvHandle);
         string type = FileReadString(csvHandle);
         string volume = FileReadString(csvHandle);
         string price = FileReadString(csvHandle);
         string sl = FileReadString(csvHandle);
         string tp = FileReadString(csvHandle);
         string comment = FileReadString(csvHandle);
         
         // 生成INSERT语句
         string insertStmt = StringFormat("INSERT INTO trade_logs (log_time, symbol, trade_type, volume, price, stop_loss, take_profit, comment) VALUES ('%s', '%s', '%s', %s, %s, %s, %s, '%s');\n",
                                         time, symbol, type, volume, price, sl, tp, comment);
         FileWriteString(sqlHandle, insertStmt);
      }
      
      FileClose(csvHandle);
      FileClose(sqlHandle);
      return true;
   }
   
   // 获取最后错误信息
   string GetLastError() const
   {
      return "File operation error";
   }
};