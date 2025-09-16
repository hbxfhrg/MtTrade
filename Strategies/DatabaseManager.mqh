//+------------------------------------------------------------------+
//| DatabaseManager.mqh                                              |
//| 数据库管理器（使用MySQL数据库存储）                              |
//+------------------------------------------------------------------+
#include "../MySQLOrderLogger.mqh"
#include "../libmysql.mqh"

class CDatabaseManager
{
private:
   CMySQLOrderLogger m_mysqlLogger;
   string m_memoryLog;  // 内存日志存储
   
public:
   CDatabaseManager(string host = "rm-bp1dd16o34ktj6un0to.mysql.rds.aliyuncs.com", 
                   string username = "saas", 
                   string password = "Unic$!anb4agg1", 
                   string database = "pymt5", int port = 3306)
   {
      m_memoryLog = "";  // 初始化内存日志
      // 初始化MySQL连接
      if(!m_mysqlLogger.Initialize(host, port, database, username, password))
      {
         Print("DatabaseManager: MySQL连接初始化失败");
      }
   }
   
   // 检查MySQL连接状态
   bool IsConnected() const
   {
      return m_mysqlLogger.IsInitialized();
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
                      double volume, double price, double sl, double tp, string comment)
   {
      string timeStr = TimeToString(time);
      
      // 首先记录到内存日志
      LogToMemory(timeStr, symbol, type, DoubleToString(volume), DoubleToString(price), 
                 DoubleToString(sl), DoubleToString(tp), comment);
      
      // 转换数据类型
      double dVolume = volume;
      double dPrice = price;
      double dSL = sl;
      double dTP = tp;
      
      // 记录到MySQL数据库
      bool success = m_mysqlLogger.LogOrderEvent(
         "TRADE", symbol, type, dVolume, dPrice, dSL, dTP,
         0, 0, comment, "Trade executed successfully", 0
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
      return m_mysqlLogger.GetLastError();
   }
   
   // 获取最后错误代码
   int GetLastErrorCode() const
   {
      return m_mysqlLogger.GetLastErrorCode();
   }
};