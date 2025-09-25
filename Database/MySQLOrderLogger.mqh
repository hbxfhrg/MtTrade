#define STATUS_ERROR -1
#include "DatabaseManager.mqh"
#include "..\Logging\SimpleCSVLogger.mqh"

class CMySQLOrderLogger
{
private:
   CDatabaseManager* m_dbManager;
   CSimpleCSVLogger* m_csvLogger;  // 使用简化版CSV日志记录器
   bool m_initialized;

public:
   // 带参数的构造函数（默认文件名）
   CMySQLOrderLogger(CDatabaseManager* dbManager) : 
      m_dbManager(dbManager),
      m_csvLogger(new CSimpleCSVLogger("trade_orders.csv", dbManager)),  // 初始化简化版CSV日志记录器并传递数据库管理器
      m_initialized(false)
   {
      if (m_dbManager != NULL)
      {
         m_initialized = true;
      }
      
      Print("MySQL订单日志记录器初始化完成");
   }
   
   // 带参数的构造函数（自定义文件名）
   CMySQLOrderLogger(CDatabaseManager* dbManager, string filename) : 
      m_dbManager(dbManager),
      m_csvLogger(new CSimpleCSVLogger(filename, dbManager)),  // 初始化简化版CSV日志记录器并传递数据库管理器和自定义文件名
      m_initialized(false)
   {
      if (m_dbManager != NULL)
      {
         m_initialized = true;
      }
      
      // 在测试模式下启用时间戳
      if(MQLInfoInteger(MQL_TESTER))
      {
         m_csvLogger.SetUseTimestamp(true);
      }
      
      Print("MySQL订单日志记录器初始化完成，使用文件名: ", filename);
   }
   
   // 析构函数
   ~CMySQLOrderLogger()
   {
      // 注意：这里不再删除m_dbManager，因为它是外部传入的
      m_dbManager = NULL;
      
      // 删除CSV日志记录器
      if(m_csvLogger != NULL)
      {
         delete m_csvLogger;
         m_csvLogger = NULL;
      }
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
                    "entry_time DATETIME DEFAULT NULL, " +  // 进场时间
                    "exit_time DATETIME DEFAULT NULL, " +   // 出场时间
                    "event_type VARCHAR(20), " +
                    "symbol VARCHAR(20), " +
                    "order_type VARCHAR(20), " +
                    "volume DOUBLE, " +
                    "entry_price DOUBLE, " +
                    "stop_loss DOUBLE, " +
                    "take_profit DOUBLE, " +
                    "exit_price DOUBLE, " +  // 添加出场价字段
                    "profit DOUBLE, " +      // 实际利润字段
                    "order_ticket BIGINT, " +
                    "position_id BIGINT, " +
                    "magic_number BIGINT, " +
                    "comment TEXT, " +
                    "result TEXT, " +
                    "error_code INT, " +
                    "deal_entry VARCHAR(20)" +  // 添加deal_entry字段
                    ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4";
      
      return m_dbManager.Execute(query);
   }
   
   bool LogOrderEvent(string eventType, string symbol, string orderType, double volume,
                     double entryPrice, double stopLoss, double takeProfit, double exitPrice, double actualProfit,
                     datetime eventTime, ulong orderTicket, long positionId, long magicNumber, string comment, 
                     string result, int errorCode, string dealEntry = "")
   {
      if (m_dbManager == NULL)
      {
         Print("数据库管理器未初始化");
         return false;
      }
      
      // 根据deal_entry值决定操作类型
      if(dealEntry == "IN")
      {
         // 只记录到CSV文件（记录入场交易），不执行MySQL操作
         if(m_csvLogger != NULL)
         {
            m_csvLogger.LogEntry(eventType, symbol, orderType, volume, entryPrice, stopLoss, takeProfit, 
                               eventTime, orderTicket, positionId, magicNumber, 
                               comment, result, errorCode, dealEntry);
         }
         
         // IN事件不执行MySQL操作
         return true;
      }
      else if(dealEntry == "OUT" || dealEntry == "OUT_BY")
      {
         // 同时更新CSV文件中的记录，SimpleCSVLogger会自动写入MySQL
         if(m_csvLogger != NULL)
         {
            return m_csvLogger.LogExit(positionId, exitPrice, actualProfit, eventTime, dealEntry, comment);
         }
         
         return false;
      }
      
      return false;
   }
   
   // 记录交易到MySQL数据库
   bool LogTradeToMySQL(int time, string symbol, string type, 
                      double volume, double price, double sl, double tp, double exitPrice, double actualProfit,
                      ulong orderTicket, long positionId, string comment, string dealEntry = "")
   {
      if (m_dbManager == NULL)
      {
         Print("数据库管理器未初始化");
         return false;
      }
      
      datetime eventTime = (datetime)time;
      
      // 根据deal_entry值决定操作类型
      if(dealEntry == "IN")
      {
         // 只记录到CSV文件（记录入场交易），不执行MySQL操作
         if(m_csvLogger != NULL)
         {
            m_csvLogger.LogEntry("TRADE", symbol, type, volume, price, sl, tp, 
                               eventTime, orderTicket, positionId, 0, 
                               comment, "Trade executed successfully", 0, dealEntry);
         }
         
         // IN事件不执行MySQL操作
         return true;
      }
      else if(dealEntry == "OUT" || dealEntry == "OUT_BY")
      {
         // 同时更新CSV文件中的记录，SimpleCSVLogger会自动写入MySQL
         if(m_csvLogger != NULL)
         {
            return m_csvLogger.LogExit(positionId, exitPrice, actualProfit, eventTime, dealEntry, comment);
         }
         
         return false;
      }
      
      return false;
   }

