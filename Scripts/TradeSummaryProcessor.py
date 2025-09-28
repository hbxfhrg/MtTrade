#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
交易数据汇总处理器
专门用于将订单表、成交表和线段表数据汇总成一个综合分析表
"""

import pandas as pd
import mysql.connector
from mysql.connector import Error
import logging
from collections import defaultdict

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("TradeSummaryProcessor.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("TradeSummaryProcessor")

class TradeSummaryProcessor:
    """交易数据汇总处理器"""
    
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
    
    def create_summary_table(self):
        """创建汇总表"""
        try:
            # 创建汇总表
            self.cursor.execute("""
            CREATE TABLE IF NOT EXISTS trade_summary (
                id INT AUTO_INCREMENT PRIMARY KEY,
                order_id BIGINT COMMENT '订单号',
                position_id BIGINT COMMENT '仓位ID',
                symbol VARCHAR(20) COMMENT '交易品种',
                order_type VARCHAR(50) COMMENT '订单类型',
                volume VARCHAR(20) COMMENT '交易量',
                open_price DOUBLE COMMENT '开仓价格',
                close_price DOUBLE COMMENT '平仓价格',
                sl DOUBLE COMMENT '止损',
                tp DOUBLE COMMENT '止盈',
                open_time DATETIME COMMENT '开仓时间',
                close_time DATETIME COMMENT '平仓时间',
                status VARCHAR(20) COMMENT '订单状态',
                commission DOUBLE COMMENT '手续费',
                swap DOUBLE COMMENT '库存费',
                profit DOUBLE COMMENT '盈利',
                comment VARCHAR(255) COMMENT '注释',
                right_segments_5min INT COMMENT '5分钟右线段数量',
                right_segments_15min INT COMMENT '15分钟右线段数量',
                right_segments_30min INT COMMENT '30分钟右线段数量',
                first_segment_length DOUBLE COMMENT '第一个线段长度',
                entry_right_segments_5min INT COMMENT '进场5分钟右线段数量',
                entry_right_segments_15min INT COMMENT '进场15分钟右线段数量',
                entry_right_segments_30min INT COMMENT '进场30分钟右线段数量',
                exit_right_segments_5min INT COMMENT '出场5分钟右线段数量',
                exit_right_segments_15min INT COMMENT '出场15分钟右线段数量',
                exit_right_segments_30min INT COMMENT '出场30分钟右线段数量',
                entry_first_segment_length DOUBLE COMMENT '进场第一个线段长度',
                exit_first_segment_length DOUBLE COMMENT '出场第一个线段长度',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间'
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            """)
            
            self.conn.commit()
            logger.info("汇总表创建成功")
            return True
        except Exception as e:
            logger.error(f"创建汇总表失败: {e}")
            self.conn.rollback()
            return False
    
    def generate_summary_data(self):
        """
        生成汇总数据
        以订单表为主表，关联成交表和线段表数据
        """
        try:
            # 读取订单表数据
            orders_query = """
            SELECT 
                order_id, symbol, type, volume, price, sl, tp, open_time, time, status, comment
            FROM report_orders
            """
            orders_df = pd.read_sql(orders_query, self.conn)
            logger.info(f"读取订单数据 {len(orders_df)} 条")
            
            # 读取成交表数据
            deals_query = """
            SELECT 
                deal_id, symbol, type, direction, volume, price, order_id, commission, swap, profit, balance, comment, deal_time
            FROM report_deals
            """
            deals_df = pd.read_sql(deals_query, self.conn)
            logger.info(f"读取成交数据 {len(deals_df)} 条")
            
            # 读取线段表数据
            segments_query = """
            SELECT 
                order_ticket, position_id, reference_price, reference_time, timeframe, 
                segment_side, segment_index, start_price, end_price, amplitude, direction,
                trade_action, trade_price, trade_volume, trade_comment, trade_status
            FROM segment_info
            """
            segments_df = pd.read_sql(segments_query, self.conn)
            logger.info(f"读取线段数据 {len(segments_df)} 条")
            
            # 处理数据汇总
            summary_data = self._process_summary_data(orders_df, deals_df, segments_df)
            
            return summary_data
            
        except Exception as e:
            logger.error(f"生成汇总数据失败: {e}")
            return None
    
    def _process_summary_data(self, orders_df, deals_df, segments_df):
        """
        处理汇总数据
        
        Args:
            orders_df (DataFrame): 订单数据
            deals_df (DataFrame): 成交数据
            segments_df (DataFrame): 线段数据
        """
        try:
            # 创建汇总数据列表
            summary_list = []
            
            # 按订单号分组处理数据
            for _, order_row in orders_df.iterrows():
                order_id = order_row['order_id']
                
                # 获取该订单的成交记录
                order_deals = deals_df[deals_df['order_id'] == order_id]
                
                # 获取该订单的线段记录
                order_segments = segments_df[segments_df['order_ticket'] == order_id]
                
                # 创建汇总记录
                summary_record = {
                    'order_id': order_id,
                    'symbol': order_row['symbol'],
                    'order_type': order_row['type'],
                    'volume': order_row['volume'],
                    'open_price': order_row['price'],
                    'sl': order_row['sl'],
                    'tp': order_row['tp'],
                    'open_time': order_row['open_time'],
                    'close_time': order_row['time'],
                    'status': order_row['status'],
                    'comment': order_row['comment']
                }
                
                # 添加成交相关信息
                if not order_deals.empty:
                    # 计算总手续费、库存费和盈利
                    summary_record['commission'] = order_deals['commission'].sum()
                    summary_record['swap'] = order_deals['swap'].sum()
                    summary_record['profit'] = order_deals['profit'].sum()
                    
                    # 获取最后一条成交记录的注释作为平仓注释
                    summary_record['comment'] = order_deals.iloc[-1]['comment']
                    
                    # 获取平仓价格和时间
                    summary_record['close_price'] = order_deals.iloc[-1]['price']
                    summary_record['close_time'] = order_deals.iloc[-1]['deal_time']
                
                # 添加线段相关信息
                if not order_segments.empty:
                    # 按时间周期统计右线段数量
                    right_segments_5min = len(order_segments[
                        (order_segments['timeframe'] == 'M5') & 
                        (order_segments['segment_side'] == 'Right')
                    ])
                    
                    right_segments_15min = len(order_segments[
                        (order_segments['timeframe'] == 'M15') & 
                        (order_segments['segment_side'] == 'Right')
                    ])
                    
                    right_segments_30min = len(order_segments[
                        (order_segments['timeframe'] == 'M30') & 
                        (order_segments['segment_side'] == 'Right')
                    ])
                    
                    summary_record['right_segments_5min'] = right_segments_5min
                    summary_record['right_segments_15min'] = right_segments_15min
                    summary_record['right_segments_30min'] = right_segments_30min
                    
                    # 获取参考点价格右侧第一个线段的长度
                    first_right_segment = order_segments[
                        (order_segments['segment_side'] == 'Right')
                    ].sort_values('segment_index').iloc[0] if not order_segments[
                        (order_segments['segment_side'] == 'Right')
                    ].empty else None
                    
                    if first_right_segment is not None:
                        summary_record['first_segment_length'] = abs(
                            first_right_segment['end_price'] - first_right_segment['start_price']
                        )
                
                summary_list.append(summary_record)
            
            # 转换为DataFrame
            summary_df = pd.DataFrame(summary_list)
            
            # 按position_id合并进场和出场数据
            merged_summary_df = self._merge_entry_exit_data(summary_df, segments_df)
            
            return merged_summary_df
            
        except Exception as e:
            logger.error(f"处理汇总数据失败: {e}")
            return None
    
    def _merge_entry_exit_data(self, summary_df, segments_df):
        """
        将进场和出场数据合并成一行
        
        Args:
            summary_df (DataFrame): 汇总数据
            segments_df (DataFrame): 线段数据
        """
        try:
            # 按position_id分组
            merged_list = []
            position_groups = summary_df.groupby('position_id') if 'position_id' in summary_df.columns else []
            
            # 如果没有position_id字段，则按订单号处理
            if len(position_groups) == 0:
                return summary_df
            
            for position_id, group in position_groups:
                if len(group) == 1:
                    # 只有一条记录，直接添加
                    merged_list.append(group.iloc[0])
                else:
                    # 有多条记录，需要合并
                    entry_record = None
                    exit_record = None
                    
                    # 确定进场和出场记录
                    for _, record in group.iterrows():
                        if 'entry' in str(record['comment']).lower() or 'in' in str(record['comment']).lower():
                            entry_record = record
                        elif 'exit' in str(record['comment']).lower() or 'out' in str(record['comment']).lower():
                            exit_record = record
                    
                    # 如果无法通过注释确定，则按时间排序
                    if entry_record is None or exit_record is None:
                        sorted_group = group.sort_values('open_time')
                        if len(sorted_group) >= 2:
                            entry_record = sorted_group.iloc[0]
                            exit_record = sorted_group.iloc[1]
                        else:
                            # 只有一条记录
                            merged_list.append(group.iloc[0])
                            continue
                    
                    # 创建合并记录
                    merged_record = {
                        'order_id': entry_record['order_id'],
                        'position_id': position_id,
                        'symbol': entry_record['symbol'],
                        'order_type': entry_record['order_type'],
                        'volume': entry_record['volume'],
                        'open_price': entry_record['open_price'],
                        'close_price': exit_record['close_price'] if not pd.isna(exit_record['close_price']) else entry_record['close_price'],
                        'sl': entry_record['sl'],
                        'tp': entry_record['tp'],
                        'open_time': entry_record['open_time'],
                        'close_time': exit_record['close_time'] if not pd.isna(exit_record['close_time']) else entry_record['close_time'],
                        'status': self._merge_status(entry_record['status'], exit_record['status']),
                        'commission': (entry_record['commission'] if not pd.isna(entry_record['commission']) else 0) + 
                                     (exit_record['commission'] if not pd.isna(exit_record['commission']) else 0),
                        'swap': (entry_record['swap'] if not pd.isna(entry_record['swap']) else 0) + 
                               (exit_record['swap'] if not pd.isna(exit_record['swap']) else 0),
                        'profit': (entry_record['profit'] if not pd.isna(entry_record['profit']) else 0) + 
                                 (exit_record['profit'] if not pd.isna(exit_record['profit']) else 0),
                        'comment': f"{entry_record['comment']} | {exit_record['comment']}"
                    }
                    
                    # 添加进场和出场的线段统计信息
                    entry_segments = segments_df[segments_df['order_ticket'] == entry_record['order_id']]
                    exit_segments = segments_df[segments_df['order_ticket'] == exit_record['order_id']]
                    
                    # 进场线段统计
                    if not entry_segments.empty:
                        merged_record['entry_right_segments_5min'] = len(entry_segments[
                            (entry_segments['timeframe'] == 'M5') & 
                            (entry_segments['segment_side'] == 'Right')
                        ])
                        
                        merged_record['entry_right_segments_15min'] = len(entry_segments[
                            (entry_segments['timeframe'] == 'M15') & 
                            (entry_segments['segment_side'] == 'Right')
                        ])
                        
                        merged_record['entry_right_segments_30min'] = len(entry_segments[
                            (entry_segments['timeframe'] == 'M30') & 
                            (entry_segments['segment_side'] == 'Right')
                        ])
                        
                        # 进场第一个线段长度
                        first_entry_segment = entry_segments[
                            (entry_segments['segment_side'] == 'Right')
                        ].sort_values('segment_index').iloc[0] if not entry_segments[
                            (entry_segments['segment_side'] == 'Right')
                        ].empty else None
                        
                        if first_entry_segment is not None:
                            merged_record['entry_first_segment_length'] = abs(
                                first_entry_segment['end_price'] - first_entry_segment['start_price']
                            )
                    
                    # 出场线段统计
                    if not exit_segments.empty:
                        merged_record['exit_right_segments_5min'] = len(exit_segments[
                            (exit_segments['timeframe'] == 'M5') & 
                            (exit_segments['segment_side'] == 'Right')
                        ])
                        
                        merged_record['exit_right_segments_15min'] = len(exit_segments[
                            (exit_segments['timeframe'] == 'M15') & 
                            (exit_segments['segment_side'] == 'Right')
                        ])
                        
                        merged_record['exit_right_segments_30min'] = len(exit_segments[
                            (exit_segments['timeframe'] == 'M30') & 
                            (exit_segments['segment_side'] == 'Right')
                        ])
                        
                        # 出场第一个线段长度
                        first_exit_segment = exit_segments[
                            (exit_segments['segment_side'] == 'Right')
                        ].sort_values('segment_index').iloc[0] if not exit_segments[
                            (exit_segments['segment_side'] == 'Right')
                        ].empty else None
                        
                        if first_exit_segment is not None:
                            merged_record['exit_first_segment_length'] = abs(
                                first_exit_segment['end_price'] - first_exit_segment['start_price']
                            )
                    
                    merged_list.append(merged_record)
            
            # 转换为DataFrame
            merged_df = pd.DataFrame(merged_list)
            return merged_df
            
        except Exception as e:
            logger.error(f"合并进场出场数据失败: {e}")
            return summary_df
    
    def _merge_status(self, entry_status, exit_status):
        """
        合并订单状态
        
        Args:
            entry_status (str): 进场状态
            exit_status (str): 出场状态
            
        Returns:
            str: 合并后的状态
        """
        # 如果任意一个是取消，则为取消
        if 'cancel' in str(entry_status).lower() or 'cancel' in str(exit_status).lower():
            return '取消'
        
        # 如果任意一个是亏损，则为亏损
        if 'loss' in str(entry_status).lower() or 'loss' in str(exit_status).lower():
            return '亏损'
        
        # 如果任意一个是盈利，则为盈利
        if 'profit' in str(entry_status).lower() or 'profit' in str(exit_status).lower():
            return '盈利'
        
        # 默认返回原始状态
        return entry_status if not pd.isna(entry_status) else exit_status
    
    def save_summary_to_db(self, summary_df):
        """
        将汇总数据保存到数据库
        
        Args:
            summary_df (DataFrame): 汇总数据
            
        Returns:
            int: 成功插入的记录数
        """
        if summary_df is None or len(summary_df) == 0:
            logger.warning("汇总数据为空，跳过保存到数据库")
            return 0
        
        try:
            # 先清除现有数据
            self.cursor.execute("DELETE FROM trade_summary")
            
            # 插入新数据
            insert_query = """
            INSERT INTO trade_summary 
            (order_id, position_id, symbol, order_type, volume, open_price, close_price, sl, tp, 
             open_time, close_time, status, commission, swap, profit, comment,
             right_segments_5min, right_segments_15min, right_segments_30min, first_segment_length,
             entry_right_segments_5min, entry_right_segments_15min, entry_right_segments_30min,
             exit_right_segments_5min, exit_right_segments_15min, exit_right_segments_30min,
             entry_first_segment_length, exit_first_segment_length)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """
            
            count = 0
            for _, row in summary_df.iterrows():
                values = (
                    row.get('order_id'),
                    row.get('position_id'),
                    row.get('symbol'),
                    row.get('order_type'),
                    row.get('volume'),
                    row.get('open_price'),
                    row.get('close_price'),
                    row.get('sl'),
                    row.get('tp'),
                    row.get('open_time'),
                    row.get('close_time'),
                    row.get('status'),
                    row.get('commission', 0),
                    row.get('swap', 0),
                    row.get('profit', 0),
                    row.get('comment'),
                    row.get('right_segments_5min', 0),
                    row.get('right_segments_15min', 0),
                    row.get('right_segments_30min', 0),
                    row.get('first_segment_length', 0),
                    row.get('entry_right_segments_5min', 0),
                    row.get('entry_right_segments_15min', 0),
                    row.get('entry_right_segments_30min', 0),
                    row.get('exit_right_segments_5min', 0),
                    row.get('exit_right_segments_15min', 0),
                    row.get('exit_right_segments_30min', 0),
                    row.get('entry_first_segment_length', 0),
                    row.get('exit_first_segment_length', 0)
                )
                
                self.cursor.execute(insert_query, values)
                count += 1
            
            self.conn.commit()
            logger.info(f"成功将 {count} 条汇总记录保存到数据库")
            return count
            
        except Error as e:
            logger.error(f"保存汇总数据到数据库失败: {e}")
            self.conn.rollback()
            return 0
    
    def save_summary_to_csv(self, summary_df, csv_path="trade_summary.csv"):
        """
        将汇总数据保存为CSV文件
        
        Args:
            summary_df (DataFrame): 汇总数据
            csv_path (str): CSV文件路径
        """
        try:
            if summary_df is not None and not summary_df.empty:
                summary_df.to_csv(csv_path, index=False, encoding='utf-8-sig')
                logger.info(f"汇总数据已保存到 {csv_path}")
                return True
            else:
                logger.warning("汇总数据为空，未保存")
                return False
        except Exception as e:
            logger.error(f"保存汇总数据为CSV文件失败: {e}")
            return False
    
    def clear_summary_database(self):
        """清除汇总表中的所有数据"""
        try:
            # 清除汇总表数据
            self.cursor.execute("DELETE FROM trade_summary")
            deleted_count = self.cursor.rowcount
            
            self.conn.commit()
            logger.info(f"已清除汇总表中的数据: {deleted_count} 条记录")
        except Error as e:
            logger.error(f"清除汇总表数据失败: {e}")
            self.conn.rollback()
            raise