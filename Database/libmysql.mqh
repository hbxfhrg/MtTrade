#property copyright "avoitienko"
#property link      "https://login.mql5.com/ru/users/avoitienko"
#property description "MySQL Connect"
#property version   "1.00"

enum mysql_option
  {
   MYSQL_OPT_CONNECT_TIMEOUT,MYSQL_OPT_COMPRESS,MYSQL_OPT_NAMED_PIPE,MYSQL_INIT_COMMAND,
   MYSQL_READ_DEFAULT_FILE,MYSQL_READ_DEFAULT_GROUP,MYSQL_SET_CHARSET_DIR,MYSQL_SET_CHARSET_NAME,
   MYSQL_OPT_LOCAL_INFILE,MYSQL_OPT_PROTOCOL,MYSQL_SHARED_MEMORY_BASE_NAME,MYSQL_OPT_READ_TIMEOUT,
   MYSQL_OPT_WRITE_TIMEOUT,MYSQL_OPT_USE_RESULT,MYSQL_OPT_USE_REMOTE_CONNECTION,MYSQL_OPT_USE_EMBEDDED_CONNECTION,
   MYSQL_OPT_GUESS_CONNECTION,MYSQL_SET_CLIENT_IP,MYSQL_SECURE_AUTH,MYSQL_REPORT_DATA_TRUNCATION,
   MYSQL_OPT_RECONNECT,MYSQL_OPT_SSL_VERIFY_SERVER_CERT,MYSQL_PLUGIN_DIR,MYSQL_DEFAULT_AUTH
  };

#ifdef __MQL5__
#define POINTER      long
#else
#define POINTER      int
#endif
#define MYSQL       POINTER
#define MYSQL_RES   POINTER

#import "libmysql.dll"
MYSQL mysql_init(MYSQL mysql);
void mysql_close(MYSQL mysql);
MYSQL mysql_real_connect(MYSQL mysql,char &host[],
                         char &user[],char &passwd[],
                         char &db[],uint port,char &unix_socket[],
                         ulong clientflag);

POINTER mysql_error(MYSQL mysql);
uint mysql_errno(MYSQL mysql);
int mysql_query(MYSQL mysql,char &stmt_str[]);
int mysql_real_query(MYSQL mysql,char &stmt_str[],ulong length);

MYSQL_RES mysql_store_result(MYSQL mysql);
MYSQL_RES mysql_field_count(MYSQL mysql);
int mysql_num_rows(MYSQL_RES result);
int mysql_fetch_row(MYSQL_RES result);
void mysql_free_result(MYSQL_RES result);

int mysql_options(MYSQL mysql,mysql_option option,char &arg[]);

long mysql_get_server_version(MYSQL mysql);
POINTER mysql_get_host_info(MYSQL mysql);
POINTER mysql_get_server_info(MYSQL mysql);

int mysql_ping(MYSQL mysql);

#import "msvcrt.dll"
int strcpy(char &dst[],POINTER src);
int memcpy(double &dst[],double &src[],int cnt);
int memcpy(int &dst[],int &src[],int cnt);
#import

enum ENUM_MYSQL_STATUS
  {
   STATUS_OK,
   STATUS_NOT_INIT,
   STATUS_NOT_CONNECTED,
   STATUS_BAD_REQUEST
  };

class CMySQL_Connection
{
private:
   MYSQL mysql;
   bool connect;
   string last_error;
   uint last_errno;
   
   void UpdateErrorInfo(uint err=0)
   {
      if(err==0)
      {
         last_errno=mysql_errno(mysql);
         POINTER err_ptr=mysql_error(mysql);
         if(err_ptr!=0)
         {
            char err_buf[256];
            strcpy(err_buf,err_ptr);
            last_error=CharArrayToString(err_buf);
         }
         else
         {
            last_error="Unknown error";
         }
      }
      else
      {
         last_errno=err;
         last_error="Connection failed";
      }
   }
   
public:
   CMySQL_Connection() : mysql(0), connect(false), last_error(""), last_errno(0) {}
   
   bool Init()
   {
      mysql=mysql_init(mysql);
      if(mysql==0)
      {
         last_errno=1;
         last_error="MySQL initialization failed";
         return false;
      }
      return true;
   }
   
   bool Connect(string host, uint port, string db, string user, string passwd, string unix_socket="", ulong client_flag=0)
   {
      if(mysql==0)
      {
         if(!Init()) return false;
      }
      
      // 设置SSL选项以支持MySQL 8.0+ caching_sha2_password认证
      char ssl_enable[] = {1};
      mysql_options(mysql, MYSQL_OPT_SSL_VERIFY_SERVER_CERT, ssl_enable);
      
      char a_host[];
      char a_user[];
      char a_passwd[];
      char a_db[];
      char a_unix_socket[];
      
      StringToCharArray(host,a_host);
      StringToCharArray(user,a_user);
      StringToCharArray(passwd,a_passwd);
      StringToCharArray(db,a_db);
      StringToCharArray(unix_socket,a_unix_socket);
      
      MYSQL res=mysql_real_connect(mysql,a_host,a_user,a_passwd,a_db,port,a_unix_socket,client_flag);
      if(res==0)
      {
         UpdateErrorInfo();
         connect=false;
      }
      else
      {
         UpdateErrorInfo(0);
         connect=true;
      }
      
      return connect;
   }
   
   ENUM_MYSQL_STATUS GetStatus()
   {
      if(mysql==0)
      {
         return(STATUS_NOT_INIT);
      }
      
      if(!connect)
         return(STATUS_NOT_CONNECTED);
      
      if(mysql_ping(mysql)!=0)
         return(STATUS_NOT_CONNECTED);
      
      return(STATUS_OK);
   }
   
   ENUM_MYSQL_STATUS ExecSQL(string sql)
   {
      if(GetStatus()!=STATUS_OK)
         return GetStatus();
      
      char query[];
      StringToCharArray(sql,query);
      
      int res=mysql_real_query(mysql,query,StringLen(sql));
      if(res!=0)
      {
         UpdateErrorInfo();
         return STATUS_BAD_REQUEST;
      }
      
      return STATUS_OK;
   }
   
   string GetErrorDescription() const { return last_error; }
   uint GetLastError() const { return last_errno; }
   
   long GetServerVersion() const 
   {
      if(mysql != 0)
         return mysql_get_server_version(mysql);
      return 0;
   }
   
   void Close()
   {
      if(mysql!=0)
      {
         mysql_close(mysql);
         mysql=0;
         connect=false;
      }
   }
   
   ~CMySQL_Connection()
   {
      Close();
   }
};