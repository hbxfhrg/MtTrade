#include "MQLMySQLClass.mqh"

#define STATUS_OK 0
#define STATUS_ERROR -1
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
   // 默认构造函数
   CMySQLOrderLogger() : m_initialized(false), m_port(3306) {}
   
   // 带参数的构造函数
   CMySQLOrderLogger(string host, uint port, string database, string user, string password) : 
      m_host(host), m_port(port), m_database(database), m_user(user), m_password(password), 
      m_initialized(false) {}
   
   bool Initialize(bool isReconnect = false)
   {
      // 初始化MySQL连接
      if(!m_mysql.Connect(m_host, m_user, m_password, m_database, (int)m_port, "", 0))
      {
         Print("MySQLOrderLogger: 连接失败 - ", m_mysql.LastErrorMessage(), " (错误码: ", m_mysql.LastError(), ")");
         return false;
      }
      
      // 如果不是重连操作，才创建表和设置字符集
      if(!isReconnect)
      {
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
                                "expiry_time VARCHAR(50), " +
                                "order_ticket BIGINT, " +
                                "comment TEXT, " +
                                "result TEXT, " +
                                "error_code INT" +
                                ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4";
         
         if(!m_mysql.Execute(createTableSQL))
         {
            Print("MySQLOrderLogger: 创建表失败 - ", m_mysql.LastErrorMessage());
            return false;
         }
         
         // 设置连接字符集为UTF8
         if(!m_mysql.Execute("SET NAMES utf8mb4"))
         {
            Print("MySQLOrderLogger: 设置字符集失败 - ", m_mysql.LastErrorMessage());
         }
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
      
      return Initialize(false);
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

      // 转义字符串参数以防止SQL注入
      string escapedEventType = eventType;
      string escapedSymbol = symbol;
      string escapedOrderType = orderType;
      string escapedComment = comment;
      string escapedResult = result;

      StringReplace(escapedEventType, "'", "''");
      StringReplace(escapedSymbol, "'", "''");
      StringReplace(escapedOrderType, "'", "''");
      StringReplace(escapedComment, "'", "''");
      StringReplace(escapedResult, "'", "''");

      // 使用参数化查询防止SQL注入
      string sql = StringFormat(
         "INSERT INTO order_logs "
         "(event_type, symbol, order_type, volume, entry_price, stop_loss, take_profit, expiry_time, order_ticket, comment, result, error_code) "
         "VALUES (" 
         "'%s', '%s', '%s', %.2f, %.5f, %.5f, %.5f, '%s', %d, '%s', '%s', %d"
         ")",
         escapedEventType, escapedSymbol, escapedOrderType, volume,
         entryPrice, stopLoss, takeProfit, 
         TimeToString(expiryTime, TIME_DATE|TIME_MINUTES), 
         orderTicket, escapedComment, escapedResult, errorCode
      );
                               
      // 打印SQL语句用于核对
      Print("即将执行的SQL语句: ", sql);

      // 使用新的通用执行方法执行SQL
      return ExecuteSQL(sql);
   }
   
   // 更新订单事件（如果订单已存在则更新，否则插入）
   bool UpdateOrderEvent(string eventType, string symbol, string orderType, double volume,
                       double entryPrice, double stopLoss, double takeProfit, datetime expiryTime,
                       ulong orderTicket, string comment, string result, int errorCode)
   {
      if(!m_initialized)
      {
         Print("MySQLOrderLogger: 未初始化");
         return false;
      }

      // 首先检查订单是否已存在
      string checkSql = StringFormat("SELECT 1 FROM order_logs WHERE order_ticket = %d LIMIT 1", orderTicket);
      bool orderExists = false;
      
      // 使用新的通用执行方法检查订单是否存在
      CMySQL tempMysql;
      
      // 连接数据库
      if(tempMysql.Connect(m_host, m_user, m_password, m_database, (int)m_port, "", 0))
      {
         // 设置连接字符集为UTF8
         tempMysql.Execute("SET NAMES utf8mb4");
         
         // 执行检查SQL
         if(tempMysql.Execute(checkSql))
         {
            orderExists = true;
         }
         
         // 关闭连接
         tempMysql.Disconnect();
      }

      if(orderExists)
      {
         // 订单存在，执行更新操作
         string escapedEventType = eventType;
         string escapedSymbol = symbol;
         string escapedOrderType = orderType;
         string escapedComment = comment;
         string escapedResult = result;

         StringReplace(escapedEventType, "'", "''");
         StringReplace(escapedSymbol, "'", "''");
         StringReplace(escapedOrderType, "'", "''");
         StringReplace(escapedComment, "'", "''");
         StringReplace(escapedResult, "'", "''");

         string updateSql = StringFormat(
            "UPDATE order_logs SET "
            "event_type = '%s', symbol = '%s', order_type = '%s', volume = %.2f, "
            "entry_price = %.5f, stop_loss = %.5f, take_profit = %.5f, expiry_time = '%s', "
            "comment = '%s', result = '%s', error_code = %d, event_time = NOW() "
            "WHERE order_ticket = %d",
            escapedEventType, escapedSymbol, escapedOrderType, volume,
            entryPrice, stopLoss, takeProfit, 
            TimeToString(expiryTime, TIME_DATE|TIME_MINUTES),
            escapedComment, escapedResult, errorCode, orderTicket
         );
         
         Print("即将执行的更新SQL语句: ", updateSql);
         
         // 使用新的通用执行方法执行更新SQL
         bool result = ExecuteSQL(updateSql);
         if(result)
         {
            Print("订单 #", orderTicket, " 更新成功");
         }
         return result;
      }
      else
      {
         // 订单不存在，执行插入操作
         return LogOrderEvent(eventType, symbol, orderType, volume, entryPrice, stopLoss, 
                            takeProfit, expiryTime, orderTicket, comment, result, errorCode);
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
   
   // 检查表是否存在
   bool CheckTableExists(const string tableName)
   {
      if(!m_initialized) return false;
      string sql = StringFormat("SELECT 1 FROM %s LIMIT 1", tableName);
      return m_mysql.Execute(sql);
   }
   
   // 创建表
   bool CreateTable(const string tableName, const string createSQL)
   {
      if(!m_initialized) return false;
      return m_mysql.Execute(createSQL);
   }
   
   // 获取最后错误信息
   string GetErrorDescription() const
   {
      return m_mysql.LastErrorMessage();
   }
   
   // 获取最后错误代码
   int GetLastError() const
   {
      return m_mysql.LastError();
   }

   void Close()
   {
      m_mysql.Disconnect();
      m_initialized = false;
   }
   
   // 通用数据库执行方法（每次执行都重新连接）
   bool ExecuteSQL(const string sql)
   {
      // 每次执行SQL都重新建立连接
      CMySQL tempMysql;
      
      // 连接数据库
      if(!tempMysql.Connect(m_host, m_user, m_password, m_database, (int)m_port, "", 0))
      {
         Print("MySQLOrderLogger: 连接失败 - ", tempMysql.LastErrorMessage(), " (错误码: ", tempMysql.LastError(), ")");
         return false;
      }
      
      // 设置连接字符集为UTF8
      tempMysql.Execute("SET NAMES utf8mb4");
      
      // 执行SQL
      bool result = tempMysql.Execute(sql);
      
      // 关闭连接
      tempMysql.Disconnect();
      
      if(!result)
      {
         Print("MySQLOrderLogger: SQL执行失败 - ", tempMysql.LastErrorMessage(), " (错误码: ", tempMysql.LastError(), ")");
         Print("失败SQL语句: ", sql);
      }
      
      return result;
   }
   
   ~CMySQLOrderLogger()
   {
      Close();
   }

   // 数据库操作测试函数
   static void TestDatabaseOperations()
   {
      Print("=== 开始数据库测试 ===");
      
      // 1. 测试连接
      CMySQLOrderLogger tester;
      if(!tester.Initialize("rm-bp1dd16o34ktj6un0to.mysql.rds.aliyuncs.com", 
                      3306, "pymt5", "saas", "Unic$!anb4agg1"))
      {
         Print("测试失败: 无法连接数据库");
         return;
      }
      Print("测试通过: 数据库连接成功");
      
      // 2. 测试插入操作
      datetime testTime = TimeCurrent();
      string testSymbol = "TEST" + IntegerToString(GetTickCount() % 1000);
      bool insertResult = tester.LogOrderEvent(
         "TEST", testSymbol, "TEST_ORDER", 1.0,
         100.0, 99.0, 101.0, testTime, 
         999999, "测试订单", "测试成功", 0
      );
      
      if(!insertResult)
      {
         Print("测试失败: 插入操作失败 - ", tester.GetErrorDescription());
         return;
      }
      Print("测试通过: 插入操作成功");
      
      // 3. 测试查询验证
      // 这里可以添加查询验证代码，确认数据已插入
      
      Print("=== 数据库测试完成 ===");
   }
};