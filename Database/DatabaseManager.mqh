//+------------------------------------------------------------------+
//| DatabaseManager.mqh                                              |
//| 数据库管理器（使用MySQL数据库存储）                              |
//+------------------------------------------------------------------+
#include "MySQLOrderLogger.mqh"

class CDatabaseManager
{
private:
   CMySQLOrderLogger m_mysqlLogger;
   string m_memoryLog;
   ulong m_lastSyncedDeal;
   datetime m_lastSyncTime;

public:
   // 带参数的构造函数
   CDatabaseManager(string host, string username, string password, string database, int port) :
      m_mysqlLogger(host, (uint)port, database, username, password),
      m_memoryLog(""),
      m_lastSyncedDeal(0),
      m_lastSyncTime(0)
   {
      Print("数据库管理器初始化完成");
   }

   // 记录交易到MySQL数据库
   bool LogTradeToMySQL(int time, string symbol, string type, 
                      double volume, double price, double sl, double tp,
                      ulong orderTicket, long positionId, string comment)
   {
      // 记录到内存日志
      m_memoryLog += StringFormat("[%s] %s %s %.2f @ %.5f (SL:%.5f TP:%.5f) #%d PosID:%d %s\n",
                                TimeToString((datetime)time), symbol, type, 
                                volume, price, sl, tp, orderTicket, positionId, comment);
      
      // 调用MySQLOrderLogger记录交易
      return m_mysqlLogger.LogOrderEvent(
         "TRADE", symbol, type, volume, price, sl, tp,
         (datetime)time, orderTicket, positionId, comment, 
         "Trade executed successfully", 0
      );
   }

   // 增量同步历史交易
   bool SyncTradeHistory(datetime fromTime)
   {
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
            
            if(!LogTradeToMySQL(
               (int)dealTime, symbol,
               (HistoryDealGetInteger(dealTicket, DEAL_TYPE) == DEAL_TYPE_BUY) ? "BUY" : "SELL",
               volume, price, 0, 0, dealTicket, positionId, "增量同步"
            ))
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