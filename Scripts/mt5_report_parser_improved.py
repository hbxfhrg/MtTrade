#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
MT5策略测试报告解析器 (改进版)
专门用于解析MetaTrader 5策略测试报告的非标准Excel格式
更加通用，能够根据表头自动识别订单和成交记录的开始行
"""

import os
import sys
import pandas as pd
import mysql.connector
from mysql.connector import Error
import datetime
import logging
import re
from pathlib import Path

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("mt5_report_parser_improved.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("MT5ReportParser")

class MT5ReportParser:
    """MT5策略测试报告解析器"""
    
    def __init__(self, db_config=None):
        """
        初始化解析器
        
        Args:
            db_config (dict): 数据库配置，包含host, user, password, database等信息
        """
        self.db_config = db_config or {
            'host': 'localhost',
            'user': 'root',
            'password': '!Aa123456',
            'database': 'pymt5',
            'port': 3306
        }
        self.conn = None
        self.cursor = None
        
        # 订单表头关键词
        self.order_header_keywords = [
            '订单号', '订单', 'order', '#', 
            '时间', 'time', 
            '类型', 'type', 
            '交易量', 'volume', 'lot',
            '价格', 'price',
            '止损', 's/l', 'sl',
            '止盈', 't/p', 'tp'
        ]
        
        # 成交记录表头关键词
        self.deal_header_keywords = [
            '成交号', '成交', 'deal', '#',
            '订单号', '订单', 'order',
            '时间', 'time',
            '类型', 'type',
            '方向', 'direction',
            '交易量', 'volume', 'lot',
            '价格', 'price',
            '利润', 'profit'
        ]
    
    def connect_db(self):
        """连接到MySQL数据库"""
        try:
            self.conn = mysql.connector.connect(**self.db_config)
            self.cursor = self.conn.cursor()
            logger.info("成功连接到MySQL数据库")
            return True
        except Error as e:
            logger.error(f"数据库连接失败: {e}")
            return False
    
    def close_db(self):
        """关闭数据库连接"""
        if self.cursor:
            self.cursor.close()
        if self.conn:
            self.conn.close()
        logger.info("数据库连接已关闭")
    
    def create_tables(self):
        """创建订单和成交记录表"""
        try:
            # 创建订单表
            self.cursor.execute("""
            CREATE TABLE IF NOT EXISTS mt5_strategy_orders (
                id INT AUTO_INCREMENT PRIMARY KEY,
                order_id BIGINT,
                symbol VARCHAR(20),
                type VARCHAR(20),
                time DATETIME,
                open_price DOUBLE,
                volume DOUBLE,
                sl DOUBLE,
                tp DOUBLE,
                comment VARCHAR(255),
                report_file VARCHAR(255),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            """)
            
            # 创建成交记录表
            self.cursor.execute("""
            CREATE TABLE IF NOT EXISTS mt5_strategy_deals (
                id INT AUTO_INCREMENT PRIMARY KEY,
                deal_id BIGINT,
                order_id BIGINT,
                symbol VARCHAR(20),
                type VARCHAR(20),
                direction VARCHAR(10),
                time DATETIME,
                price DOUBLE,
                volume DOUBLE,
                profit DOUBLE,
                commission DOUBLE,
                swap DOUBLE,
                comment VARCHAR(255),
                report_file VARCHAR(255),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            """)
            
            self.conn.commit()
            logger.info("数据表创建成功")
            return True
        except Error as e:
            logger.error(f"创建数据表失败: {e}")
            self.conn.rollback()
            return False
    
    def is_header_row(self, row_values, header_keywords):
        """
        判断一行是否为表头行
        
        Args:
            row_values: 行值
            header_keywords: 表头关键词列表
            
        Returns:
            bool: 是否为表头行
        """
        # 将行值转换为字符串并连接
        row_str = ' '.join([str(x).lower() for x in row_values if pd.notna(x)])
        
        # 计算匹配的关键词数量
        match_count = sum(1 for keyword in header_keywords if keyword.lower() in row_str)
        
        # 如果匹配的关键词数量超过阈值，认为是表头行
        return match_count >= 3
    
    def extract_data_from_excel(self, file_path):
        """
        从Excel文件中提取数据
        
        Args:
            file_path (str): Excel文件路径
            
        Returns:
            tuple: (orders_df, deals_df) 订单和成交记录的DataFrame
        """
        try:
            # 直接读取整个Excel文件
            df = pd.read_excel(file_path, header=None)
            logger.info(f"成功读取Excel文件，包含 {len(df)} 行数据")
            
            # 查找订单和成交记录表头行
            orders_header_row = None
            deals_header_row = None
            
            # 遍历行查找表头
            for i in range(len(df)):
                row_values = df.iloc[i].values
                
                # 检查是否为订单表头行
                if orders_header_row is None and self.is_header_row(row_values, self.order_header_keywords):
                    orders_header_row = i
                    logger.info(f"找到订单表头行: {orders_header_row + 1}")
                
                # 检查是否为成交记录表头行
                if deals_header_row is None and self.is_header_row(row_values, self.deal_header_keywords):
                    deals_header_row = i
                    logger.info(f"找到成交记录表头行: {deals_header_row + 1}")
                
                # 如果两个表头都找到了，可以提前结束循环
                if orders_header_row is not None and deals_header_row is not None:
                    break
            
            # 提取订单数据
            orders_df = None
            if orders_header_row is not None:
                # 提取列名
                column_names = []
                for j, val in enumerate(df.iloc[orders_header_row].values):
                    if pd.notna(val):
                        column_names.append(str(val))
                    else:
                        column_names.append(f"Column_{j}")
                
                # 确定订单数据的结束行
                orders_end_row = len(df)
                if deals_header_row is not None and deals_header_row > orders_header_row:
                    orders_end_row = deals_header_row
                
                # 提取数据行
                orders_data = []
                for i in range(orders_header_row + 1, orders_end_row):
                    row_values = df.iloc[i].values
                    non_na_count = sum(1 for x in row_values if pd.notna(x))
                    
                    # 如果行中有足够多的非空值，添加到数据中
                    if non_na_count >= 2:
                        # 添加数据行
                        row_data = {}
                        for j, val in enumerate(row_values):
                            if j < len(column_names):
                                row_data[column_names[j]] = val
                        
                        orders_data.append(row_data)
                
                # 创建DataFrame
                if orders_data:
                    orders_df = pd.DataFrame(orders_data)
                    logger.info(f"成功提取订单数据，包含 {len(orders_df)} 行")
                else:
                    logger.warning("未找到有效的订单数据行")
            else:
                logger.warning("未找到订单表头行")
            
            # 提取成交记录数据
            deals_df = None
            if deals_header_row is not None:
                # 提取列名
                column_names = []
                for j, val in enumerate(df.iloc[deals_header_row].values):
                    if pd.notna(val):
                        column_names.append(str(val))
                    else:
                        column_names.append(f"Column_{j}")
                
                # 提取数据行
                deals_data = []
                for i in range(deals_header_row + 1, len(df)):
                    row_values = df.iloc[i].values
                    non_na_count = sum(1 for x in row_values if pd.notna(x))
                    
                    # 如果行中有足够多的非空值，添加到数据中
                    if non_na_count >= 2:
                        # 添加数据行
                        row_data = {}
                        for j, val in enumerate(row_values):
                            if j < len(column_names):
                                row_data[column_names[j]] = val
                        
                        deals_data.append(row_data)
                
                # 创建DataFrame
                if deals_data:
                    deals_df = pd.DataFrame(deals_data)
                    logger.info(f"成功提取成交记录数据，包含 {len(deals_df)} 行")
                else:
                    logger.warning("未找到有效的成交记录数据行")
            else:
                logger.warning("未找到成交记录表头行")
            
            return orders_df, deals_df
            
        except Exception as e:
            logger.exception(f"从Excel文件提取数据失败: {e}")
            return None, None
    
    def extract_numeric_value(self, value):
        """
        从字符串中提取数值
        
        Args:
            value: 输入值
            
        Returns:
            float: 提取的数值，如果无法提取则返回None
        """
        if pd.isna(value):
            return None
        
        if isinstance(value, (int, float)):
            return float(value)
        
        # 尝试从字符串中提取数值
        if isinstance(value, str):
            # 移除货币符号和逗号
            value = value.replace(',', '')
            
            # 尝试直接转换
            try:
                return float(value)
            except ValueError:
                pass
            
            # 尝试使用正则表达式提取数值
            match = re.search(r'[-+]?\d*\.\d+|\d+', value)
            if match:
                try:
                    return float(match.group())
                except ValueError:
                    pass
        
        return None
    
    def process_orders(self, orders_df, report_file):
        """
        处理订单数据并写入数据库
        
        Args:
            orders_df (DataFrame): 订单数据
            report_file (str): 报告文件名
            
        Returns:
            int: 成功插入的记录数
        """
        if orders_df is None or len(orders_df) == 0:
            logger.warning("订单数据为空，跳过处理")
            return 0
        
        # 准备SQL语句
        insert_query = """
        INSERT INTO mt5_strategy_orders 
        (order_id, symbol, type, time, open_price, volume, sl, tp, comment, report_file)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """
        
        # 插入数据
        count = 0
        try:
            for _, row in orders_df.iterrows():
                # 尝试提取订单号
                order_id = None
                for col in orders_df.columns:
                    col_lower = str(col).lower()
                    if '订单' in col_lower or 'order' in col_lower or '#' in col_lower:
                        value = row[col]
                        if pd.notna(value):
                            try:
                                order_id = int(float(value))
                                break
                            except (ValueError, TypeError):
                                continue
                
                # 如果没有找到订单号，跳过此行
                if order_id is None:
                    continue
                
                # 提取其他字段
                symbol = ""
                order_type = ""
                order_time = datetime.datetime.now()
                open_price = 0.0
                volume = 0.0
                sl = 0.0
                tp = 0.0
                comment = ""
                
                # 遍历列查找匹配的字段
                for col in orders_df.columns:
                    col_lower = str(col).lower()
                    value = row[col]
                    
                    if pd.isna(value):
                        continue
                    
                    # 交易品种
                    if '品种' in col_lower or 'symbol' in col_lower:
                        symbol = str(value)
                    
                    # 类型
                    elif '类型' in col_lower or 'type' in col_lower:
                        order_type = str(value)
                    
                    # 时间
                    elif '时间' in col_lower or 'time' in col_lower:
                        if isinstance(value, datetime.datetime):
                            order_time = value
                        elif isinstance(value, str):
                            try:
                                order_time = datetime.datetime.strptime(value, '%Y.%m.%d %H:%M:%S')
                            except ValueError:
                                try:
                                    order_time = datetime.datetime.strptime(value, '%Y-%m-%d %H:%M:%S')
                                except ValueError:
                                    pass
                    
                    # 价格
                    elif '价格' in col_lower or 'price' in col_lower:
                        open_price = self.extract_numeric_value(value) or 0.0
                    
                    # 交易量
                    elif '交易量' in col_lower or 'volume' in col_lower or 'lot' in col_lower:
                        volume = self.extract_numeric_value(value) or 0.0
                    
                    # 止损
                    elif '止损' in col_lower or 's/l' in col_lower or 'sl' in col_lower:
                        sl = self.extract_numeric_value(value) or 0.0
                    
                    # 止盈
                    elif '止盈' in col_lower or 't/p' in col_lower or 'tp' in col_lower:
                        tp = self.extract_numeric_value(value) or 0.0
                    
                    # 注释
                    elif '注释' in col_lower or 'comment' in col_lower:
                        comment = str(value)
                
                values = (
                    order_id,
                    symbol,
                    order_type,
                    order_time,
                    open_price,
                    volume,
                    sl,
                    tp,
                    comment,
                    report_file
                )
                
                self.cursor.execute(insert_query, values)
                count += 1
            
            self.conn.commit()
            logger.info(f"成功插入{count}条订单记录")
            return count
        except Error as e:
            logger.error(f"插入订单数据失败: {e}")
            self.conn.rollback()
            return 0
    
    def process_deals(self, deals_df, report_file):
        """
        处理成交记录并写入数据库
        
        Args:
            deals_df (DataFrame): 成交记录数据
            report_file (str): 报告文件名
            
        Returns:
            int: 成功插入的记录数
        """
        if deals_df is None or len(deals_df) == 0:
            logger.warning("成交记录数据为空，跳过处理")
            return 0
        
        # 准备SQL语句
        insert_query = """
        INSERT INTO mt5_strategy_deals 
        (deal_id, order_id, symbol, type, direction, time, price, volume, profit, commission, swap, comment, report_file)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """
        
        # 插入数据
        count = 0
        try:
            for _, row in deals_df.iterrows():
                # 尝试提取成交号
                deal_id = None
                for col in deals_df.columns:
                    col_lower = str(col).lower()
                    if '成交' in col_lower or 'deal' in col_lower or '#' in col_lower:
                        value = row[col]
                        if pd.notna(value):
                            try:
                                deal_id = int(float(value))
                                break
                            except (ValueError, TypeError):
                                continue
                
                # 如果没有找到成交号，尝试使用行索引作为成交号
                if deal_id is None:
                    deal_id = count + 1
                
                # 提取其他字段
                order_id = 0
                symbol = ""
                deal_type = ""
                direction = ""
                deal_time = datetime.datetime.now()
                price = 0.0
                volume = 0.0
                profit = 0.0
                commission = 0.0
                swap = 0.0
                comment = ""
                
                # 遍历列查找匹配的字段
                for col in deals_df.columns:
                    col_lower = str(col).lower()
                    value = row[col]
                    
                    if pd.isna(value):
                        continue
                    
                    # 订单号
                    if '订单' in col_lower or 'order' in col_lower:
                        order_id = self.extract_numeric_value(value) or 0
                    
                    # 交易品种
                    elif '品种' in col_lower or 'symbol' in col_lower:
                        symbol = str(value)
                    
                    # 类型
                    elif '类型' in col_lower or 'type' in col_lower:
                        deal_type = str(value)
                    
                    # 方向
                    elif '方向' in col_lower or 'direction' in col_lower:
                        direction = str(value)
                    
                    # 时间
                    elif '时间' in col_lower or 'time' in col_lower:
                        if isinstance(value, datetime.datetime):
                            deal_time = value
                        elif isinstance(value, str):
                            try:
                                deal_time = datetime.datetime.strptime(value, '%Y.%m.%d %H:%M:%S')
                            except ValueError:
                                try:
                                    deal_time = datetime.datetime.strptime(value, '%Y-%m-%d %H:%M:%S')
                                except ValueError:
                                    pass
                    
                    # 价格
                    elif '价格' in col_lower or 'price' in col_lower:
                        price = self.extract_numeric_value(value) or 0.0
                    
                    # 交易量
                    elif '交易量' in col_lower or 'volume' in col_lower or 'lot' in col_lower:
                        volume = self.extract_numeric_value(value) or 0.0
                    
                    # 利润
                    elif '利润' in col_lower or 'profit' in col_lower:
                        profit = self.extract_numeric_value(value) or 0.0
                    
                    # 手续费
                    elif '手续费' in col_lower or 'commission' in col_lower:
                        commission = self.extract_numeric_value(value) or 0.0
                    
                    # 掉期
                    elif '掉期' in col_lower or 'swap' in col_lower:
                        swap = self.extract_numeric_value(value) or 0.0
                    
                    # 注释
                    elif '注释' in col_lower or 'comment' in col_lower:
                        comment = str(value)
                
                values = (
                    deal_id,
                    int(order_id),
                    symbol,
                    deal_type,
                    direction,
                    deal_time,
                    price,
                    volume,
                    profit,
                    commission,
                    swap,
                    comment,
                    report_file
                )
                
                self.cursor.execute(insert_query, values)
                count += 1
            
            self.conn.commit()
            logger.info(f"成功插入{count}条成交记录")
            return count
        except Error as e:
            logger.error(f"插入成交记录失败: {e}")
            self.conn.rollback()
            return 0
    
    def process_report(self, file_path):
        """
        处理策略报告
        
        Args:
            file_path (str): Excel文件路径
            
        Returns:
            tuple: (orders_count, deals_count) 成功插入的订单和成交记录数
        """
        # 获取文件名
        report_file = os.path.basename(file_path)
        logger.info(f"开始处理报告文件: {report_file}")
        
        # 从Excel文件提取数据
        orders_df, deals_df = self.extract_data_from_excel(file_path)
        
        # 连接数据库
        if not self.connect_db():
            return 0, 0
        
        # 创建表
        if not self.create_tables():
            self.close_db()
            return 0, 0
        
        # 处理订单数据
        orders_count = self.process_orders(orders_df, report_file)
        
        # 处理成交记录
        deals_count = self.process_deals(deals_df, report_file)
        
        # 关闭数据库连接
        self.close_db()
        
        logger.info(f"报告处理完成: 插入{orders_count}条订单记录，{deals_count}条成交记录")
        return orders_count, deals_count


def main():
    """主函数"""
    # 获取脚本所在目录
    script_dir = Path(__file__).parent.absolute()
    
    # 默认Excel文件路径
    default_file = script_dir / "ReportTester.xlsx"
    
    # 解析命令行参数
    if len(sys.argv) > 1:
        file_path = sys.argv[1]
    else:
        file_path = str(default_file)
    
    # 检查文件是否存在
    if not os.path.exists(file_path):
        logger.error(f"文件不存在: {file_path}")
        return
    
    # 创建解析器并处理报告
    parser = MT5ReportParser()
    orders_count, deals_count = parser.process_report(file_path)
    
    logger.info(f"处理完成: 插入{orders_count}条订单记录，{deals_count}条成交记录")


if __name__ == "__main__":
    main()