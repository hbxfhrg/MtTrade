#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Trade/OrderInfo.mqh>
#include <Trade/HistoryOrderInfo.mqh>
#include <Trade/PositionInfo.mqh>

class COrderMonitor
{
private:
   ulong m_lastOrderTicket;
   datetime m_lastCheckTime;
   string m_eaName;
   string m_filename;
   
   // 文件句柄
   int m_fileHandle;
   
   // 补偿机制相关
   ulong m_lastCompensationCheckTime;
   uint m_compensationInterval; // 补偿检查间隔（秒）
   
public:
   COrderMonitor(string eaName, string filename = "", uint compensationInterval = 300)
   : m_lastOrderTicket(0),
     m_lastCheckTime(0),
     m_eaName(eaName),
     m_filename(filename == "" ? eaName + "_order_log.csv" : filename),
     m_fileHandle(INVALID_HANDLE),
     m_lastCompensationCheckTime(0),
     m_compensationInterval(compensationInterval)
   {
      // 初始化CSV文件头
      InitializeCSV();
   }
   
   ~COrderMonitor()
   {
      if(m_fileHandle != INVALID_HANDLE)
      {
         FileClose(m_fileHandle);
      }
   }
   
   // EA初始化时调用，执行补偿检查
   void OnInit()
   {
      // 执行一次完整的补偿检查
      PerformCompensationCheck();
      m_lastCompensationCheckTime = TimeCurrent();
   }
   
   // 交易事件处理函数（应该在EA的OnTrade事件中调用）
   void OnTrade()
   {
      // 检查挂单状态变化
      COrderInfo orderInfo;
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         if(orderInfo.SelectByIndex(i) && orderInfo.Comment() == m_eaName)
         {
            CheckOrderStatus(orderInfo);
         }
      }
      
      // 检查历史订单（新完成的订单）
      CHistoryOrderInfo historyOrder;
      for(int i = HistoryOrdersTotal() - 1; i >= 0; i--)
      {
         if(historyOrder.SelectByIndex(i) && historyOrder.Comment() == m_eaName)
         {
            // 只检查最近的历史订单（避免重复记录）
            if(historyOrder.TimeDone() > m_lastCheckTime)
            {
               CheckHistoryOrderStatus(historyOrder);
            }
         }
      }
      
