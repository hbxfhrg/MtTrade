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
                    "exit_price DOUBLE, " +  // 添加出场价字段
                    "profit DOUBLE, " +      // 实际利润字段
                    "expiry_time VARCHAR(50), " +
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
      
      // 使用DatabaseManager记录订单事件
      string query = StringFormat(
         "INSERT INTO order_logs " +
         "(event_type, symbol, order_type, volume, entry_price, stop_loss, take_profit, exit_price, profit, event_time, " +
         "order_ticket, position_id, magic_number, comment, result, error_code, deal_entry) " +
         "VALUES ('%s', '%s', '%s', %.2f, %.5f, %.5f, %.5f, %.5f, %.2f, FROM_UNIXTIME(%d), %d, %d, %d, '%s', '%s', %d, '%s')",
         eventType, symbol, orderType, volume, entryPrice, stopLoss, takeProfit, exitPrice, actualProfit,
         (int)eventTime, orderTicket, positionId, magicNumber, comment, result, errorCode, dealEntry
      );
      
      return m_dbManager.Execute(query);
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
      
      // 直接使用数据库管理器记录交易
      string query = StringFormat(
         "INSERT INTO order_logs " +
         "(event_type, symbol, order_type, volume, entry_price, stop_loss, take_profit, exit_price, profit, event_time, " +
         "order_ticket, position_id, magic_number, comment, result, error_code, deal_entry) " +
         "VALUES ('%s', '%s', '%s', %.2f, %.5f, %.5f, %.5f, %.5f, %.2f, FROM_UNIXTIME(%d), %d, %d, %d, '%s', '%s', %d, '%s')",
         "TRADE", symbol, type, volume, price, sl, tp, exitPrice, actualProfit,
         (int)time, orderTicket, positionId, 0, comment, "Trade executed successfully", 0, dealEntry
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
         double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT); // 获取实际利润
         long positionId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
         datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
         long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY); // 获取deal_entry值
         
         string dealType = (HistoryDealGetInteger(dealTicket, DEAL_TYPE) == DEAL_TYPE_BUY) ? "BUY" : "SELL";
         
         // 获取实际出场价（对于入场交易为0，对于出场交易为实际价格）
         double exitPrice = 0.0;
         if (dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_OUT_BY)
         {
            exitPrice = price;
         }
         
         // 获取止损和止盈价格
         double sl = 0, tp = 0;
         // 首先尝试通过positionId获取持仓信息
         if(positionId > 0 && PositionSelectByTicket(positionId))
         {
            sl = PositionGetDouble(POSITION_SL);
            tp = PositionGetDouble(POSITION_TP);
         }
         else
         {
            // 如果通过positionId无法获取，尝试通过symbol和订单类型获取
            long dealType = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
            
            // 尝试选择对应的持仓
            if(PositionSelect(symbol))
            {
               // 检查持仓类型是否匹配
               long positionType = PositionGetInteger(POSITION_TYPE);
               if((dealType == DEAL_TYPE_BUY && positionType == POSITION_TYPE_BUY) ||
                  (dealType == DEAL_TYPE_SELL && positionType == POSITION_TYPE_SELL))
               {
                  sl = PositionGetDouble(POSITION_SL);
                  tp = PositionGetDouble(POSITION_TP);
               }
            }
            else
            {
               // 如果通过symbol也无法获取持仓信息，尝试从订单历史中获取
               // 这种情况可能发生在持仓已关闭后
               long orderTicket = HistoryDealGetInteger(dealTicket, DEAL_ORDER);
               if(orderTicket > 0)
               {
                  // 尝试获取订单信息
                  if(OrderSelect(orderTicket))
                  {
                     sl = OrderGetDouble(ORDER_SL);
                     tp = OrderGetDouble(ORDER_TP);
                  }
               }
            }
         }
         
         // 如果仍然无法获取止损和止盈价格，尝试从交易记录中获取
         if(sl == 0 && tp == 0)
         {
            // 从交易记录的注释或其他字段中尝试获取信息
            // 这里可以根据实际需求添加更多获取止损止盈价格的方法
         }
         
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
         
         string query = StringFormat(
            "INSERT INTO order_logs " +
            "(event_type, symbol, order_type, volume, entry_price, stop_loss, take_profit, exit_price, profit, event_time, " +
            "order_ticket, position_id, magic_number, comment, result, error_code, deal_entry) " +
            "VALUES ('%s', '%s', '%s', %.2f, %.5f, %.5f, %.5f, %.5f, %.2f, FROM_UNIXTIME(%d), %d, %d, %d, '%s', '%s', %d, '%s')",
            "TRADE", symbol, dealType, volume, price, sl, tp, exitPrice, profit,
            (int)dealTime, dealTicket, positionId, 0, "增量同步", "Trade executed successfully", 0, dealEntryStr
         );
         
         if(!m_dbManager.Execute(query))
         {
            success = false;
         }
      }
      
      return success;
   }
   
  
};