   // 增量同步历史交易
   bool SyncTradeHistory()
   {
      if (m_dbManager == NULL)
      {
         Print("数据库管理器未初始化");
         return false;
      }
      
      // 先从CSV文件获取最后同步时间
      datetime lastSyncTime = 0;
      datetime dbLastSyncTime = 0;
      
      // 获取CSV文件中的最大时间
      if(m_csvLogger != NULL)
      {
         lastSyncTime = m_csvLogger.GetLastSyncTime();
         Print("从CSV文件获取的最后同步时间: ", TimeToString(lastSyncTime));
         
         // 如果CSV中没有记录，则查询数据库
         if (lastSyncTime == 0 && m_dbManager != NULL)
         {
            // 使用DatabaseManager的查询功能获取数据库最大时间
            string query = "SELECT GREATEST(MAX(UNIX_TIMESTAMP(entry_time)), MAX(UNIX_TIMESTAMP(exit_time))) as max_time FROM order_logs";
            string result = m_dbManager.QuerySingleValue(query);
            
            if (result != "" && StringToInteger(result) > 0)
            {
               // 如果查询成功且有结果，使用查询到的时间作为同步起点
               dbLastSyncTime = (datetime)StringToInteger(result);
               lastSyncTime = dbLastSyncTime;
               Print("从数据库获取的最后同步时间: ", TimeToString(dbLastSyncTime));
            }
         }
         
         // 如果CSV和数据库都没有记录，使用默认时间
         if (lastSyncTime == 0)
         {
            // 如果都没有记录，从100小时前开始同步
            lastSyncTime = TimeCurrent() - 360000;
            Print("CSV和数据库中均无记录，使用默认同步时间: ", TimeToString(lastSyncTime));
         }
         else
         {
            Print("使用最后同步时间: ", TimeToString(lastSyncTime));
         }
      }
      else
      {
         Print("CSV日志记录器未初始化");
         return false;
      }
      
      // 获取从最后同步时间到当前时间的交易历史
      if(!HistorySelect(lastSyncTime, TimeCurrent()))
      {
         Print("获取历史数据失败");
         return false;
      }

      int totalDeals = HistoryDealsTotal();
      bool success = true;
      
      Print("开始处理历史交易，总交易数: ", totalDeals);
      for(int i = 1; i < totalDeals; i++)
      {
         ulong dealTicket = HistoryDealGetTicket(i);
         string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
         double volume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
         double price = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
         double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT); // 获取实际利润
         long positionId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
         datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
         long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY); // 获取deal_entry值
         
         Print("处理交易 - 索引: ", i, ", DealTicket: ", dealTicket, ", PositionId: ", positionId, ", DealEntry: ", dealEntry);
         
         string dealType = (HistoryDealGetInteger(dealTicket, DEAL_TYPE) == DEAL_TYPE_BUY) ? "BUY" : "SELL";
         
         // 获取实际出场价（对于入场交易为0，对于出场交易为实际价格）
         double exitPrice = 0.0;
         if (dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_OUT_BY)
         {
            exitPrice = price;
         }
         else
         {
            exitPrice = 0.0; // 确保入场交易的出场价为0
         }
         
         // 获取止损和止盈价格 - 直接从交易记录中获取预设值
         double sl = HistoryDealGetDouble(dealTicket, DEAL_SL);
         double tp = HistoryDealGetDouble(dealTicket, DEAL_TP);        
        
         // 将deal_entry值转换为字符串
         string dealEntryStr = "";
         switch(dealEntry)
         {
            case DEAL_ENTRY_IN:
               dealEntryStr = "IN";
               break;
            case DEAL_ENTRY_OUT:
               dealEntryStr = "OUT";
               break;
            case DEAL_ENTRY_INOUT:
               dealEntryStr = "INOUT";
               break;
            case DEAL_ENTRY_OUT_BY:
               dealEntryStr = "OUT_BY";
               break;
            default:
               dealEntryStr = "UNKNOWN";
               break;
         }
         
         // 添加调试信息
         Print("处理历史交易 - PositionId: ", positionId, ", DealEntry: ", dealEntry, ", DealEntryStr: ", dealEntryStr);
         
         // 根据deal_entry值决定操作类型
         if(dealEntry == DEAL_ENTRY_IN)
         {
            // 只记录到CSV文件（记录入场交易），不执行MySQL操作
            if(m_csvLogger != NULL)
            {
               m_csvLogger.LogEntry("TRADE", symbol, dealType, volume, price, sl, tp, 
                                  dealTime, dealTicket, positionId, 0, 
                                  "增量同步", "Trade executed successfully", 0, dealEntryStr);
            }
         }
         else if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_OUT_BY)
         {
            // 同时更新CSV文件中的记录，SimpleCSVLogger会自动写入MySQL
            if(m_csvLogger != NULL)
            {
               if(!m_csvLogger.LogExit(positionId, exitPrice, profit, dealTime, dealEntryStr, "增量同步"))
               {
                  Print("CSVLogger: 更新记录失败 - trade_orders.csv, 错误: ", GetLastError());
                  success = false;
               }
            }

         }
         else
         {
            // 对于其他类型的交易，记录警告信息
            Print("未知的deal_entry类型: ", dealEntry, " PositionId: ", positionId);
         }
      }
      
      return success;
   }
   
  
};