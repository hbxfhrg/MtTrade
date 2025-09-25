#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
ReadReport GUI版本
专门用于从ReportTester.xlsx中读取订单列表和成交记录列表，并保存到MySQL数据库
带有图形用户界面，可以编译成exe文件
"""

import tkinter as tk
from tkinter import filedialog, messagebox, scrolledtext
import pandas as pd
import mysql.connector
from mysql.connector import Error
import datetime
import logging
import os
import sys

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("ReadReport.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("ReadReport")

class ReadReportGUI:
    """ReadReport GUI版本"""
    
    def __init__(self, root):
        """
        初始化GUI
        
        Args:
            root: tkinter根窗口
        """
        self.root = root
        self.root.title("ReadReport")
        self.root.geometry("800x600")
        
        # 数据库配置
        self.db_config = {
            'host': 'localhost',
            'user': 'root',
            'password': '!Aa123456',
            'database': 'pymt5',
            'port': 3306
        }
        self.conn = None
        self.cursor = None
        
        # 文件路径
        self.file_path = tk.StringVar()
        
        # 创建界面
        self.create_widgets()
        
        # 重定向stdout到文本框
        sys.stdout = TextRedirector(self.log_text, "stdout")
        sys.stderr = TextRedirector(self.log_text, "stderr")
    
    def create_widgets(self):
        """创建界面组件"""
        # 主框架
        main_frame = tk.Frame(self.root)
        main_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        # 文件选择框架
        file_frame = tk.LabelFrame(main_frame, text="文件选择", padx=5, pady=5)
        file_frame.pack(fill=tk.X, pady=(0, 10))
        
        # 文件路径输入
        tk.Label(file_frame, text="Excel文件路径:").grid(row=0, column=0, sticky=tk.W)
        tk.Entry(file_frame, textvariable=self.file_path, width=50).grid(row=0, column=1, padx=(5, 5), sticky=tk.EW)
        tk.Button(file_frame, text="浏览...", command=self.browse_file).grid(row=0, column=2, padx=(5, 0))
        
        file_frame.columnconfigure(1, weight=1)
        
        # 操作按钮框架
        button_frame = tk.Frame(main_frame)
        button_frame.pack(fill=tk.X, pady=(0, 10))
        
        # 操作按钮
        tk.Button(button_frame, text="读取数据", command=self.read_data, bg="#4CAF50", fg="white").pack(side=tk.LEFT, padx=(0, 5))
        tk.Button(button_frame, text="保存CSV", command=self.save_csv, bg="#2196F3", fg="white").pack(side=tk.LEFT, padx=(0, 5))
        tk.Button(button_frame, text="保存数据库", command=self.save_database, bg="#FF9800", fg="white").pack(side=tk.LEFT, padx=(0, 5))
        tk.Button(button_frame, text="清空日志", command=self.clear_log, bg="#F44336", fg="white").pack(side=tk.LEFT)
        
        # 日志显示框架
        log_frame = tk.LabelFrame(main_frame, text="运行日志", padx=5, pady=5)
        log_frame.pack(fill=tk.BOTH, expand=True)
        
        # 日志文本框
        self.log_text = scrolledtext.ScrolledText(log_frame, height=20)
        self.log_text.pack(fill=tk.BOTH, expand=True)
        
        # 添加说明文本
        info_text = """
