# ReadReport GUI版本

这是一个带有图形用户界面的Windows应用程序，可以读取MT5策略测试报告中的订单和成交记录，并将其保存到CSV文件或MySQL数据库中。

## 功能特点

1. **图形界面**：直观易用的图形用户界面
2. **文件选择**：通过浏览按钮选择ReportTester.xlsx文件
3. **数据读取**：自动识别并提取订单和成交记录数据
4. **CSV导出**：将数据保存为CSV文件
5. **数据库存储**：将数据保存到MySQL数据库
6. **实时日志**：显示操作过程中的详细日志信息

## 使用方法

### 方法一：直接运行exe文件
1. 双击 `dist/ReadReport.exe` 文件启动程序
2. 点击"浏览..."按钮选择ReportTester.xlsx文件
3. 点击"读取数据"按钮读取订单和成交记录
4. 点击"保存CSV"按钮将数据保存为CSV文件
5. 点击"保存数据库"按钮将数据保存到MySQL数据库

### 方法二：运行批处理文件
1. 双击 `run_gui.bat` 文件启动程序
2. 按照上述步骤操作

## 系统要求

- Windows操作系统
- Python 3.13或更高版本（仅在开发环境中需要）
- MySQL数据库（可选，用于保存数据到数据库）

## 数据库配置

程序默认使用以下数据库配置：
- 主机：localhost
- 端口：3306
- 用户名：root
- 密码：!Aa123456
- 数据库：pymt5

如需修改数据库配置，请编辑 `ReadReport.py` 文件中的 `db_config` 变量。

## 编译说明

如果需要重新编译exe文件，有两种方法：

### 方法一：使用批处理文件（推荐）
1. 双击 `build_exe.bat` 文件
2. 等待打包完成
3. 生成的exe文件位于 `dist` 目录中

### 方法二：手动编译
1. 安装依赖：
   ```
   pip install pandas openpyxl mysql-connector-python pyinstaller
   ```

2. 编译exe文件：
   ```
   pyinstaller --onefile --windowed ReadReport.py
   ```

3. 生成的exe文件位于 `dist` 目录中

## 文件说明

- `ReadReport.py`：GUI应用程序源代码
- `dist/ReadReport.exe`：编译后的可执行文件
- `run_gui.bat`：启动批处理文件
- `build_exe.bat`：打包批处理文件
- `build_exe.py`：使用cx_Freeze打包的脚本（备用）
- `orders.csv`：导出的订单数据CSV文件（示例）
- `deals.csv`：导出的成交记录CSV文件（示例）
- `ReadReport.log`：程序运行日志

## 注意事项

1. 确保ReportTester.xlsx文件格式正确
2. 确保MySQL数据库服务正在运行（如果要保存到数据库）
3. 程序会自动创建所需的数据库表
4. 如果遇到权限问题，请以管理员身份运行程序