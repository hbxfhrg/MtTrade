//+------------------------------------------------------------------+
//| CMySQL.mqh                                                       |
//|                                                                  |
//| 这个文件定义了用于连接和操作MySQL数据库的CMySQL类                |
//|                                                                  |
//+------------------------------------------------------------------+
// 注意：在策略测试器中不支持DLL导入，因此我们使用条件编译来避免错误

#ifndef __MQL5__
// 只在非测试环境中导入DLL
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
#endif

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
#ifndef __MQL5__
        return(cMySqlVersion());
#else
        return("DLL not available in strategy tester");
#endif
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
#ifndef __MQL5__
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
#else
        // 在策略测试器中返回false，因为DLL不可用
        MySqlErrorNumber = -9;
        MySqlErrorDescription = "DLL在策略测试器中不可用。";
        return (false);
#endif
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
    
    // 执行非SELECT语句
    bool Execute(string pQuery)
    {
#ifndef __MQL5__
        bool result;
        ClearErrors();
        
        if (ConnectID < 0)
        {
            MySqlErrorNumber = -1;
            MySqlErrorDescription = "未连接到数据库。";
            if (SQLTrace) Print(MQLMYSQL_TRACER, "执行错误 #", MySqlErrorNumber, " ", MySqlErrorDescription);
            return (false);
        }
        
        result = cMySqlExecute(ConnectID, pQuery);
        if (!result)
        {
            MySqlErrorNumber = cGetMySqlErrorNumber(ConnectID);
            MySqlErrorDescription = cGetMySqlErrorDescription(ConnectID);
            if (SQLTrace) Print(MQLMYSQL_TRACER, "执行错误 #", MySqlErrorNumber, " ", MySqlErrorDescription, " 查询: ", pQuery);
        }
        else
        {
            if (SQLTrace) Print(MQLMYSQL_TRACER, "查询执行成功: ", pQuery);
        }
        
        return (result);
#else
        // 在策略测试器中返回false，因为DLL不可用
        MySqlErrorNumber = -9;
        MySqlErrorDescription = "DLL在策略测试器中不可用。";
        return (false);
#endif
    }
    
    // 断开数据库连接
    void Disconnect(void)
    {
#ifndef __MQL5__
        if (ConnectID >= 0)
        {
            cMySqlDisconnect(ConnectID);
            if (SQLTrace) Print(MQLMYSQL_TRACER, "断开数据库连接。数据库ID#", ConnectID);
            ConnectID = -1;
        }
#else
        ConnectID = -1;
#endif
    }
    
    // 获取最后错误编号
    int LastError(void)
    {
        return (MySqlErrorNumber);
    }
    
    // 获取最后错误描述
    string LastErrorMessage(void)
    {
        return (MySqlErrorDescription);
    }
};