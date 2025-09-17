//+------------------------------------------------------------------+
//| DatabaseManager.mqh                                              |
//| 数据库管理器（使用MySQL数据库存储）                              |
//+------------------------------------------------------------------+
#include "MySQLOrderLogger.mqh"

class CDatabaseManager
{
private:
   CMySQLOrderLogger m_mysqlLogger;
   string m_memoryLog;  // 内存日志存储
   
public:
   CDatabaseManager(string host = "localhost", 
                   string username = "root", 
                   string password = "!Aa123456", 
                   string database = "pymt5", int port = 3306)
   {
      m_memoryLog = "";  // 初始化内存日志
      // m_mysqlLogger.SetTrace(true); // 启用调试日志 (注释掉不存在的方法)
      
      // 初始化MySQL连接
      if(!m_mysqlLogger.Initialize(host, (uint)port, database, username, password))
      {
         Print("DatabaseManager: MySQL连接失败 - ", m_mysqlLogger.GetErrorDescription());
      }
      else
      {
         // 确保表存在
         if(!EnsureTableExists())
         {
            Print("DatabaseManager: 无法确保表存在");
         }
      }
   }
   
   // 检查MySQL连接状态
   bool IsConnected() const
   {
      return m_mysqlLogger.IsInitialized();
   }
   
   // 检查并维持连接
   bool CheckConnection()
   {
      if(!IsConnected())
      {
         Print("尝试重新连接数据库...");
         return m_mysqlLogger.Initialize();
      }
      return true;
   }

   // 确保表存在
   bool EnsureTableExists()
   {
      if(!IsConnected()) 
      {
         Print("Database not connected");
         return false;
      }
      
      // 先检查表是否存在
      if(m_mysqlLogger.CheckTableExists("order_logs")) 
      {
         Print("Table already exists");
         return true;
      }
      
      string createTableSQL = "CREATE TABLE IF NOT EXISTS order_logs (" +
                             "id BIGINT AUTO_INCREMENT PRIMARY KEY, " +
                             "event_time DATETIME DEFAULT CURRENT_TIMESTAMP, " +
                             "event_type VARCHAR(20), " +
                             "symbol VARCHAR(20), " +
                             "order_type VARCHAR(20), " +
                             "volume DOUBLE, " +
                             "entry_price DOUBLE, " +
                             "stop_loss DOUBLE, " +
                             "take_profit DOUBLE, " +
                             "expiry_time VARCHAR(50), " +
                             "order_ticket BIGINT, " +
                             "comment TEXT, " +
                             "result TEXT, " +
                             "error_code INT" +
                             ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4";
      
      bool result = m_mysqlLogger.CreateTable("order_logs", createTableSQL);
      if(!result) 
      {
         Print("Create table failed: ", m_mysqlLogger.GetErrorDescription());
      }
      return result;
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
   
   // 将交易记录保存到MySQL数据库
   bool LogTradeToMySQL(int time, string symbol, string type, 
                      double volume, double price, double sl, double tp, ulong orderTicket, string comment)
   {
      string timeStr = TimeToString(time);
      
      // 首先记录到内存日志
      LogToMemory(timeStr, symbol, type, DoubleToString(volume), DoubleToString(price), 
                 DoubleToString(sl), DoubleToString(tp), comment);
      
      // 记录到MySQL数据库
      bool success = m_mysqlLogger.LogOrderEvent(
         "TRADE", symbol, type, volume, price, sl, tp,
         time, orderTicket, comment, "Trade executed successfully", 0
      );
      
      // 输出内存日志
      OutputMemoryLog();
      
      return success;
   }
   
   // 记录订单超时未成交
   void LogOrderTimeout(ulong orderTicket, string symbol, string orderType, double volume,
                       double entryPrice, double stopLoss, double takeProfit, datetime expiryTime,
                       string comment = "")
   {
      m_mysqlLogger.LogOrderTimeout(orderTicket, symbol, orderType, volume, entryPrice, 
                                   stopLoss, takeProfit, expiryTime, comment);
   }
   
   // 记录订单止盈
   void LogOrderTakeProfit(ulong orderTicket, string symbol, string orderType, double volume,
                         double entryPrice, double stopLoss, double takeProfit,
                         string comment = "")
   {
      m_mysqlLogger.LogOrderTakeProfit(orderTicket, symbol, orderType, volume, entryPrice, 
                                     stopLoss, takeProfit, comment);
   }
   
   // 记录订单止损
   void LogOrderStopLoss(ulong orderTicket, string symbol, string orderType, double volume,
                       double entryPrice, double stopLoss, double takeProfit,
                       string comment = "")
   {
      m_mysqlLogger.LogOrderStopLoss(orderTicket, symbol, orderType, volume, entryPrice, 
                                   stopLoss, takeProfit, comment);
   }
   
   // 记录订单成交
   void LogOrderFilled(ulong orderTicket, string symbol, string orderType, double volume,
                      double entryPrice, double stopLoss, double takeProfit, datetime expiryTime,
                      string comment = "")
   {
      m_mysqlLogger.LogOrderFilled(orderTicket, symbol, orderType, volume, entryPrice, 
                                  stopLoss, takeProfit, expiryTime, comment);
   }
   
   // 获取最后错误信息
   string GetLastError() const
   {
      return m_mysqlLogger.GetErrorDescription();
   }
   
   // 获取最后错误代码
   int GetLastErrorCode() const
   {
      return m_mysqlLogger.GetLastError();
   }
};