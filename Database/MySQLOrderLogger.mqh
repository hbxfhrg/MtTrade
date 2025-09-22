//+------------------------------------------------------------------+
//| MySQLOrderLogger.mqh                                             |
//| 数据库管理器（使用MySQL数据库存储）                              |
//+------------------------------------------------------------------+
#define STATUS_OK 0
#define STATUS_ERROR -1
#include "DatabaseManager.mqh"

class CMySQLOrderLogger
{
private:
   CDatabaseManager* m_dbManager;
   bool m_initialized;
   string m_memoryLog;
   ulong m_lastSyncedDeal;
   datetime m_lastSyncTime;

public:
   // 带参数的构造函数
   CMySQLOrderLogger(CDatabaseManager* dbManager) : 
      m_dbManager(dbManager),
      m_initialized(false),
      m_memoryLog(""),
      m_lastSyncedDeal(0),
      m_lastSyncTime(0)
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
      
      // 记录到内存日志
      m_memoryLog += StringFormat("[%s] %s %s %.2f @ %.5f (SL:%.5f TP:%.5f) #%d PosID:%d %s\n",
                                TimeToString(eventTime), symbol, orderType, 
                                volume, entryPrice, stopLoss, takeProfit, orderTicket, positionId, comment);
      
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
      
      // 记录到内存日志
      m_memoryLog += StringFormat("[%s] %s %s %.2f @ %.5f (SL:%.5f TP:%.5f) #%d PosID:%d %s\n",
                                TimeToString((datetime)time), symbol, type, 
                                volume, price, sl, tp, orderTicket, positionId, comment);
      
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
   bool SyncTradeHistory(datetime fromTime)
   {
      if (m_dbManager == NULL)
      {
         Print("数据库管理器未初始化");
         return false;
      }
      
      if(!HistorySelect(fromTime, TimeCurrent()))
      {
         Print("获取历史数据失败");
         return false;
      }

      int totalDeals = HistoryDealsTotal();
      bool success = true;
      
      for(int i = 0; i < totalDeals; i++)
      {
         ulong dealTicket = HistoryDealGetTicket(i);
         if(dealTicket > m_lastSyncedDeal)
         {
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
            else
            {
               m_lastSyncedDeal = dealTicket;
            }
         }
      }
      
      m_lastSyncTime = TimeCurrent();
      return success;
   }
   
   // 获取内存日志
   string GetMemoryLog() const
   {
      return m_memoryLog;
   }

   // 获取最后同步时间
   datetime GetLastSyncTime() const
   {
      return m_lastSyncTime;
   }

   // 获取最后同步的成交单号
   ulong GetLastSyncedDeal() const
   {
      return m_lastSyncedDeal;
   }
};