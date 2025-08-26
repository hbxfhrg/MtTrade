//+------------------------------------------------------------------+
//|                                                 ConfigManager.mqh |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

//+------------------------------------------------------------------+
//| 配置管理类 - 用于保存和加载指标配置                                |
//+------------------------------------------------------------------+
class CConfigManager
  {
private:
   static string    m_configFileName;   // 配置文件名
   static string    m_symbolName;       // 品种名称
   
   // 创建配置文件路径
   static string    GetConfigFilePath()
     {
      // 直接在当前目录下创建配置文件
      string path = "";
      
      return path + m_configFileName;
     }
     
   // 将配置写入文件
   static bool WriteConfigToFile(string content)
     {
      string filePath = GetConfigFilePath();
      
      // 打开文件进行写入
      int fileHandle = FileOpen(filePath, FILE_WRITE|FILE_TXT);
      if(fileHandle == INVALID_HANDLE)
        {
         return false;
        }
      
      // 写入内容
      FileWriteString(fileHandle, content);
      
      // 关闭文件
      FileClose(fileHandle);
      
      return true;
     }
     
   // 从文件读取配置
   static string ReadConfigFromFile()
     {
      string filePath = GetConfigFilePath();
      
      // 检查文件是否存在
      if(!FileIsExist(filePath))
        {
         return "";
        }
      
      // 打开文件进行读取
      int fileHandle = FileOpen(filePath, FILE_READ|FILE_TXT);
      if(fileHandle == INVALID_HANDLE)
        {
         return "";
        }
      
      // 获取文件大小
      ulong fileSize = FileSize(fileHandle);
      
      // 读取整个文件内容
      string content = "";
      if(fileSize > 0)
        {
         content = FileReadString(fileHandle, (int)fileSize);
        }
      
      // 关闭文件
      FileClose(fileHandle);
      
      return content;
     }
     
public:
   // 初始化配置管理器
   static void Init(string symbolName)
     {
      m_symbolName = symbolName;
      m_configFileName = "MyZigzag_" + symbolName + ".cfg";
     }
     
   // 保存所有配置
   static bool SaveAllConfig(int depth, int deviation, int backstep, 
                           bool showLabels, color labelColor,
                           bool show5M, bool show4H, color label4HColor,
                           int cacheTimeout, int maxBarsH1,
                           bool showInfoPanel, color infoPanelColor, color infoPanelBgColor,
                           bool showPenetratedPoints)
     {
      // 创建JSON格式的配置内容
      string content = "{\n";
      content += "  \"Symbol\": \"" + m_symbolName + "\",\n";
      content += "  \"Depth\": " + IntegerToString(depth) + ",\n";
      content += "  \"Deviation\": " + IntegerToString(deviation) + ",\n";
      content += "  \"Backstep\": " + IntegerToString(backstep) + ",\n";
      content += "  \"ShowLabels\": " + (showLabels ? "true" : "false") + ",\n";
      content += "  \"LabelColor\": " + IntegerToString((int)labelColor) + ",\n";
      content += "  \"Show5M\": " + (show5M ? "true" : "false") + ",\n";
      content += "  \"Show4H\": " + (show4H ? "true" : "false") + ",\n";
      content += "  \"Label4HColor\": " + IntegerToString((int)label4HColor) + ",\n";
      content += "  \"CacheTimeout\": " + IntegerToString(cacheTimeout) + ",\n";
      content += "  \"MaxBarsH1\": " + IntegerToString(maxBarsH1) + ",\n";
      content += "  \"ShowInfoPanel\": " + (showInfoPanel ? "true" : "false") + ",\n";
      content += "  \"InfoPanelColor\": " + IntegerToString((int)infoPanelColor) + ",\n";
      content += "  \"InfoPanelBgColor\": " + IntegerToString((int)infoPanelBgColor) + ",\n";
      content += "  \"ShowPenetratedPoints\": " + (showPenetratedPoints ? "true" : "false") + "\n";
      content += "}";
      
      return WriteConfigToFile(content);
     }
     
   // 从配置文件中获取整数值
   static int GetIntValue(string jsonContent, string key, int defaultValue)
     {
      string searchKey = "\"" + key + "\": ";
      int pos = StringFind(jsonContent, searchKey);
      if(pos == -1)
         return defaultValue;
         
      // 找到键后，获取值
      int valueStart = pos + StringLen(searchKey);
      int valueEnd = StringFind(jsonContent, ",", valueStart);
      if(valueEnd == -1)
         valueEnd = StringFind(jsonContent, "\n", valueStart);
      
      if(valueEnd == -1)
         return defaultValue;
         
      string valueStr = StringSubstr(jsonContent, valueStart, valueEnd - valueStart);
      // 手动去除前后空格
      while(StringLen(valueStr) > 0 && (valueStr[0] == ' ' || valueStr[0] == '\t'))
         valueStr = StringSubstr(valueStr, 1);
      while(StringLen(valueStr) > 0 && (valueStr[StringLen(valueStr)-1] == ' ' || valueStr[StringLen(valueStr)-1] == '\t'))
         valueStr = StringSubstr(valueStr, 0, StringLen(valueStr)-1);
      
      return (int)StringToInteger(valueStr);
     }
     
   // 从配置文件中获取布尔值
   static bool GetBoolValue(string jsonContent, string key, bool defaultValue)
     {
      string searchKey = "\"" + key + "\": ";
      int pos = StringFind(jsonContent, searchKey);
      if(pos == -1)
         return defaultValue;
         
      // 找到键后，获取值
      int valueStart = pos + StringLen(searchKey);
      int valueEnd = StringFind(jsonContent, ",", valueStart);
      if(valueEnd == -1)
         valueEnd = StringFind(jsonContent, "\n", valueStart);
      
      if(valueEnd == -1)
         return defaultValue;
         
      string valueStr = StringSubstr(jsonContent, valueStart, valueEnd - valueStart);
      // 手动去除前后空格
      while(StringLen(valueStr) > 0 && (valueStr[0] == ' ' || valueStr[0] == '\t'))
         valueStr = StringSubstr(valueStr, 1);
      while(StringLen(valueStr) > 0 && (valueStr[StringLen(valueStr)-1] == ' ' || valueStr[StringLen(valueStr)-1] == '\t'))
         valueStr = StringSubstr(valueStr, 0, StringLen(valueStr)-1);
      
      return (valueStr == "true");
     }
     
   // 从配置文件中获取颜色值
   static color GetColorValue(string jsonContent, string key, color defaultValue)
     {
      string searchKey = "\"" + key + "\": ";
      int pos = StringFind(jsonContent, searchKey);
      if(pos == -1)
         return defaultValue;
         
      // 找到键后，获取值
      int valueStart = pos + StringLen(searchKey);
      int valueEnd = StringFind(jsonContent, ",", valueStart);
      if(valueEnd == -1)
         valueEnd = StringFind(jsonContent, "\n", valueStart);
      
      if(valueEnd == -1)
         return defaultValue;
         
      string valueStr = StringSubstr(jsonContent, valueStart, valueEnd - valueStart);
      // 手动去除前后空格
      while(StringLen(valueStr) > 0 && (valueStr[0] == ' ' || valueStr[0] == '\t'))
         valueStr = StringSubstr(valueStr, 1);
      while(StringLen(valueStr) > 0 && (valueStr[StringLen(valueStr)-1] == ' ' || valueStr[StringLen(valueStr)-1] == '\t'))
         valueStr = StringSubstr(valueStr, 0, StringLen(valueStr)-1);
      
      return (color)(int)StringToInteger(valueStr);
     }
     
   // 加载配置
   static bool LoadConfig(int &depth, int &deviation, int &backstep, 
                        bool &showLabels, color &labelColor,
                        bool &show5M, bool &show4H, color &label4HColor,
                        int &cacheTimeout, int &maxBarsH1,
                        bool &showInfoPanel, color &infoPanelColor, color &infoPanelBgColor,
                        bool &showPenetratedPoints)
     {
      // 读取配置文件内容
      string jsonContent = ReadConfigFromFile();
      
      // 如果配置文件为空，返回false
      if(jsonContent == "")
        {
         return false;
        }
      
      // 解析配置值
      depth = GetIntValue(jsonContent, "Depth", depth);
      deviation = GetIntValue(jsonContent, "Deviation", deviation);
      backstep = GetIntValue(jsonContent, "Backstep", backstep);
      showLabels = GetBoolValue(jsonContent, "ShowLabels", showLabels);
      labelColor = GetColorValue(jsonContent, "LabelColor", labelColor);
      show5M = GetBoolValue(jsonContent, "Show5M", show5M);
      show4H = GetBoolValue(jsonContent, "Show4H", show4H);
      label4HColor = GetColorValue(jsonContent, "Label4HColor", label4HColor);
      cacheTimeout = GetIntValue(jsonContent, "CacheTimeout", cacheTimeout);
      maxBarsH1 = GetIntValue(jsonContent, "MaxBarsH1", maxBarsH1);
      showInfoPanel = GetBoolValue(jsonContent, "ShowInfoPanel", showInfoPanel);
      infoPanelColor = GetColorValue(jsonContent, "InfoPanelColor", infoPanelColor);
      infoPanelBgColor = GetColorValue(jsonContent, "InfoPanelBgColor", infoPanelBgColor);
      showPenetratedPoints = GetBoolValue(jsonContent, "ShowPenetratedPoints", showPenetratedPoints);
      
      return true;
     }
     
   // 检查是否有保存的配置
   static bool HasSavedConfig()
     {
      string filePath = GetConfigFilePath();
      return FileIsExist(filePath);
     }
  };

// 初始化静态成员变量
string CConfigManager::m_configFileName = "";
string CConfigManager::m_symbolName = "";
