//+------------------------------------------------------------------+
//| MQLMySQLClass.mqh                                                |
//|                                                                  |
//| 这个文件定义了用于连接和操作MySQL数据库的类                      |
//|                                                                  |
//+------------------------------------------------------------------+
#define MQLMYSQL_TRACER "跟踪: " // 跟踪消息前缀
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
//| CMySQL类                                                         |
//| 用于处理MySQL数据库连接和基本操作                                |
//+------------------------------------------------------------------+
class CMySQL
{
private:
    bool     SQLTrace;               // SQL跟踪开关
    datetime MySqlLastConnect;       // 最后连接时间
    int      MySqlErrorNumber;       // 最近的MySQL错误编号
    string   MySqlErrorDescription;  // 最近的MySQL错误描述
    int      ConnectID;              // 数据库连接ID
    bool     vCredentialsSet;        // 数据库凭证是否已设置
    string   vHost;                  // 主机
    string   vUser;                  // 用户名
    string   vPassword;              // 密码
    string   vDatabase;              // 数据库名
    int      vPort;                  // 端口
    string   vSocket;                // 套接字
    int      vClientFlag;            // 客户端标志
    
    // 在任何函数开始其功能之前清除错误缓冲区
    void ClearErrors()
    {
        MySqlErrorNumber = 0;
        MySqlErrorDescription = "无错误。";
    }
    
public:
    // 构造函数
    CMySQL(void)
    {
        SQLTrace = false;          // 默认禁用跟踪
        MySqlLastConnect = 0;
        vCredentialsSet = false;   // 默认未设置数据库凭证
        ConnectID = -1;            // 默认未连接数据库
        ClearErrors();
    }
    
    // 析构函数
    ~CMySQL(void)
    {
        SQLTrace = false;          // 默认禁用跟踪
        MySqlLastConnect = 0;
        vCredentialsSet = false;   // 默认未设置数据库凭证
        if (ConnectID >= 0) Disconnect();
        ClearErrors();
    }
    
    // 设置跟踪状态
    // pState = true 用于调试
    //          false 用于发布
    void SetTrace(bool pState)
    {
        SQLTrace = pState;
    }
    
    // 返回MQLMySQL库的版本
    string DllVersion()
    {
        return(cMySqlVersion());
    }
    
    // 接口函数Connect - 使用参数连接到MySQL数据库：
    // pHost       - DNS名称或IP地址
    // pUser       - 数据库用户（例如root）
    // pPassword   - 用户密码（例如Zok1LmVdx）
    // pDatabase   - 数据库名称（例如metatrader）
    // pPort       - 数据库监听器的TCP/IP端口（例如3306）
    // pSocket     - unix套接字（用于套接字或命名管道）
    // pClientFlag - 功能标志的组合（通常为0）
    // ------------------------------------------------------------------------------------
    // 返回值      - 数据库连接标识符
    //               如果返回值为0，请检查MySqlErrorNumber和MySqlErrorDescription
    bool Connect(string pHost, string pUser, string pPassword, string pDatabase, int pPort, string pSocket, int pClientFlag)
    {
        SetCredentials(pHost, pUser, pPassword, pDatabase, pPort, pSocket, pClientFlag);
        return (Connect());
    }
    
