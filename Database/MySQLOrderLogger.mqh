#property copyright "Copyright 2024"
#property version   "1.00"

#include "libmysql.mqh"

class CMySQLOrderLogger
{
private:
   CMySQL_Connection m_mysql;
   string m_host;
   uint m_port;
   string m_database;
   string m_user;
   string m_password;
   bool m_initialized;
   
   // 转义字符串中的特殊字符
   string EscapeString(const string &str)
   {
      string result = str;
      StringReplace(result, "'", "\\'");
      StringReplace(result, "\"", "\\\"");
      StringReplace(result, "\\", "\\\\");
      return result;
   }
   
public:
   // 默认构造函数
   CMySQLOrderLogger() : m_initialized(false), m_port(3306) {}
   
   // 带参数的构造函数
   CMySQLOrderLogger(string host, uint port, string database, string user, string password) : 
      m_host(host), m_port(port), m_database(database), m_user(user), m_password(password), 
      m_initialized(false) {}
   
   bool Initialize()
   {
      if(!m_mysql.Init())
      {
         Print("MySQLOrderLogger: 初始化失败 - ", m_mysql.GetErrorDescription());
         return false;
      }
      
      if(!m_mysql.Connect(m_host, m_port, m_database, m_user, m_password))
      {
         Print("MySQLOrderLogger: 连接失败 - ", m_mysql.GetErrorDescription(), " (错误码: ", m_mysql.GetLastError(), ")");
         return false;
      }
      
      // 创建订单日志表
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
                             "expiry_time DATETIME, " +
                             "order_ticket BIGINT, " +
                             "comment TEXT, " +
                             "result TEXT, " +
                             "error_code INT" +
                             ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4";
      
      if(m_mysql.ExecSQL(createTableSQL) != STATUS_OK)
      {
         Print("MySQLOrderLogger: 创建表失败 - ", m_mysql.GetErrorDescription());
         return false;
      }
      
      m_initialized = true;
      Print("MySQLOrderLogger: 初始化成功");
      return true;
   }
   
   // 重载Initialize函数，支持传入连接参数
   bool Initialize(string host, uint port, string database, string user, string password)
   {
      m_host = host;
      m_port = port;
      m_database = database;
      m_user = user;
      m_password = password;
      
      return Initialize();
   }
   
   bool LogOrderEvent(string eventType, string symbol, string orderType, double volume,
                     double entryPrice, double stopLoss, double takeProfit, datetime expiryTime,
                     ulong orderTicket, string comment, string result, int errorCode)
   {
      if(!m_initialized)
      {
         Print("MySQLOrderLogger: 未初始化");
         return false;
      }
      
      string sql = StringFormat("INSERT INTO order_logs (event_type, symbol, order_type, volume, " +
                               "entry_price, stop_loss, take_profit, expiry_time, order_ticket, " +
                               "comment, result, error_code) VALUES ('%s', '%s', '%s', %.2f, " +
                               "%.5f, %.5f, %.5f, FROM_UNIXTIME(%d), %d, '%s', '%s', %d)",
                               EscapeString(eventType), EscapeString(symbol), EscapeString(orderType), volume,
                               entryPrice, stopLoss, takeProfit, expiryTime, orderTicket,
                               EscapeString(comment), EscapeString(result), errorCode);
      
      if(m_mysql.ExecSQL(sql) == STATUS_OK)
      {
         return true;
      }
      else
      {
         Print("MySQLOrderLogger: 记录事件失败 - ", m_mysql.GetErrorDescription(), " (错误码: ", m_mysql.GetLastError(), ")");
         return false;
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
   
   // 记录订单成交
   void LogOrderFilled(ulong orderTicket, string symbol, string orderType, double volume,
                      double entryPrice, double stopLoss, double takeProfit, datetime expiryTime,
                      string comment = "")
   {
      LogOrderEvent("FILLED", symbol, orderType, volume, entryPrice, stopLoss, takeProfit,
                   expiryTime, orderTicket, comment, "Order filled successfully", 0);
   }
   
   // 记录订单取消
   void LogOrderCancelled(ulong orderTicket, string symbol, string orderType, double volume,
                        double entryPrice, double stopLoss, double takeProfit, datetime expiryTime,
                        string comment = "")
   {
      LogOrderEvent("CANCELLED", symbol, orderType, volume, entryPrice, stopLoss, takeProfit,
                   expiryTime, orderTicket, comment, "Order cancelled", 0);
   }
   
   // 记录订单错误
   void LogOrderError(ulong orderTicket, string symbol, string orderType, double volume,
                    double entryPrice, double stopLoss, double takeProfit, datetime expiryTime,
                    string comment, int errorCode)
   {
      LogOrderEvent("ERROR", symbol, orderType, volume, entryPrice, stopLoss, takeProfit,
                   expiryTime, orderTicket, comment, "Order error occurred", errorCode);
   }
   
   // 记录订单止盈
   void LogOrderTakeProfit(ulong orderTicket, string symbol, string orderType, double volume,
                         double entryPrice, double stopLoss, double takeProfit,
                         string comment = "")
   {
      LogOrderEvent("TAKE_PROFIT", symbol, orderType, volume, entryPrice, stopLoss, takeProfit,
                   0, orderTicket, comment, "Order take profit triggered", 0);
   }
   
   // 记录订单止损
   void LogOrderStopLoss(ulong orderTicket, string symbol, string orderType, double volume,
                       double entryPrice, double stopLoss, double takeProfit,
                       string comment = "")
   {
      LogOrderEvent("STOP_LOSS", symbol, orderType, volume, entryPrice, stopLoss, takeProfit,
                   0, orderTicket, comment, "Order stop loss triggered", 0);
   }
   
   bool IsInitialized() const { return m_initialized; }
   
   // 获取最后错误信息
   string GetLastError() const
   {
      return m_mysql.GetErrorDescription();
   }
   
   // 获取最后错误代码
   int GetLastErrorCode() const
   {
      return m_mysql.GetLastError();
   }
   
   void Close()
   {
      m_mysql.Close();
      m_initialized = false;
   }
   
   ~CMySQLOrderLogger()
   {
      Close();
   }
};