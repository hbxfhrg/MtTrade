//+------------------------------------------------------------------+
//| CMySQLCursor.mqh                                                 |
//|                                                                  |
//| 这个文件定义了用于处理MySQL数据库游标操作的CMySQLCursor类        |
//|                                                                  |
//+------------------------------------------------------------------+
#import "MQLMySQL.dll"
    // 获取MySqlCursor.dll库的版本
    string cMySqlVersion ();
    
    // 获取连接的最后错误编号
    int    cGetMySqlErrorNumber(int pConnection);
    
    // 获取游标的最后错误编号
    int    cGetCursorErrorNumber(int pCursorID);
    
    // 获取连接的最后错误描述
    string cGetMySqlErrorDescription(int pConnection);
    
    // 获取游标的最后错误描述
    string cGetCursorErrorDescription(int pCursorID);
    
    // 建立到MySQL数据库服务器的连接并返回连接标识符
    int    cMySqlConnect(string pHost,       // 主机名
                         string pUser,       // 用户名
                         string pPassword,   // 密码
                         string pDatabase,   // 数据库名
                         int    pPort,       // 端口
                         string pSocket,     // Unix套接字
                         int    pClientFlag);// 客户端标志
                         
    // 关闭数据库连接
    void   cMySqlDisconnect(int pConnection);   // pConnection - 数据库标识符（指向结构的指针）
    
    // 执行非SELECT语句
    bool   cMySqlExecute(int    pConnection, // pConnection - 数据库标识符（指向结构的指针）
                         string pQuery);     // pQuery      - 要执行的SQL查询
                         
    // 基于SELECT语句创建游标并返回游标标识符
    int    cMySqlCursorOpen(int    pConnection, // pConnection - 数据库标识符（指向结构的指针）
                            string pQuery);     // pQuery      - 要执行的SELECT语句
                            
    // 关闭已打开的游标
    void   cMySqlCursorClose(int pCursorID);     // pCursorID  - 内部游标标识符
    
    // 返回游标选择的行数
    int    cMySqlCursorRows(int pCursorID);     // pCursorID  - 内部游标标识符
    
    // 从游标获取下一行到当前行缓冲区
    bool   cMySqlCursorFetchRow(int pCursorID);     // pCursorID  - 内部游标标识符
    
    // 从游标获取的当前行中检索值
    string cMySqlGetRowField(int pCursorID,   // pCursorID  - 内部游标标识符
                             int pField);     // pField     - SELECT子句中的字段编号（从0,1,2...开始）
                             
    // 返回上次DML操作（INSERT/UPDATE/DELETE）影响的行数
    int cMySqlRowsAffected(int pConnection);
    
    // 从标准INI文件中读取并返回键值
    string ReadIni(string pFileName,   // INI文件名
                   string pSection,    // 节名称
                   string pKey);       // 键名称
#import

//+------------------------------------------------------------------+
//| CMySQLCursor类                                                   |
//| 用于处理MySQL数据库游标操作                                      |
//+------------------------------------------------------------------+
class CMySQLCursor
{
private:
    int    CursorID;              // 游标ID
    int    ConnectID;             // 连接ID
    int    CursorErrorNumber;     // 游标错误编号
    string CursorErrorDescription;// 游标错误描述
    bool   SQLTrace;              // SQL跟踪开关
    
    // 在任何函数开始其功能之前清除错误缓冲区
    void ClearErrors()
    {
        CursorErrorNumber = 0;
        CursorErrorDescription = "无错误。";
    }
    
public:
    // 构造函数
    CMySQLCursor(void)
    {
        ConnectID = -1;
        CursorID = -1;
        ClearErrors();
        SQLTrace = false;
    }
    
    // 析构函数
    ~CMySQLCursor(void)
    {
        // 析构函数
        if (CursorID >= 0) Close();
        ClearErrors();
    }
    
    // 基于SELECT语句创建游标
    // 返回值 - 成功时为true
    //        - 失败时为false，要获取错误信息，请调用LastError()和/或LastErrorMessage()
    bool Open(CMySQL *pConnection, string pQuery)
    {
        SQLTrace = pConnection.GetTrace();
        ConnectID = pConnection.GetConnectID();
        if (SQLTrace) Print(MQLMYSQL_TRACER, "数据库ID#", ConnectID, ", 查询:", pQuery);
        ClearErrors();
        
        CursorID = cMySqlCursorOpen(ConnectID, pQuery);
        if (CursorID == -1)
        {
            CursorErrorNumber = cGetMySqlErrorNumber(ConnectID);
            CursorErrorDescription = cGetMySqlErrorDescription(ConnectID);
            if (SQLTrace) Print(MQLMYSQL_TRACER, "查询>", CursorErrorNumber, ": ", CursorErrorDescription);
            return (false);
        }
        return (true);
    }
    
    // 关闭已打开的游标
    void Close(void)
    {
        ClearErrors();
        // if (CursorID == -1) return; // 无活动游标
        
        cMySqlCursorClose(CursorID);
        CursorErrorNumber = cGetCursorErrorNumber(CursorID);
        CursorErrorDescription = cGetCursorErrorDescription(CursorID);
        if (CursorErrorNumber != 0)
        {
            if (SQLTrace) Print(MQLMYSQL_TRACER, "游标 #", CursorID, " 关闭错误: ", CursorErrorNumber, ": ", CursorErrorDescription);
        }
        else 
        {
            if (SQLTrace) Print(MQLMYSQL_TRACER, "游标 #", CursorID, " 已关闭");
            CursorID = -1;
        }
    }
    
    // 返回游标选择的行数
    int Rows(void)
    {
        int result;
        result = cMySqlCursorRows(CursorID);
        CursorErrorNumber = cGetCursorErrorNumber(CursorID);
        CursorErrorDescription = cGetCursorErrorDescription(CursorID);
        if (SQLTrace) Print(MQLMYSQL_TRACER, "游标 #", CursorID, ", 行数: ", result);
        return (result);
    }
    
    // 从游标获取下一行到当前行缓冲区
    // 成功时返回true，否则返回false
    bool Fetch(void)
    {
        bool result;
        result = cMySqlCursorFetchRow(CursorID);
        CursorErrorNumber = cGetCursorErrorNumber(CursorID);
        CursorErrorDescription = cGetCursorErrorDescription(CursorID);
        if (SQLTrace && CursorErrorNumber != 0)
        {
            Print(MQLMYSQL_TRACER, "游标 #", CursorID, " 获取错误: ", CursorErrorNumber, ": ", CursorErrorDescription);
        }
        return (result); 
    }
    
    // 从游标获取的当前行中检索值
    // 字段从0开始
    string FieldAsString(int pField)
    {
        string result;
        result = cMySqlGetRowField(CursorID, pField);
        CursorErrorNumber = cGetCursorErrorNumber(CursorID);
        CursorErrorDescription = cGetCursorErrorDescription(CursorID);
        return (result);
    }
    
    int FieldAsInt(int pField)
    {
        return ((int)StringToInteger(FieldAsString(pField)));
    }
    
    double FieldAsDouble(int pField)
    {
        return (StringToDouble(FieldAsString(pField)));
    }
    
    datetime FieldAsDatetime(int pField)
    {
        string x = FieldAsString(pField);
        StringReplace(x, "-", ".");
        return (StringToTime(x));
    }
    
    int LastError(void)
    {
        return CursorErrorNumber;
    }
    
    string LastErrorMessage(void)
    {
        return CursorErrorDescription;
    }
};