使用说明：
1. 点击"浏览..."按钮选择ReportTester.xlsx文件
2. 点击"读取数据"按钮读取订单和成交记录
3. 点击"保存CSV"按钮将数据保存为CSV文件
4. 点击"保存数据库"按钮将数据保存到MySQL数据库
5. 点击"清空日志"按钮清空日志显示
        """
        tk.Label(main_frame, text=info_text, justify=tk.LEFT, fg="blue").pack(fill=tk.X, pady=(10, 0))
    
    def browse_file(self):
        """浏览文件"""
        file_path = filedialog.askopenfilename(
            title="选择Excel文件",
            filetypes=[("Excel文件", "*.xlsx"), ("所有文件", "*.*")]
        )
        if file_path:
            self.file_path.set(file_path)
            logger.info(f"已选择文件: {file_path}")
    
    def read_data(self):
        """读取数据"""
        if not self.file_path.get():
            messagebox.showerror("错误", "请先选择Excel文件")
            return
        
        if not os.path.exists(self.file_path.get()):
            messagebox.showerror("错误", "文件不存在")
            return
        
        try:
            logger.info("开始读取数据...")
            self.orders_df, self.deals_df = self._read_order_deal_data(self.file_path.get())
            logger.info("数据读取完成")
            messagebox.showinfo("成功", "数据读取完成")
        except Exception as e:
            logger.error(f"读取数据失败: {e}")
            messagebox.showerror("错误", f"读取数据失败: {e}")
    
    def save_csv(self):
        """保存CSV"""
        if not hasattr(self, 'orders_df') or not hasattr(self, 'deals_df'):
            messagebox.showerror("错误", "请先读取数据")
            return
        
        try:
            # 选择保存目录
            save_dir = filedialog.askdirectory(title="选择保存目录")
            if not save_dir:
                return
            
            orders_csv_path = os.path.join(save_dir, "orders.csv")
            deals_csv_path = os.path.join(save_dir, "deals.csv")
            
            self._save_to_csv(self.orders_df, self.deals_df, orders_csv_path, deals_csv_path)
            logger.info(f"CSV文件已保存到: {save_dir}")
            messagebox.showinfo("成功", f"CSV文件已保存到: {save_dir}")
        except Exception as e:
            logger.error(f"保存CSV失败: {e}")
            messagebox.showerror("错误", f"保存CSV失败: {e}")
    
    def save_database(self):
        """保存到数据库"""
        if not hasattr(self, 'orders_df') or not hasattr(self, 'deals_df'):
            messagebox.showerror("错误", "请先读取数据")
            return
        
        try:
            logger.info("开始保存到数据库...")
            if self._connect_db():
                if self._create_tables():
                    orders_count = self._save_orders_to_db(self.orders_df, os.path.basename(self.file_path.get()))
                    deals_count = self._save_deals_to_db(self.deals_df, os.path.basename(self.file_path.get()))
                    logger.info(f"成功将 {orders_count} 条订单记录和 {deals_count} 条成交记录保存到数据库")
                    messagebox.showinfo("成功", f"成功将 {orders_count} 条订单记录和 {deals_count} 条成交记录保存到数据库")
                self._close_db()
            else:
                logger.error("无法连接到数据库")
                messagebox.showerror("错误", "无法连接到数据库")
        except Exception as e:
            logger.error(f"保存到数据库失败: {e}")
            messagebox.showerror("错误", f"保存到数据库失败: {e}")
    
    def clear_log(self):
        """清空日志"""
        self.log_text.delete(1.0, tk.END)
    
    def _connect_db(self):
        """连接到MySQL数据库"""
        try:
            self.conn = mysql.connector.connect(**self.db_config)
            self.cursor = self.conn.cursor()
            logger.info("成功连接到MySQL数据库")
            return True
        except Error as e:
            logger.error(f"数据库连接失败: {e}")
            return False
    
    def _close_db(self):
        """关闭数据库连接"""
        if self.cursor:
            self.cursor.close()
        if self.conn:
            self.conn.close()
        logger.info("数据库连接已关闭")
    
    def _create_tables(self):
        """创建订单和成交记录表"""
        try:
            # 创建订单表（根据ReportTester.xlsx的实际列结构调整）
            self.cursor.execute("""
            CREATE TABLE IF NOT EXISTS report_orders (
                id INT AUTO_INCREMENT PRIMARY KEY,
                open_time DATETIME COMMENT '开价时间',
                order_id BIGINT COMMENT '订单号',
                symbol VARCHAR(20) COMMENT '交易品种',
                type VARCHAR(50) COMMENT '类型',
                volume VARCHAR(20) COMMENT '交易量',
                price DOUBLE COMMENT '价位',
                sl DOUBLE COMMENT '止损',
                tp DOUBLE COMMENT '止盈',
                time DATETIME COMMENT '时间',
                status VARCHAR(20) COMMENT '状态',
                comment VARCHAR(255) COMMENT '注释',
                report_file VARCHAR(255) COMMENT '报告文件名',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间'
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            """)
            
            # 创建成交记录表（根据ReportTester.xlsx的实际列结构调整）
            self.cursor.execute("""
            CREATE TABLE IF NOT EXISTS report_deals (
                id INT AUTO_INCREMENT PRIMARY KEY,
                deal_time DATETIME COMMENT '时间',
                deal_id BIGINT COMMENT '成交号',
                symbol VARCHAR(20) COMMENT '交易品种',
                type VARCHAR(50) COMMENT '类型',
                direction VARCHAR(20) COMMENT '趋势',
                volume VARCHAR(20) COMMENT '交易量',
                price DOUBLE COMMENT '价位',
                order_id BIGINT COMMENT '订单号',
                commission DOUBLE COMMENT '手续费',
                swap DOUBLE COMMENT '库存费',
                profit DOUBLE COMMENT '盈利',
                balance DOUBLE COMMENT '结余',
                comment VARCHAR(255) COMMENT '注释',
                report_file VARCHAR(255) COMMENT '报告文件名',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间'
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            """)
            
            self.conn.commit()
            logger.info("数据表创建成功")
            return True
        except Error as e:
            logger.error(f"创建数据表失败: {e}")
            self.conn.rollback()
            return False
    
    def _read_order_deal_data(self, file_path):
        """
        从Excel文件中读取订单和成交记录数据
        
        Args:
            file_path (str): Excel文件路径
            
        Returns:
            tuple: (orders_df, deals_df) 订单和成交记录的DataFrame
        """
        try:
            # 检查文件是否存在
            if not os.path.exists(file_path):
                logger.error(f"文件不存在: {file_path}")
                logger.info(f"当前工作目录: {os.getcwd()}")
                logger.info(f"目录中的文件: {os.listdir('.')}")
                return None, None
            
            logger.info(f"开始读取文件: {file_path}")
            logger.info(f"文件大小: {os.path.getsize(file_path)} 字节")
            
            # 读取整个Excel文件
            df = pd.read_excel(file_path, header=None)
            logger.info(f"成功读取Excel文件，包含 {len(df)} 行数据")
            
            # 查找订单表头行（包含"订单"关键字且下一行包含"开价时间"的行）
            orders_header_row = None
            for i in range(len(df)):
                row_values = df.iloc[i].values
                row_str = ' '.join([str(x) for x in row_values if pd.notna(x)])
                # 检查当前行是否为"订单"表头，并且下一行是否为列名行（包含"开价时间"）
                if '订单' in row_str:
                    if i + 1 < len(df):
                        next_row_values = df.iloc[i + 1].values
                        next_row_str = ' '.join([str(x) for x in next_row_values if pd.notna(x)])
                        if '开价时间' in next_row_str:
                            orders_header_row = i
                            logger.info(f"找到订单表头行: 第{i+1}行")
                            break
            
            # 查找成交表头行（包含"成交"关键字且下一行包含"时间"的行）
            deals_header_row = None
            for i in range(len(df)):
                row_values = df.iloc[i].values
                row_str = ' '.join([str(x) for x in row_values if pd.notna(x)])
                # 检查当前行是否为"成交"表头，并且下一行是否为列名行（包含"时间"）
                if '成交' in row_str:
                    if i + 1 < len(df):
                        next_row_values = df.iloc[i + 1].values
                        next_row_str = ' '.join([str(x) for x in next_row_values if pd.notna(x)])
                        if '时间' in next_row_str and '成交' in next_row_str:
                            deals_header_row = i
                            logger.info(f"找到成交表头行: 第{i+1}行")
                            break
            
            # 如果没有找到表头，返回空数据
            if orders_header_row is None:
                logger.warning("未找到订单表头")
                return None, None
            
            # 读取订单数据表头（订单表头的下一行）
            order_columns_row = orders_header_row + 1
            order_columns = []
            for val in df.iloc[order_columns_row].values:
                if pd.notna(val):
                    order_columns.append(str(val))
                else:
                    order_columns.append("")
            
            logger.info(f"订单表列名: {order_columns}")
            
            # 读取订单数据（从订单表头下两行开始，到成交表头为止）
            orders_data = []
            end_row = deals_header_row if deals_header_row is not None else len(df)
            for i in range(orders_header_row + 2, end_row):
                row_values = df.iloc[i].values
                # 只添加非空行
                non_na_count = sum(1 for x in row_values if pd.notna(x))
                if non_na_count >= 2:  # 至少有2个非空值才认为是有效数据行
                    orders_data.append(row_values)
            
            # 创建订单DataFrame
            if orders_data:
                # 确保列数与数据匹配
                max_cols = len(order_columns)
                for i in range(len(orders_data)):
                    if len(orders_data[i]) < max_cols:
                        # 如果数据列数不足，补充空值
                        orders_data[i] = list(orders_data[i]) + [''] * (max_cols - len(orders_data[i]))
                    elif len(orders_data[i]) > max_cols:
                        # 如果数据列数过多，截断
                        orders_data[i] = orders_data[i][:max_cols]
                
                orders_df = pd.DataFrame(orders_data, columns=order_columns)
                logger.info(f"成功提取订单数据，包含 {len(orders_df)} 行")
            else:
                orders_df = pd.DataFrame(columns=order_columns)
                logger.warning("未找到有效的订单数据")
            
            # 如果没有找到成交表头，返回订单数据
            if deals_header_row is None:
                logger.warning("未找到成交表头")
                return orders_df, None
            
            # 读取成交记录表头（成交表头的下一行）
            deal_columns_row = deals_header_row + 1
            deal_columns = []
            for val in df.iloc[deal_columns_row].values:
                if pd.notna(val):
                    deal_columns.append(str(val))
                else:
                    deal_columns.append("")
            
            logger.info(f"成交表列名: {deal_columns}")
            
            # 读取成交记录数据（从成交表头下两行开始，到文件末尾）
            deals_data = []
            for i in range(deals_header_row + 2, len(df)):
                row_values = df.iloc[i].values
                # 只添加非空行
                non_na_count = sum(1 for x in row_values if pd.notna(x))
                if non_na_count >= 2:  # 至少有2个非空值才认为是有效数据行
                    deals_data.append(row_values)
            
            # 创建成交记录DataFrame
            if deals_data:
                # 确保列数与数据匹配
                max_cols = len(deal_columns)
                for i in range(len(deals_data)):
                    if len(deals_data[i]) < max_cols:
                        # 如果数据列数不足，补充空值
                        deals_data[i] = list(deals_data[i]) + [''] * (max_cols - len(deals_data[i]))
                    elif len(deals_data[i]) > max_cols:
                        # 如果数据列数过多，截断
                        deals_data[i] = deals_data[i][:max_cols]
                
                deals_df = pd.DataFrame(deals_data, columns=deal_columns)
                logger.info(f"成功提取成交记录数据，包含 {len(deals_df)} 行")
            else:
                deals_df = pd.DataFrame(columns=deal_columns)
                logger.warning("未找到有效的成交记录数据")
            
            return orders_df, deals_df
            
        except Exception as e:
            logger.error(f"读取Excel文件失败: {e}")
            return None, None
    
    def _save_to_csv(self, orders_df, deals_df, orders_csv_path="orders.csv", deals_csv_path="deals.csv"):
        """
        将订单和成交记录保存为CSV文件
        
        Args:
            orders_df (DataFrame): 订单数据
            deals_df (DataFrame): 成交记录数据
            orders_csv_path (str): 订单CSV文件路径
            deals_csv_path (str): 成交记录CSV文件路径
        """
        try:
            if orders_df is not None and not orders_df.empty:
                orders_df.to_csv(orders_csv_path, index=False, encoding='utf-8-sig')
                logger.info(f"订单数据已保存到 {orders_csv_path}")
            else:
                logger.warning("订单数据为空，未保存")
            
            if deals_df is not None and not deals_df.empty:
                deals_df.to_csv(deals_csv_path, index=False, encoding='utf-8-sig')
                logger.info(f"成交记录数据已保存到 {deals_csv_path}")
            else:
                logger.warning("成交记录数据为空，未保存")
        except Exception as e:
            logger.error(f"保存CSV文件失败: {e}")
    
    def _save_orders_to_db(self, orders_df, report_file):
        """
        将订单数据保存到数据库
        
        Args:
            orders_df (DataFrame): 订单数据
            report_file (str): 报告文件名
            
        Returns:
            int: 成功插入的记录数
        """
        if orders_df is None or len(orders_df) == 0:
            logger.warning("订单数据为空，跳过保存到数据库")
            return 0
        
        try:
            insert_query = """
            INSERT INTO report_orders 
            (open_time, order_id, symbol, type, volume, price, sl, tp, time, status, comment, report_file)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE
            open_time=VALUES(open_time), symbol=VALUES(symbol), type=VALUES(type), 
            volume=VALUES(volume), price=VALUES(price), sl=VALUES(sl), tp=VALUES(tp), 
            time=VALUES(time), status=VALUES(status), comment=VALUES(comment), report_file=VALUES(report_file)
            """
            
            count = 0
            for idx, row in orders_df.iterrows():
                # 提取各字段值
                open_time = None
                order_id = None
                symbol = ""
                type_val = ""
                volume = ""
                price = 0.0
                sl = 0.0
                tp = 0.0
                time_val = None
                status = ""
                comment = ""
                
                # 遍历列查找匹配的字段
                for col in orders_df.columns:
                    # 确保col不是NaN
                    if pd.isna(col):
                        continue
                        
                    col_name = str(col)
                    col_lower = col_name.lower()
                    value = row[col]
                    
                    # 检查值是否为空，使用any()方法处理可能的Series情况
                    try:
                        if pd.isna(value).any():
                            continue
                    except AttributeError:
                        # 如果不是Series，直接检查
                        if pd.isna(value):
                            continue
                    
                    # 开价时间
                    if '开价时间' in col_name:
                        if isinstance(value, datetime.datetime):
                            open_time = value
                        elif isinstance(value, str):
                            try:
                                open_time = datetime.datetime.strptime(value, '%Y.%m.%d %H:%M:%S')
                            except ValueError:
                                pass
                    
                    # 订单号
                    elif '订单' in col_name and '开价时间' not in col_name:
                        try:
                            order_id = int(float(value))
                        except (ValueError, TypeError):
                            order_id = None
                    
                    # 交易品种
                    elif '交易品种' in col_name:
                        symbol = str(value)
                    
                    # 类型
                    elif '类型' in col_name:
                        type_val = str(value)
                    
                    # 交易量
                    elif '交易量' in col_name:
                        volume = str(value)
                    
                    # 价位
                    elif '价位' in col_name:
                        try:
                            price = float(value)
                        except (ValueError, TypeError):
                            price = 0.0
                    
                    # 止损
                    elif '止损' in col_name:
                        try:
                            sl = float(value)
                        except (ValueError, TypeError):
                            sl = 0.0
                    
                    # 止盈
                    elif '止盈' in col_name:
                        try:
                            tp = float(value)
                        except (ValueError, TypeError):
                            tp = 0.0
                    
                    # 时间
                    elif '时间' in col_name and '开价时间' not in col_name:
                        if isinstance(value, datetime.datetime):
                            time_val = value
                        elif isinstance(value, str):
                            try:
                                time_val = datetime.datetime.strptime(value, '%Y.%m.%d %H:%M:%S')
                            except ValueError:
                                pass
                    
                    # 状态
                    elif '状态' in col_name:
                        status = str(value)
                    
                    # 注释
                    elif '注释' in col_name:
                        comment = str(value)
                
                # 如果订单号为空，跳过此行
                if order_id is None:
                    logger.warning(f"跳过第{idx+1}行，订单号为空: {row.to_dict()}")
                    continue
                
                values = (
                    open_time,
                    order_id,
                    symbol,
                    type_val,
                    volume,
                    price,
                    sl,
                    tp,
                    time_val,
                    status,
                    comment,
                    report_file
                )
                
                self.cursor.execute(insert_query, values)
                count += 1
            
            self.conn.commit()
            logger.info(f"成功将{count}条订单记录保存到数据库")
            return count
            
        except Error as e:
            logger.error(f"保存订单数据到数据库失败: {e}")
            self.conn.rollback()
            return 0
    
    def _save_deals_to_db(self, deals_df, report_file):
        """
        将成交记录数据保存到数据库
        
        Args:
            deals_df (DataFrame): 成交记录数据
            report_file (str): 报告文件名
            
        Returns:
            int: 成功插入的记录数
        """
        if deals_df is None or len(deals_df) == 0:
            logger.warning("成交记录数据为空，跳过保存到数据库")
            return 0
        
        try:
            insert_query = """
            INSERT INTO report_deals 
            (deal_time, deal_id, symbol, type, direction, volume, price, order_id, commission, swap, profit, balance, comment, report_file)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE
            deal_time=VALUES(deal_time), symbol=VALUES(symbol), type=VALUES(type), direction=VALUES(direction),
            volume=VALUES(volume), price=VALUES(price), order_id=VALUES(order_id), commission=VALUES(commission),
            swap=VALUES(swap), profit=VALUES(profit), balance=VALUES(balance), comment=VALUES(comment), 
            report_file=VALUES(report_file)
            """
            
            count = 0
            for idx, row in deals_df.iterrows():
                # 提取各字段值
                deal_time = None
                deal_id = None
                symbol = ""
                type_val = ""
                direction = ""
                volume = ""
                price = 0.0
                order_id = 0
                commission = 0.0
                swap = 0.0
                profit = 0.0
                balance = 0.0
                comment = ""
                
                # 遍历列查找匹配的字段
                for col in deals_df.columns:
                    # 确保col不是NaN
                    if pd.isna(col):
                        continue
                        
                    col_name = str(col)
                    col_lower = col_name.lower()
                    value = row[col]
                    
                    # 检查值是否为空，使用any()方法处理可能的Series情况
                    try:
                        if pd.isna(value).any():
                            continue
                    except AttributeError:
                        # 如果不是Series，直接检查
                        if pd.isna(value):
                            continue
                    
                    # 时间
                    if '时间' in col_name and '成交' not in col_name:
                        if isinstance(value, datetime.datetime):
                            deal_time = value
                        elif isinstance(value, str):
                            try:
                                deal_time = datetime.datetime.strptime(value, '%Y.%m.%d %H:%M:%S')
                            except ValueError:
                                pass
                    
                    # 成交号
                    elif '成交' in col_name and '时间' not in col_name:
                        try:
                            deal_id = int(float(value))
                        except (ValueError, TypeError):
                            deal_id = None
                    
                    # 交易品种
                    elif '交易品种' in col_name:
                        symbol = str(value)
                    
                    # 类型
                    elif '类型' in col_name:
                        type_val = str(value)
                    
                    # 趋势/方向
                    elif '趋势' in col_name or '方向' in col_name:
                        direction = str(value)
                    
                    # 交易量
                    elif '交易量' in col_name:
                        volume = str(value)
                    
                    # 价位
                    elif '价位' in col_name:
                        try:
                            price = float(value)
                        except (ValueError, TypeError):
                            price = 0.0
                    
                    # 订单号
                    elif '订单' in col_name and '成交' not in col_name:
                        try:
                            order_id = int(float(value))
                        except (ValueError, TypeError):
                            order_id = 0
                    
                    # 手续费
                    elif '手续费' in col_name:
                        try:
                            commission = float(value)
                        except (ValueError, TypeError):
                            commission = 0.0
                    
                    # 库存费/掉期
                    elif '库存费' in col_name or '掉期' in col_name:
                        try:
                            swap = float(value)
                        except (ValueError, TypeError):
                            swap = 0.0
                    
                    # 盈利
                    elif '盈利' in col_name:
                        try:
                            profit = float(value)
                        except (ValueError, TypeError):
                            profit = 0.0
                    
                    # 结余
                    elif '结余' in col_name:
                        try:
                            balance = float(value)
                        except (ValueError, TypeError):
                            balance = 0.0
                    
                    # 注释
                    elif '注释' in col_name:
                        comment = str(value)
                
                # 如果成交号为空，跳过此行
                if deal_id is None:
                    logger.warning(f"跳过第{idx+1}行，成交号为空: {row.to_dict()}")
                    continue
                
                values = (
                    deal_time,
                    deal_id,
                    symbol,
                    type_val,
                    direction,
                    volume,
                    price,
                    order_id,
                    commission,
                    swap,
                    profit,
                    balance,
                    comment,
                    report_file
                )
                
                self.cursor.execute(insert_query, values)
                count += 1
            
            self.conn.commit()
            logger.info(f"成功将{count}条成交记录保存到数据库")
            return count
            
        except Error as e:
            logger.error(f"保存成交记录数据到数据库失败: {e}")
            self.conn.rollback()
            return 0

class TextRedirector:
    """重定向stdout/stderr到文本框"""
    def __init__(self, widget, tag="stdout"):
        self.widget = widget
        self.tag = tag

    def write(self, str):
        self.widget.configure(state="normal")
        self.widget.insert("end", str, (self.tag,))
        self.widget.configure(state="disabled")
        self.widget.see("end")

    def flush(self):
        pass

def main():
    """主函数"""
    root = tk.Tk()
    app = ReadReportGUI(root)
    root.mainloop()

if __name__ == "__main__":
    main()