      // 检查持仓状态变化
      CPositionInfo positionInfo;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(positionInfo.SelectByIndex(i) && positionInfo.Comment() == m_eaName)
         {
            CheckPositionStatus(positionInfo);
         }
      }
      
      m_lastCheckTime = TimeCurrent();
      
      // 定期执行补偿检查
      if(TimeCurrent() - m_lastCompensationCheckTime >= m_compensationInterval)
      {
         PerformCompensationCheck();
         m_lastCompensationCheckTime = TimeCurrent();
      }
   }
   
   // 补偿检查机制 - 全量检查所有订单状态
   void PerformCompensationCheck()
   {
      // 检查所有当前挂单
      COrderInfo orderInfo;
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         if(orderInfo.SelectByIndex(i) && orderInfo.Comment() == m_eaName)
         {
            // 记录所有当前挂单（即使状态未变化）
            string orderTypeStr = GetOrderTypeString(orderInfo.OrderType());
            LogOrderEvent("COMPENSATION_ORDER", orderInfo.Symbol(), orderTypeStr,
                        orderInfo.VolumeInitial(), orderInfo.PriceOpen(),
                        orderInfo.StopLoss(), orderInfo.TakeProfit(),
                        orderInfo.TimeExpiration(), orderInfo.Ticket(),
                        orderInfo.Comment(), "Active order (compensation)", 0);
         }
      }
      
      // 检查最近的历史订单（过去1小时内）
      CHistoryOrderInfo historyOrder;
      datetime oneHourAgo = TimeCurrent() - 3600;
      for(int i = HistoryOrdersTotal() - 1; i >= 0; i--)
      {
         if(historyOrder.SelectByIndex(i) && historyOrder.Comment() == m_eaName)
         {
            // 检查最近1小时内的历史订单
            if(historyOrder.TimeDone() > oneHourAgo)
            {
               string orderTypeStr = GetOrderTypeString(historyOrder.OrderType());
               string result = "Completed";
               
               // 根据订单状态设置结果描述
               if(historyOrder.State() == ORDER_STATE_FILLED)
                  result = "Filled";
               else if(historyOrder.State() == ORDER_STATE_CANCELED)
                  result = "Canceled";
               else if(historyOrder.State() == ORDER_STATE_EXPIRED)
                  result = "Expired";
               else if(historyOrder.State() == ORDER_STATE_REJECTED)
                  result = "Rejected";
               
               // 记录历史订单状态（补偿检查）
               LogOrderEvent("COMPENSATION_HISTORY", historyOrder.Symbol(), orderTypeStr,
                           historyOrder.VolumeInitial(), historyOrder.PriceOpen(),
                           historyOrder.StopLoss(), historyOrder.TakeProfit(),
                           historyOrder.TimeExpiration(), historyOrder.Ticket(),
                           historyOrder.Comment(), result + " (compensation)", 0);
            }
         }
      }
      
      // 检查所有当前持仓
      CPositionInfo positionInfo;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(positionInfo.SelectByIndex(i) && positionInfo.Comment() == m_eaName)
         {
            string posTypeStr = positionInfo.PositionType() == POSITION_TYPE_BUY ? "BUY" : "SELL";
            // 记录所有当前持仓（补偿检查）
            LogOrderEvent("COMPENSATION_POSITION", positionInfo.Symbol(), posTypeStr,
                        positionInfo.Volume(), positionInfo.PriceOpen(),
                        positionInfo.StopLoss(), positionInfo.TakeProfit(),
                        0, positionInfo.Ticket(),
                        "Active position", "Position active (compensation)", 0);
         }
      }
   }
   
   void CheckOrderStatus(COrderInfo &orderInfo)
   {
      // 只监控当前EA的订单
      if(orderInfo.Comment() != m_eaName)
         return;
         
      // 检查订单状态变化
      if(orderInfo.Ticket() != m_lastOrderTicket)
      {
         string orderTypeStr = GetOrderTypeString(orderInfo.OrderType());
         
         // 记录订单状态
         LogOrderEvent("ORDER_STATUS", orderInfo.Symbol(), orderTypeStr,
                     orderInfo.VolumeInitial(), orderInfo.PriceOpen(),
                     orderInfo.StopLoss(), orderInfo.TakeProfit(),
                     orderInfo.TimeExpiration(), orderInfo.Ticket(),
                     orderInfo.Comment(), "Order active", 0);
         
         m_lastOrderTicket = orderInfo.Ticket();
      }
   }
   
   void CheckHistoryOrderStatus(CHistoryOrderInfo &historyOrder)
   {
      // 只监控当前EA的历史订单
      if(historyOrder.Comment() != m_eaName)
         return;
         
      string orderTypeStr = GetOrderTypeString(historyOrder.OrderType());
      string result = "Completed";
      
      // 根据订单状态设置结果描述
      if(historyOrder.State() == ORDER_STATE_FILLED)
         result = "Filled";
      else if(historyOrder.State() == ORDER_STATE_CANCELED)
         result = "Canceled";
      else if(historyOrder.State() == ORDER_STATE_EXPIRED)
         result = "Expired";
      else if(historyOrder.State() == ORDER_STATE_REJECTED)
         result = "Rejected";
      
      // 记录历史订单状态
      LogOrderEvent("HISTORY_ORDER", historyOrder.Symbol(), orderTypeStr,
                  historyOrder.VolumeInitial(), historyOrder.PriceOpen(),
                  historyOrder.StopLoss(), historyOrder.TakeProfit(),
                  historyOrder.TimeExpiration(), historyOrder.Ticket(),
                  historyOrder.Comment(), result, 0);
   }
   
   void CheckPositionStatus(CPositionInfo &positionInfo)
   {
      // 只监控当前EA的持仓
      if(positionInfo.Comment() != m_eaName)
         return;
         
      string posTypeStr = positionInfo.PositionType() == POSITION_TYPE_BUY ? "BUY" : "SELL";
      
      // 记录持仓状态
      LogOrderEvent("POSITION_STATUS", positionInfo.Symbol(), posTypeStr,
                  positionInfo.Volume(), positionInfo.PriceOpen(),
                  positionInfo.StopLoss(), positionInfo.TakeProfit(),
                  0, positionInfo.Ticket(),
                  "Active position", "Position active", 0);
   }
   
   string GetOrderTypeString(ENUM_ORDER_TYPE orderType)
   {
      switch(orderType)
      {
         case ORDER_TYPE_BUY: return "BUY";
         case ORDER_TYPE_SELL: return "SELL";
         case ORDER_TYPE_BUY_LIMIT: return "BUY_LIMIT";
         case ORDER_TYPE_SELL_LIMIT: return "SELL_LIMIT";
         case ORDER_TYPE_BUY_STOP: return "BUY_STOP";
         case ORDER_TYPE_SELL_STOP: return "SELL_STOP";
         case ORDER_TYPE_BUY_STOP_LIMIT: return "BUY_STOP_LIMIT";
         case ORDER_TYPE_SELL_STOP_LIMIT: return "SELL_STOP_LIMIT";
         default: return "UNKNOWN";
      }
   }
   
private:
   // 初始化CSV文件
   void InitializeCSV()
   {
      // 检查文件是否存在，如果不存在则创建并写入表头
      if(FileIsExist(m_filename, FILE_COMMON))
         return;
         
      m_fileHandle = FileOpen(m_filename, FILE_WRITE|FILE_CSV|FILE_COMMON, ",");
      if(m_fileHandle != INVALID_HANDLE)
      {
         FileWrite(m_fileHandle, "EventType", "Symbol", "OrderType", "Volume", "Price", 
                  "StopLoss", "TakeProfit", "Expiration", "Ticket", "Comment", 
                  "Result", "ErrorCode", "Timestamp");
         FileClose(m_fileHandle);
         m_fileHandle = INVALID_HANDLE;
      }
   }
   
   // 记录订单事件到CSV
   void LogOrderEvent(string eventType, string symbol, string orderType, 
                     double volume, double price, double sl, double tp,
                     datetime expiration, ulong ticket, string comment, 
                     string result, int errorCode)
   {
      m_fileHandle = FileOpen(m_filename, FILE_WRITE|FILE_READ|FILE_CSV|FILE_COMMON, ",");
      if(m_fileHandle != INVALID_HANDLE)
      {
         FileSeek(m_fileHandle, 0, SEEK_END);
         FileWrite(m_fileHandle, eventType, symbol, orderType, DoubleToString(volume, 2),
                  DoubleToString(price, _Digits), DoubleToString(sl, _Digits),
                  DoubleToString(tp, _Digits), TimeToString(expiration),
                  IntegerToString(ticket), comment, result, IntegerToString(errorCode),
                  TimeToString(TimeCurrent()));
         FileClose(m_fileHandle);
         m_fileHandle = INVALID_HANDLE;
      }
   }
};