//+------------------------------------------------------------------+
//| DatabaseManager.mqh                                              |
//| MySQL数据库管理器                                                |
//+------------------------------------------------------------------+
#include <MySQL/MySQL.mqh>

class CDatabaseManager
{
private:
   CMySQLConnection m_connection;
   string m_host;
   string m_username;
   string m_password;
   string m_database;
   int m_port;
   bool m_isConnected;
   
public:
   CDatabaseManager(string host = "localhost", string username = "root", 
                   string password = "", string database = "mttrade", int port = 3306)
   {
      m_host = host;
      m_username = username;
      m_password = password;
      m_database = database;
      m_port = port;
      m_isConnected = false;
      
      // 初始化数据库连接
      Connect();
   }
   
   ~CDatabaseManager()
   {
      if(m_isConnected)
      {
         m_connection.Disconnect();
      }
   }
   
   // 连接到MySQL数据库
   bool Connect()
   {
      if(m_connection.Connect(m_host, m_username, m_password, m_database, m_port))
      {
         m_isConnected = true;
         Print("成功连接到MySQL数据库: ", m_database);
         
         // 创建交易日志表（如果不存在）
         CreateTradeLogTable();
         return true;
      }
      else
      {
         m_isConnected = false;
         Print("连接MySQL数据库失败: ", m_connection.GetLastError());
         return false;
      }
   }
   
   // 创建交易日志表
   bool CreateTradeLogTable()
   {
      if(!m_isConnected)
         return false;
         
      string query = "CREATE TABLE IF NOT EXISTS trade_logs ("
                    "id INT AUTO_INCREMENT PRIMARY KEY, "
                    "log_time DATETIME, "
                    "symbol VARCHAR(20), "
                    "trade_type VARCHAR(20), "
                    "volume DECIMAL(10,2), "
                    "price DECIMAL(20,8), "
                    "stop_loss DECIMAL(20,8), "
                    "take_profit DECIMAL(20,8), "
                    "comment TEXT, "
                    "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP"
                    ")";
                    
      if(m_connection.Query(query))
      {
         Print("交易日志表已创建或已存在");
         return true;
      }
      else
      {
         Print("创建交易日志表失败: ", m_connection.GetLastError());
         return false;
      }
   }
   
   // 将交易记录保存到MySQL数据库
   bool LogTradeToMySQL(int time, string symbol, string type, 
                      string volume, string price, string sl, string tp, string comment)
   {
      if(!m_isConnected)
      {
         Print("数据库未连接，尝试重新连接...");
         if(!Connect())
         {
            Print("重新连接数据库失败");
            return false;
         }
      }
      
      // 准备SQL插入语句
      string query = StringFormat("INSERT INTO trade_logs (log_time, symbol, trade_type, volume, price, stop_loss, take_profit, comment) "
                                 "VALUES ('%s', '%s', '%s', %s, %s, %s, %s, '%s')",
                                 TimeToString(time, TIME_DATE|TIME_SECONDS),
                                 symbol,
                                 type,
                                 volume,
                                 price,
                                 sl,
                                 tp,
                                 comment);
      
      if(m_connection.Query(query))
      {
         Print("交易记录已保存到MySQL数据库");
         return true;
      }
      else
      {
         Print("保存交易记录到MySQL数据库失败: ", m_connection.GetLastError());
         return false;
      }
   }
   
   // 检查数据库连接状态
   bool IsConnected() const
   {
      return m_isConnected;
   }
   
   // 获取最后错误信息
   string GetLastError() const
   {
      return m_connection.GetLastError();
   }
};