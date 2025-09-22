#define STATUS_ERROR -1
#include "DatabaseManager.mqh"

class CMySQLOrderLogger
{
private:
   CDatabaseManager* m_dbManager;
   bool m_initialized;

public:
   // 带参数的构造函数
   CMySQLOrderLogger(CDatabaseManager* dbManager) : 
      m_dbManager(dbManager),
      m_initialized(false)
   {
      if (m_dbManager != NULL)
      {
         m_initialized = true;
      }
      
      Print("MySQL订单日志记录器初始化完成");
   }
   
   // 析构函数
   ~CMySQLOrderLogger()
   {
      // 注意：这里不再删除m_dbManager，因为它是外部传入的
      m_dbManager = NULL;
   }

   bool Initialize(bool isReconnect = false)
   {
      if (m_dbManager == NULL)
      {
         Print("数据库管理器未初始化");
         return false;
      }
      
      // DatabaseManager在构造时已经初始化，这里可以重新连接
      return true;
   }
   
   // 创建订单日志表
   bool CreateOrderLogsTable()
   {
      if (m_dbManager == NULL)
      {
         Print("数据库管理器未初始化");
         return false;
      }
      
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
      
      return m_dbManager.Execute(query);
   }

   bool LogOrderEvent(string eventType, string symbol, string orderType, double volume,
                     double entryPrice, double stopLoss, double takeProfit, datetime eventTime,
                     ulong orderTicket, long positionId, long magicNumber, string comment, 
                     string result, int errorCode)
   {
      if (m_dbManager == NULL)
      {
         Print("数据库管理器未初始化");
         return false;
      }
      
      // 使用DatabaseManager记录订单事件
      string query = StringFormat(
         "INSERT INTO order_logs " +
         "(event_type, symbol, order_type, volume, entry_price, stop_loss, take_profit, event_time, " +
         "order_ticket, position_id, magic_number, profit, comment, result, error_code) " +
         "VALUES ('%s', '%s', '%s', %.2f, %.5f, %.5f, %.5f, FROM_UNIXTIME(%d), %d, %d, %d, %.2f, '%s', '%s', %d)",
         eventType, symbol, orderType, volume, entryPrice, stopLoss, takeProfit, 
         (int)eventTime, orderTicket, positionId, magicNumber, 0.0, comment, result, errorCode
      );
      
      return m_dbManager.Execute(query);
   }
   
   // 记录交易到MySQL数据库
   bool LogTradeToMySQL(int time, string symbol, string type, 
                      double volume, double price, double sl, double tp,
                      ulong orderTicket, long positionId, string comment)
   {
      if (m_dbManager == NULL)
      {
         Print("数据库管理器未初始化");
         return false;
      }
      
      // 直接使用数据库管理器记录交易
      string query = StringFormat(
         "INSERT INTO order_logs " +
         "(event_type, symbol, order_type, volume, entry_price, stop_loss, take_profit, event_time, " +
         "order_ticket, position_id, magic_number, profit, comment, result, error_code) " +
         "VALUES ('%s', '%s', '%s', %.2f, %.5f, %.5f, %.5f, FROM_UNIXTIME(%d), %d, %d, %d, %.2f, '%s', '%s', %d)",
         "TRADE", symbol, type, volume, price, sl, tp, 
         (int)time, orderTicket, positionId, 0, 0.0, comment, "Trade executed successfully", 0
      );
      
      return m_dbManager.Execute(query);
   }

   // 增量同步历史交易
   bool SyncTradeHistory()
   {
      if (m_dbManager == NULL)
      {
         Print("数据库管理器未初始化");
         return false;
      }
      
      // 查询数据库中最大的事件时间
      datetime lastSyncTime = 0;
      
      // 使用DatabaseManager的查询功能获取最大时间
      string query = "SELECT MAX(UNIX_TIMESTAMP(event_time)) as max_time FROM order_logs";
      string result = m_dbManager.QuerySingleValue(query);
      
      if (result != "" && StringToInteger(result) > 0)
      {
         // 如果查询成功且有结果，使用查询到的时间作为同步起点
         lastSyncTime = (datetime)StringToInteger(result);
         Print("从数据库获取的最后同步时间: ", TimeToString(lastSyncTime));
      }
      else
      {
         // 如果查询失败或没有记录，从100小时前开始同步
         lastSyncTime = TimeCurrent() - 360000;
         Print("使用默认同步时间: ", TimeToString(lastSyncTime));
      }
      
      // 获取从最后同步时间到当前时间的交易历史
      if(!HistorySelect(lastSyncTime, TimeCurrent()))
      {
         Print("获取历史数据失败");
         return false;
      }

      int totalDeals = HistoryDealsTotal();
      bool success = true;
      
      for(int i = 1; i < totalDeals; i++)
      {
         ulong dealTicket = HistoryDealGetTicket(i);
         string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
         double volume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
         double price = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
         long positionId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
         datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
         
         string dealType = (HistoryDealGetInteger(dealTicket, DEAL_TYPE) == DEAL_TYPE_BUY) ? "BUY" : "SELL";
         
         string query = StringFormat(
            "INSERT INTO order_logs " +
            "(event_type, symbol, order_type, volume, entry_price, stop_loss, take_profit, event_time, " +
            "order_ticket, position_id, magic_number, profit, comment, result, error_code) " +
            "VALUES ('%s', '%s', '%s', %.2f, %.5f, %.5f, %.5f, FROM_UNIXTIME(%d), %d, %d, %d, %.2f, '%s', '%s', %d)",
            "TRADE", symbol, dealType, volume, price, 0.0, 0.0, 
            (int)dealTime, dealTicket, positionId, 0, 0.0, "增量同步", "Trade executed successfully", 0
         );
         
         if(!m_dbManager.Execute(query))
         {
            success = false;
         }
      }
      
      return success;
   }
   
  
};