    // 接口函数Connect - 使用内部凭证（已加载或设置）连接到MySQL数据库
    bool Connect(void)
    {
        int connection;
        ClearErrors();
        
        if (!vCredentialsSet)
        {
            MySqlErrorNumber = -8;
            MySqlErrorDescription = "未设置数据库凭证。";
            if (SQLTrace) Print(MQLMYSQL_TRACER, "连接错误 #", MySqlErrorNumber, " ", MySqlErrorDescription);
            return (false);
        }
        
        if (ConnectID >= 0)
        {
            // 连接已存在
            MySqlErrorNumber = -7;
            MySqlErrorDescription = "连接已存在。";
            if (SQLTrace) Print(MQLMYSQL_TRACER, "连接错误 #", MySqlErrorNumber, " ", MySqlErrorDescription);
            return (false);
        }
        
        connection = cMySqlConnect(vHost, vUser, vPassword, vDatabase, vPort, vSocket, vClientFlag);

        if (SQLTrace) Print(MQLMYSQL_TRACER, "正在连接到 主机=", vHost, ", 用户=", vUser, ", 数据库=", vDatabase, " 数据库ID#", connection);

        if (connection == -1)
        {
            MySqlErrorNumber = cGetMySqlErrorNumber(-1);
            MySqlErrorDescription = cGetMySqlErrorDescription(-1);
            if (SQLTrace) Print(MQLMYSQL_TRACER, "连接错误 #", MySqlErrorNumber, " ", MySqlErrorDescription);
            return (false);
        }

        MySqlLastConnect = TimeCurrent();
        if (SQLTrace) Print(MQLMYSQL_TRACER, "已连接! 数据库ID#", connection);
        
        ConnectID = connection;

        // 为连接设置UTF8字符集
        if (!Execute("SET NAMES UTF8"))
        {
            MySqlErrorNumber = cGetMySqlErrorNumber(-1);
            MySqlErrorDescription = cGetMySqlErrorDescription(-1);
            if (SQLTrace) Print(MQLMYSQL_TRACER, "'SET NAMES UTF8' 错误 #", MySqlErrorNumber, " ", MySqlErrorDescription);
        }
        
        return (true);
    }
    
    // 为后续连接设置数据库凭证
    void SetCredentials(string pHost, string pUser, string pPassword, string pDatabase, int pPort, string pSocket, int pClientFlag)
    {
        vHost = pHost;
        vUser = pUser;
        vPassword = pPassword;
        vDatabase = pDatabase;
        vPort = pPort;
        vSocket = pSocket;
        vClientFlag = pClientFlag;
        vCredentialsSet = true;
    }
    
    // 从标准INI文件加载数据库凭证用于后续连接
    // INI文件必须有MYSQL节和键 Host, User, Password, Database, Port, Socket, ClientFlag
    /*
    void LoadCredentials(string p_ini_file)
    {
        // 从INI文件读取数据库凭证
        // vHost = ReadIni(p_ini_file, "MYSQL", "Host");
        // vUser = ReadIni(p_ini_file, "MYSQL", "User");
        // vPassword = ReadIni(p_ini_file, "MYSQL", "Password");
        // vDatabase = ReadIni(p_ini_file, "MYSQL", "Database");
        // vPort     = (int)StringToInteger(ReadIni(p_ini_file, "MYSQL", "Port"));
        // vSocket   = ReadIni(p_ini_file, "MYSQL", "Socket");
        // vClientFlag = (int)StringToInteger(ReadIni(p_ini_file, "MYSQL", "ClientFlag"));  

        // if (SQLTrace) Print (MQLMYSQL_TRACER, "已加载 '", p_ini_file, "'> 主机: ", vHost, ", 用户: ", vUser, ", 数据库: ", vDatabase);
        // vCredentialsSet = true;
    }
    */
    
    // 接口函数Disconnect - 关闭数据库连接
    // 如果未建立连接，则不执行任何操作
    void Disconnect(void)
    {
        ClearErrors();
        if (ConnectID != -1) 
        {
            cMySqlDisconnect(ConnectID);
            if (SQLTrace) Print(MQLMYSQL_TRACER, "数据库ID#", ConnectID, " 已断开连接");
            ConnectID = -1;
        }
    }
    
