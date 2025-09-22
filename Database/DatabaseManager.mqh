//+------------------------------------------------------------------+
//| DatabaseManager.mqh                                              |
//| 数据库管理器（使用MySQL数据库存储）                              |
//+------------------------------------------------------------------+
#include "CMySQL.mqh"
#include "CMySQLCursor.mqh"

class CDatabaseManager
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
   CDatabaseManager(string host, string username, string password, string database, int port) :
      m_host(host), m_port(port), m_database(database), m_user(username), m_password(password),
      m_initialized(false)
   {
      // 只进行连接参数的赋值，不立即调用连接动作
      Print("数据库管理器初始化完成（连接参数已设置）");
   }

   // 初始化数据库连接
   bool Initialize(bool isReconnect = false)
   {
      // 如果已经连接且不是重新连接，则直接返回true
      if (m_initialized && !isReconnect)
      {
         return true;
      }
      
      if(!m_mysql.Connect(m_host, m_user, m_password, m_database, m_port, "", 0))
      {
         Print("MySQL连接失败: ", m_mysql.LastErrorMessage());
         return false;
      }
      
      m_initialized = true;
      return true;
   }
   
   // 断开数据库连接
   void Disconnect()
   {
      if (m_initialized)
      {
         m_mysql.Disconnect();
         m_initialized = false;
      }
   }
   
   // 执行类SQL语句（INSERT, UPDATE, DELETE等）
   bool Execute(string query)
   {
      // 打开连接
      if (!Initialize())
      {
         Print("数据库连接失败");
         return false;
      }
      
      bool result = true;
      if (!m_mysql.Execute(query))
      {
         Print("执行SQL语句失败: ", m_mysql.LastErrorMessage());
         // 检查是否是"Commands out of sync"错误(2014)
         if (m_mysql.LastError() == 2014)
         {
            Print("检测到命令不同步错误，正在尝试重新连接...");
            Disconnect();
            if (Initialize(true))
            {
               // 重新连接成功后再次尝试执行查询
               if (!m_mysql.Execute(query))
               {
                  Print("重新执行查询失败: ", m_mysql.LastErrorMessage());
                  result = false;
               }
               else
               {
                  result = true;
               }
            }
            else
            {
               result = false;
            }
         }
         else
         {
            result = false;
         }
      }
      else
      {
         result = true;
      }
      
      // 执行完成后关闭连接
      Disconnect();
      
      return result;
   }

   // 查询类SQL语句（SELECT等）并返回结果
   string QuerySingleValue(string query)
   {
      // 打开连接
      if (!Initialize())
      {
         Print("数据库连接失败");
         return "";
      }
      
      // 创建游标对象
      CMySQLCursor cursor;
      
      // 打开游标执行查询
      if (!cursor.Open(&m_mysql, query))
      {
         Print("执行查询语句失败: ", cursor.LastErrorMessage());
         Disconnect();
         return "";
      }
      
      string result = "";
      // 获取查询结果
      if (cursor.Rows() > 0 && cursor.Fetch())
      {
         result = cursor.FieldAsString(0);
      }
      
      // 关闭游标
      cursor.Close();
      
      // 执行完成后关闭连接
      Disconnect();
      
      return result;
   }
   
   // 获取最后错误信息
   string GetLastError() const
   {
      return m_mysql.LastErrorMessage();
   }
   
   // 获取最后错误代码
   int LastError() const
   {
      return m_mysql.LastError();
   }
};