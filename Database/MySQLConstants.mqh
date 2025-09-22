//+------------------------------------------------------------------+
//| MySQLConstants.mqh                                               |
//|                                                                  |
//| 这个文件定义了MySQL标准常量                                      |
//|                                                                  |
//+------------------------------------------------------------------+

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