    // 接口函数Execute - 执行SQL查询（DML/DDL/DCL操作，MySQL命令）
    // pQuery      - SQL查询
    // ------------------------------------------------------
    // 返回值      - true : 执行成功
    //             - false: 出现任何错误（请参见MySqlErrorNumber, MySqlErrorDescription）
    bool Execute(string pQuery)
    {
        ClearErrors();
        if (SQLTrace) Print(MQLMYSQL_TRACER, "数据库ID#", ConnectID, ", 命令:", pQuery);
        if (ConnectID == -1) 
        {
            // 无连接
            MySqlErrorNumber = -2;
            MySqlErrorDescription = "未连接到数据库。";
            if (SQLTrace) Print(MQLMYSQL_TRACER, "命令>", MySqlErrorNumber, ": ", MySqlErrorDescription);
            return (false);
        }

        if (!cMySqlExecute(ConnectID, pQuery))
        {
            MySqlErrorNumber = cGetMySqlErrorNumber(ConnectID);
            MySqlErrorDescription = cGetMySqlErrorDescription(ConnectID);
            if (SQLTrace) Print(MQLMYSQL_TRACER, "命令>", MySqlErrorNumber, ": ", MySqlErrorDescription);
            return (false);
        }
        
        // 添加额外的错误检查，确保没有未处理的结果集
        int errorCode = cGetMySqlErrorNumber(ConnectID);
        if (errorCode != 0)
        {
            MySqlErrorNumber = errorCode;
            MySqlErrorDescription = cGetMySqlErrorDescription(ConnectID);
            if (SQLTrace) Print(MQLMYSQL_TRACER, "命令>", MySqlErrorNumber, ": ", MySqlErrorDescription);
            // 如果是"Commands out of sync"错误(2014)，尝试重新连接
            if (errorCode == 2014)
            {
                if (SQLTrace) Print(MQLMYSQL_TRACER, "检测到命令不同步错误，正在尝试重新连接...");
                Disconnect();
                // 重置连接状态，确保可以重新连接
                ConnectID = -1;
                if (Connect())
                {
                    // 重新连接成功后再次尝试执行查询
                    if (!cMySqlExecute(ConnectID, pQuery))
                    {
                        MySqlErrorNumber = cGetMySqlErrorNumber(ConnectID);
                        MySqlErrorDescription = cGetMySqlErrorDescription(ConnectID);
                        if (SQLTrace) Print(MQLMYSQL_TRACER, "命令>", MySqlErrorNumber, ": ", MySqlErrorDescription);
                        return (false);
                    }
                    return (true);
                }
            }
            return (false);
        }
        
        return (true);
    }
    
    // 返回上次DML操作影响的行数
    int RowsAffected(void)
    {
        return (cMySqlRowsAffected(ConnectID));
    }
    
    // 返回内部连接标识符
    int GetConnectID(void)
    {
        return ConnectID;
    }
    
    bool GetTrace(void)
    {
        return SQLTrace;
    }
    
    int LastError(void) const
    {
        return MySqlErrorNumber;
    }
    
    string LastErrorMessage(void) const
    {
        return MySqlErrorDescription;
    }
};

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

//+------------------------------------------------------------------+
//| MySQL标准定义                                                    |
//+------------------------------------------------------------------+
#define CLIENT_LONG_PASSWORD               1 /* 更安全的新密码 */
#define CLIENT_FOUND_ROWS                  2 /* 找到的行而不是受影响的行 */
#define CLIENT_LONG_FLAG                   4 /* 获取所有列标志 */
#define CLIENT_CONNECT_WITH_DB             8 /* 可以在连接时指定数据库 */
#define CLIENT_NO_SCHEMA                  16 /* 不允许database.table.column */
#define CLIENT_COMPRESS                   32 /* 可以使用压缩协议 */
#define CLIENT_ODBC                       64 /* Odbc客户端 */
#define CLIENT_LOCAL_FILES               128 /* 可以使用LOAD DATA LOCAL */
#define CLIENT_IGNORE_SPACE              256 /* 忽略'('之前的空格 */
#define CLIENT_PROTOCOL_41               512 /* 新4.1协议 */
#define CLIENT_INTERACTIVE              1024 /* 这是一个交互式客户端 */
#define CLIENT_SSL                      2048 /* 握手后切换到SSL */
#define CLIENT_IGNORE_SIGPIPE           4096 /* 忽略sigpipes */
#define CLIENT_TRANSACTIONS             8192 /* 客户端知道事务 */
#define CLIENT_RESERVED                16384 /* 4.1协议的旧标志 */
#define CLIENT_SECURE_CONNECTION       32768 /* 新4.1认证 */
#define CLIENT_MULTI_STATEMENTS        65536 /* 启用/禁用多语句支持 */
#define CLIENT_MULTI_RESULTS          131072 /* 启用/禁用多结果 */
#define CLIENT_PS_MULTI_RESULTS       262144 /* PS协议中的多结果 */