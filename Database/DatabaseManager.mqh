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
   CDatabaseManager(string host, string username, string password, string database, int port)
   {
      m_memoryLog = "";  // 初始化内存日志
      
      // 创建MySQLOrderLogger实例并保存连接参数
      m_mysqlLogger = CMySQLOrderLogger(host, (uint)port, database, username, password);
      
      // 初始化MySQLOrderLogger（创建表结构）
      if(!m_mysqlLogger.Initialize())
      {
         Print("DatabaseManager: MySQL表结构初始化失败 - ", m_mysqlLogger.GetErrorDescription());
      }
      else
      {
         Print("DatabaseManager: 初始化完成（按需连接模式）");
      }
   }
   
   // 检查表是否存在
   bool CheckTableExists(string tableName)
   {
      return m_mysqlLogger.CheckTableExists(tableName);
   }
   
   // 创建订单日志表（如果不存在）
   bool CreateOrderLogsTableIfNotExists()
   {
      // 直接调用MySQLOrderLogger的Initialize方法创建表
      return m_mysqlLogger.Initialize(false); // 传入false确保会创建表
   }
   
   // 检查并创建必要的表
   bool CheckAndCreateTables()
   {
      // 检查order_logs表是否存在
      if(!CheckTableExists("order_logs"))
      {
         Print("DatabaseManager: order_logs表不存在，正在创建...");
         if(CreateOrderLogsTableIfNotExists())
         {
            Print("DatabaseManager: order_logs表创建成功");
            return true;
         }
         else
         {
            Print("DatabaseManager: order_logs表创建失败 - ", GetLastError());
            return false;
         }
      }
      else
      {
         Print("DatabaseManager: order_logs表已存在");
         return true;
      }
   }
   
   // 检查MySQL连接状态（按需连接模式下总是返回true）
   bool IsConnected() const
   {
      return true; // 按需连接模式下不需要检查连接状态
   }
   
   // 检查并维持连接（按需连接模式下不需要）
   bool CheckConnection()
   {
      return true; // 按需连接模式下不需要维持连接
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
   
   // 将交易记录保存到MySQL数据库（使用更新机制）
   bool LogTradeToMySQL(int time, string symbol, string type, 
                      double volume, double price, double sl, double tp, ulong orderTicket, ulong positionId, long magicNumber, string comment)
   {
      string timeStr = TimeToString(time);
      
      // 首先记录到内存日志
      LogToMemory(timeStr, symbol, type, DoubleToString(volume), DoubleToString(price), 
                 DoubleToString(sl), DoubleToString(tp), comment);
      
      // 使用更新机制记录到MySQL数据库（如果订单已存在则更新，否则插入）
      bool success = m_mysqlLogger.UpdateOrderEvent(
         "TRADE", symbol, type, volume, price, sl, tp,
         (datetime)time, orderTicket, positionId, magicNumber, comment, "Trade executed successfully", 0
      );
      
      // 输出内存日志
      OutputMemoryLog();
      
      return success;
   }
   
   // 向后兼容的LogTradeToMySQL函数
   bool LogTradeToMySQL(int time, string symbol, string type, 
                      double volume, double price, double sl, double tp, ulong orderTicket, string comment)
   {
      return LogTradeToMySQL(time, symbol, type, volume, price, sl, tp, orderTicket, 0, 0, comment);
   }
   
   // 记录订单超时未成交
   void LogOrderTimeout(ulong orderTicket, ulong positionId, long magicNumber, string symbol, string orderType, double volume,
                       double entryPrice, double stopLoss, double takeProfit, datetime expiryTime,
                       string comment = "")
   {
      m_mysqlLogger.LogOrderTimeout(orderTicket, positionId, magicNumber, symbol, orderType, volume, entryPrice, 
                                   stopLoss, takeProfit, expiryTime, comment);
   }
   
   // 向后兼容的LogOrderTimeout函数
   void LogOrderTimeout(ulong orderTicket, string symbol, string orderType, double volume,
                       double entryPrice, double stopLoss, double takeProfit, datetime expiryTime,
                       string comment = "")
   {
      LogOrderTimeout(orderTicket, 0, 0, symbol, orderType, volume, entryPrice, stopLoss, takeProfit, expiryTime, comment);
   }
   
   // 记录订单止盈
   void LogOrderTakeProfit(ulong orderTicket, ulong positionId, long magicNumber, string symbol, string orderType, double volume,
                         double entryPrice, double stopLoss, double takeProfit,
                         string comment = "")
   {
      m_mysqlLogger.LogOrderTakeProfit(orderTicket, positionId, magicNumber, symbol, orderType, volume, entryPrice, 
                                     stopLoss, takeProfit, comment);
   }
   
   // 向后兼容的LogOrderTakeProfit函数
   void LogOrderTakeProfit(ulong orderTicket, string symbol, string orderType, double volume,
                         double entryPrice, double stopLoss, double takeProfit,
                         string comment = "")
   {
      LogOrderTakeProfit(orderTicket, 0, 0, symbol, orderType, volume, entryPrice, stopLoss, takeProfit, comment);
   }
   
   // 记录订单止损
   void LogOrderStopLoss(ulong orderTicket, ulong positionId, long magicNumber, string symbol, string orderType, double volume,
                       double entryPrice, double stopLoss, double takeProfit,
                       string comment = "")
   {
      m_mysqlLogger.LogOrderStopLoss(orderTicket, positionId, magicNumber, symbol, orderType, volume, entryPrice, 
                                   stopLoss, takeProfit, comment);
   }
   
   // 向后兼容的LogOrderStopLoss函数
   void LogOrderStopLoss(ulong orderTicket, string symbol, string orderType, double volume,
                       double entryPrice, double stopLoss, double takeProfit,
                       string comment = "")
   {
      LogOrderStopLoss(orderTicket, 0, 0, symbol, orderType, volume, entryPrice, stopLoss, takeProfit, comment);
   }
   
   // 记录订单成交
   void LogOrderFilled(ulong orderTicket, ulong positionId, long magicNumber, string symbol, string orderType, double volume,
                      double entryPrice, double stopLoss, double takeProfit, datetime expiryTime,
                      string comment = "")
   {
      m_mysqlLogger.LogOrderFilled(orderTicket, positionId, magicNumber, symbol, orderType, volume, entryPrice, 
                                  stopLoss, takeProfit, expiryTime, comment);
   }
   
   // 向后兼容的LogOrderFilled函数
   void LogOrderFilled(ulong orderTicket, string symbol, string orderType, double volume,
                      double entryPrice, double stopLoss, double takeProfit, datetime expiryTime,
                      string comment = "")
   {
      LogOrderFilled(orderTicket, 0, 0, symbol, orderType, volume, entryPrice, stopLoss, takeProfit, expiryTime, comment);
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
   
   // 更新持仓信息（开仓或加仓）
   bool UpdatePosition(string symbol, string positionType, double volume, double entryPrice, 
                      double stopLoss, double takeProfit, ulong orderTicket, ulong positionId, long magicNumber, string comment = "")
   {
      return m_mysqlLogger.UpdatePosition(symbol, positionType, volume, entryPrice, 
                                         stopLoss, takeProfit, orderTicket, positionId, magicNumber, comment);
   }
   
   // 向后兼容的UpdatePosition函数
   bool UpdatePosition(string symbol, string positionType, double volume, double entryPrice, 
                      double stopLoss, double takeProfit, ulong orderTicket, string comment = "")
   {
      return UpdatePosition(symbol, positionType, volume, entryPrice, stopLoss, takeProfit, orderTicket, 0, 0, comment);
   }
   
   // 关闭持仓（平仓）
   bool ClosePosition(string symbol, string positionType, double exitPrice, ulong orderTicket, ulong positionId, long magicNumber, string comment = "")
   {
      return m_mysqlLogger.ClosePosition(symbol, positionType, exitPrice, orderTicket, positionId, magicNumber, comment);
   }
   
   // 向后兼容的ClosePosition函数
   bool ClosePosition(string symbol, string positionType, double exitPrice, ulong orderTicket, string comment = "")
   {
      return ClosePosition(symbol, positionType, exitPrice, orderTicket, 0, 0, comment);
   }
};