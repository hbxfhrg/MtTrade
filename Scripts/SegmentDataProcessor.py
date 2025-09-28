#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
线段数据处理器
专门用于从segment_info.csv中读取线段信息数据，并保存到MySQL数据库
"""

import pandas as pd
import mysql.connector
from mysql.connector import Error
import datetime
import logging
import os

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("SegmentDataProcessor.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("SegmentDataProcessor")

class SegmentDataProcessor:
    """线段数据处理器"""
    
    def __init__(self, db_config):
        """
        初始化处理器
        
        Args:
            db_config (dict): 数据库配置
        """
        self.db_config = db_config
        self.conn = None
        self.cursor = None
    
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
        """创建线段信息表"""
        try:
            # 创建线段信息表（更新为新的格式）
            self.cursor.execute("""
            CREATE TABLE IF NOT EXISTS segment_info (
                id INT AUTO_INCREMENT PRIMARY KEY,
                trade_time DATETIME COMMENT '交易时间',
                order_ticket BIGINT COMMENT '订单号',
                position_id BIGINT COMMENT '仓位ID',
                reference_price DOUBLE COMMENT '参考价格',
                reference_time DATETIME COMMENT '参考时间',
                reference_bar_index INT COMMENT '参考K线索引',
                timeframe VARCHAR(10) COMMENT '时间周期',
                segment_side VARCHAR(10) COMMENT '线段方向（Left/Right）',
                segment_index INT COMMENT '线段序号',
                start_price DOUBLE COMMENT '起始价格',
                end_price DOUBLE COMMENT '结束价格',
                amplitude DOUBLE COMMENT '幅度',
                direction VARCHAR(10) COMMENT '方向',
                trade_action VARCHAR(20) COMMENT '交易操作类型',
                trade_price DOUBLE COMMENT '交易价格',
                trade_volume DOUBLE COMMENT '交易量',
                trade_comment VARCHAR(255) COMMENT '交易注释',
                trade_status VARCHAR(50) COMMENT '交易状态',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间'
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            """)
            
            self.conn.commit()
            logger.info("数据表创建成功")
            return True
        except Exception as e:
            logger.error(f"创建数据表失败: {e}")
            self.conn.rollback()
            return False
    
    def read_segment_data(self, file_path):
        """
        从CSV文件中读取线段数据
        
        Args:
            file_path (str): CSV文件路径
            
        Returns:
            DataFrame: 线段数据的DataFrame
        """
        try:
            # 读取segment_info.csv文件
            df = pd.read_csv(file_path, sep=';', encoding='utf-16')
            logger.info(f"成功读取线段数据文件，包含 {len(df)} 行数据")
            logger.info(f"列名: {list(df.columns)}")
            return df
        except Exception as e:
            logger.error(f"读取线段数据文件失败: {e}")
            return None
    
    def save_segments_to_db(self, segments_df):
        """
        将线段数据保存到数据库
        
        Args:
            segments_df (DataFrame): 线段数据
            
        Returns:
            int: 成功插入的记录数
        """
        if segments_df is None or len(segments_df) == 0:
            logger.warning("线段数据为空，跳过保存到数据库")
            return 0
        
        try:
            insert_query = """
            INSERT INTO segment_info 
            (trade_time, order_ticket, position_id, reference_price, reference_time, 
             reference_bar_index, timeframe, segment_side, segment_index, start_price,
             end_price, amplitude, direction, trade_action, trade_price, trade_volume,
             trade_comment, trade_status)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """
            
            count = 0
            for idx, row in segments_df.iterrows():
                # 提取各字段值
                trade_time = None
                order_ticket = None
                position_id = None
                reference_price = 0.0
                reference_time = None
                reference_bar_index = 0
                timeframe = ""
                segment_side = ""
                segment_index = 0
                start_price = 0.0
                end_price = 0.0
                amplitude = 0.0
                direction = ""
                trade_action = ""
                trade_price = 0.0
                trade_volume = 0.0
                trade_comment = ""
                trade_status = ""
                
                # 处理时间字段
                if 'TradeTime' in row and pd.notna(row['TradeTime']):
                    try:
                        trade_time = datetime.datetime.strptime(row['TradeTime'], '%Y.%m.%d %H:%M:%S')
                    except ValueError:
                        pass
                
                if 'ReferenceTime' in row and pd.notna(row['ReferenceTime']):
                    try:
                        reference_time = datetime.datetime.strptime(row['ReferenceTime'], '%Y.%m.%d %H:%M:%S')
                    except ValueError:
                        pass
                
                # 处理其他字段
                if 'OrderTicket' in row and pd.notna(row['OrderTicket']):
                    order_ticket = int(row['OrderTicket'])
                
                if 'PositionId' in row and pd.notna(row['PositionId']):
                    position_id = int(row['PositionId'])
                
                if 'ReferencePrice' in row and pd.notna(row['ReferencePrice']):
                    reference_price = float(row['ReferencePrice'])
                
                if 'ReferenceBarIndex' in row and pd.notna(row['ReferenceBarIndex']):
                    reference_bar_index = int(row['ReferenceBarIndex'])
                
                if 'Timeframe' in row and pd.notna(row['Timeframe']):
                    timeframe = str(row['Timeframe'])
                
                if 'SegmentSide' in row and pd.notna(row['SegmentSide']):
                    segment_side = str(row['SegmentSide'])
                
                if 'SegmentIndex' in row and pd.notna(row['SegmentIndex']):
                    segment_index = int(row['SegmentIndex'])
                
                if 'StartPrice' in row and pd.notna(row['StartPrice']):
                    start_price = float(row['StartPrice'])
                
                if 'EndPrice' in row and pd.notna(row['EndPrice']):
                    end_price = float(row['EndPrice'])
                
                if 'Amplitude' in row and pd.notna(row['Amplitude']):
                    amplitude = float(row['Amplitude'])
                
                if 'Direction' in row and pd.notna(row['Direction']):
                    direction = str(row['Direction'])
                    
                # 新增的交易操作相关字段
                if 'TradeAction' in row and pd.notna(row['TradeAction']):
                    trade_action = str(row['TradeAction'])
                
                if 'TradePrice' in row and pd.notna(row['TradePrice']):
                    trade_price = float(row['TradePrice'])
                
                if 'TradeVolume' in row and pd.notna(row['TradeVolume']):
                    trade_volume = float(row['TradeVolume'])
                
                if 'TradeComment' in row and pd.notna(row['TradeComment']):
                    trade_comment = str(row['TradeComment'])
                
                if 'TradeStatus' in row and pd.notna(row['TradeStatus']):
                    trade_status = str(row['TradeStatus'])
                
                values = (
                    trade_time,
                    order_ticket,
                    position_id,
                    reference_price,
                    reference_time,
                    reference_bar_index,
                    timeframe,
                    segment_side,
                    segment_index,
                    start_price,
                    end_price,
                    amplitude,
                    direction,
                    trade_action,
                    trade_price,
                    trade_volume,
                    trade_comment,
                    trade_status
                )
                
                self.cursor.execute(insert_query, values)
                count += 1
            
            self.conn.commit()
            logger.info(f"成功将{count}条线段记录保存到数据库")
            return count
            
        except Error as e:
            logger.error(f"保存线段数据到数据库失败: {e}")
            self.conn.rollback()
            return 0
    
    def clear_segment_database(self):
        """清除数据库中的线段数据"""
        try:
            # 清除线段表数据
            self.cursor.execute("DELETE FROM segment_info")
            segments_deleted = self.cursor.rowcount
            
            self.conn.commit()
            logger.info(f"已清除数据库中的线段数据: {segments_deleted} 条记录")
        except Error as e:
            logger.error(f"清除数据库线段数据失败: {e}")
            self.conn.rollback()
            raise