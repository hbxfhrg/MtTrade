//+------------------------------------------------------------------+
//| MySQLOrderLogger.mqh                                             |
//| 数据库管理器（使用MySQL数据库存储）                              |
//+------------------------------------------------------------------+
#define STATUS_OK 0
#define STATUS_ERROR -1
#include "CMySQL.mqh"

class CMySQLOrderLogger
{
private:
   CMySQL m_mysql;
   string m_host;
   int m_port;
   string m_database;
   string m_user;
   string m_password;
   bool m_initialized;

public:
   // 带参数的构造函数
   CMySQLOrderLogger(string host, int port, string database, string user, string password) : 
      m_host(host), m_port(port), m_database(database), m_user(user), m_password(password),
      m_initialized(false) 
   {
   }

   bool Initialize(bool isReconnect = false)
   {
      if(!m_mysql.Connect(m_host, m_user, m_password, m_database, m_port, "", 0))
      {
         Print("MySQL连接失败: ", m_mysql.LastErrorMessage());
         return false;
      }
      
      m_initialized = true;
      return true;
   }
   
   // 创建订单日志表
   bool CreateOrderLogsTable()
   {
      string query = "CREATE TABLE IF NOT EXISTS order_logs (" +
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
                    "magic_number BIGINT, " +
                    "profit DOUBLE, " +
                    "comment TEXT, " +
                    "result TEXT, " +
                    "error_code INT" +
                    ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4";
      
      if (!m_mysql.Execute(query))
      {
         Print("创建订单日志表失败: ", m_mysql.LastErrorMessage());
         return false;
      }
      
      return true;
   }

   bool LogOrderEvent(string eventType, string symbol, string orderType, double volume,
                     double entryPrice, double stopLoss, double takeProfit, datetime eventTime,
                     ulong orderTicket, long positionId, long magicNumber, string comment, 
                     string result, int errorCode)
   {
      string query = StringFormat(
         "INSERT INTO order_logs " +
         "(event_type, symbol, order_type, volume, entry_price, stop_loss, take_profit, event_time, " +
         "order_ticket, position_id, magic_number, profit, comment, result, error_code) " +
         "VALUES ('%s', '%s', '%s', %.2f, %.5f, %.5f, %.5f, FROM_UNIXTIME(%d), %d, %d, %d, %.2f, '%s', '%s', %d)",
         eventType, symbol, orderType, volume, entryPrice, stopLoss, takeProfit, 
         (int)eventTime, orderTicket, positionId, magicNumber, 0.0, comment, result, errorCode
      );
      
      if (!m_mysql.Execute(query))
      {
         Print("记录订单事件失败: ", m_mysql.LastErrorMessage());
         // 检查是否是"Commands out of sync"错误(2014)
         if (m_mysql.LastError() == 2014)
         {
            Print("检测到命令不同步错误，正在尝试重新连接...");
            m_mysql.Disconnect();
            if (Initialize(true))
            {
               // 重新连接成功后再次尝试执行查询
               if (!m_mysql.Execute(query))
               {
                  Print("重新执行查询失败: ", m_mysql.LastErrorMessage());
                  return false;
               }
               return true;
            }
         }
         return false;
      }
      
      return true;
   }
};