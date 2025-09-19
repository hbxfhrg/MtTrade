//+------------------------------------------------------------------+
//| MySQLOrderLogger.mqh                                             |
//| 数据库管理器（使用MySQL数据库存储）                              |
//+------------------------------------------------------------------+
#define STATUS_OK 0
#define STATUS_ERROR -1
#include "MQLMySQLClass.mqh"

class CMySQLOrderLogger
{
private:
   CMySQL m_mysql;
   string m_host;
   uint m_port;
   string m_database;
   string m_user;
   string m_password;
   bool m_initialized;

public:
   // 带参数的构造函数
   CMySQLOrderLogger(string host, uint port, string database, string user, string password) : 
      m_host(host), m_port(port), m_database(database), m_user(user), m_password(password), 
      m_initialized(false) 
   {
      Initialize();
   }

   bool Initialize(bool isReconnect = false)
   {
      if(!m_mysql.Connect(m_host, m_user, m_password, m_database, (int)m_port, "", 0))
      {
         Print("MySQL连接失败: ", m_mysql.LastErrorMessage());
         return false;
      }
      
      if(!isReconnect)
      {
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
                                "position_id BIGINT, " +
                                "comment TEXT, " +
                                "result TEXT, " +
                                "error_code INT" +
                                ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4";
         
         if(!m_mysql.Execute(createTableSQL))
         {
            Print("创建表失败: ", m_mysql.LastErrorMessage());
            return false;
         }
      }
      
      m_mysql.Disconnect();
      m_initialized = true;
      return true;
   }

   bool LogOrderEvent(string eventType, string symbol, string orderType, double volume,
                     double entryPrice, double stopLoss, double takeProfit, datetime eventTime,
                     ulong orderTicket, long positionId, string comment, string result, int errorCode)
   {
      string sql = StringFormat(
         "INSERT INTO order_logs "
         "(event_type, symbol, order_type, volume, entry_price, stop_loss, take_profit, event_time, order_ticket, position_id, comment, result, error_code) "
         "VALUES ('%s', '%s', '%s', %.2f, %.5f, %.5f, %.5f, FROM_UNIXTIME(%d), %d, %d, '%s', '%s', %d)",
         eventType, symbol, orderType, volume, entryPrice, stopLoss, takeProfit, 
         (int)eventTime, orderTicket, positionId, comment, result, errorCode
      );
      return ExecuteSQL(sql);
   }

   bool ExecuteSQL(const string sql)
   {
      if(!m_mysql.Connect(m_host, m_user, m_password, m_database, (int)m_port, "", 0))
         return false;
      
      bool result = m_mysql.Execute(sql);
      m_mysql.Disconnect();
      return result;
   }
};