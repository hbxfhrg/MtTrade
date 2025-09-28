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
            
            # 处理所有订单，而不仅仅是已成交的仓位
            logger.info(f"处理所有 {len(orders_df)} 条订单记录")
            
            # 首先处理有position_id的已成交订单（进场/出场对）
            # 从线段表中获取所有有效的position_id（大于0的）
            valid_positions = segments_df[segments_df['position_id'] > 0]['position_id'].unique()
            logger.info(f"找到 {len(valid_positions)} 个有效的仓位ID")
            
            # 处理每个仓位
            processed_order_ids = set()  # 记录已处理的订单ID
            
            for position_id in valid_positions:
                # 获取该仓位的所有线段记录
                position_segments = segments_df[segments_df['position_id'] == position_id]
                
                # 获取该仓位涉及的所有订单票号
                order_tickets = position_segments['order_ticket'].unique()
                processed_order_ids.update(order_tickets)
                
                # 获取这些订单票号对应的订单记录
                position_orders = orders_df[orders_df['order_id'].isin(order_tickets)]
                
                # 获取这些订单对应的成交记录
                position_deals = deals_df[deals_df['order_id'].isin(order_tickets)]
                
                # 确定进场和出场订单
                entry_order = None
                exit_order = None
                
                if len(position_orders) >= 2:
                    # 按时间排序确定进场和出场
                    sorted_orders = position_orders.sort_values('open_time')
                    entry_order = sorted_orders.iloc[0]
                    exit_order = sorted_orders.iloc[1]
                elif len(position_orders) == 1:
                    # 只有一个订单
                    entry_order = position_orders.iloc[0]
                
                # 创建汇总记录
                if entry_order is not None:
                    summary_record = {
                        'position_id': position_id,
                        'symbol': entry_order['symbol'],
                        'order_type': entry_order['type'],
                        'volume': entry_order['volume'],
                        'open_price': entry_order['price'],
                        'sl': entry_order['sl'],
                        'tp': entry_order['tp'],
                        'open_time': entry_order['open_time'],
                        'status': entry_order['status'],
                        'comment': entry_order['comment']
                    }
                    
                    # 如果有出场订单，添加出场信息
                    if exit_order is not None:
                        summary_record['order_id'] = exit_order['order_id']
                        summary_record['close_time'] = exit_order['time']
                        summary_record['close_price'] = exit_order['price']
                        # 合并状态
                        profit_value = 0
                        if not position_deals.empty:
                            profit_value = position_deals['profit'].sum()
                        summary_record['status'] = self._merge_status(entry_order['status'], exit_order['status'], profit_value)
                        summary_record['comment'] = f"{entry_order['comment']} | {exit_order['comment']}"
                    else:
                        summary_record['order_id'] = entry_order['order_id']
                        summary_record['close_time'] = entry_order['time']
                        summary_record['close_price'] = entry_order['price']
                    
                    # 添加成交相关信息
                    if not position_deals.empty:
                        # 计算总手续费、库存费和盈利
                        summary_record['commission'] = position_deals['commission'].sum()
                        summary_record['swap'] = position_deals['swap'].sum()
                        summary_record['profit'] = position_deals['profit'].sum()
                        
                        # 获取最后一条成交记录的信息
                        last_deal = position_deals.iloc[-1]
                        summary_record['close_price'] = last_deal['price']
                        summary_record['close_time'] = last_deal['deal_time']
                        summary_record['comment'] = last_deal['comment']
                    
                    # 添加线段相关信息
                    if not position_segments.empty:
                        # 分离进场和出场的线段
                        entry_segments = pd.DataFrame()
                        exit_segments = pd.DataFrame()
                        
                        if entry_order is not None:
                            entry_segments = position_segments[position_segments['order_ticket'] == entry_order['order_id']]
                        
                        if exit_order is not None:
                            exit_segments = position_segments[position_segments['order_ticket'] == exit_order['order_id']]
                        
                        # 进场线段统计
                        if not entry_segments.empty:
                            summary_record['entry_right_segments_5min'] = len(entry_segments[
                                (entry_segments['timeframe'] == 'M5') & 
                                (entry_segments['segment_side'] == 'Right')
                            ])
                            
                            summary_record['entry_right_segments_15min'] = len(entry_segments[
                                (entry_segments['timeframe'] == 'M15') & 
                                (entry_segments['segment_side'] == 'Right')
                            ])
                            
                            summary_record['entry_right_segments_30min'] = len(entry_segments[
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
                                summary_record['entry_first_segment_length'] = round(abs(
                                    first_entry_segment['end_price'] - first_entry_segment['start_price']
                                ), 2)
                        
                        # 出场线段统计
                        if not exit_segments.empty:
                            summary_record['exit_right_segments_5min'] = len(exit_segments[
                                (exit_segments['timeframe'] == 'M5') & 
                                (exit_segments['segment_side'] == 'Right')
                            ])
                            
                            summary_record['exit_right_segments_15min'] = len(exit_segments[
                                (exit_segments['timeframe'] == 'M15') & 
                                (exit_segments['segment_side'] == 'Right')
                            ])
                            
                            summary_record['exit_right_segments_30min'] = len(exit_segments[
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
                                summary_record['exit_first_segment_length'] = round(abs(
                                    first_exit_segment['end_price'] - first_exit_segment['start_price']
                                ), 2)
                    
                    summary_list.append(summary_record)
            
            # 处理未成交的订单（没有position_id关联的订单）
            logger.info(f"已处理 {len(processed_order_ids)} 条订单，剩余 {len(orders_df) - len(processed_order_ids)} 条未处理订单")
            unprocessed_orders = orders_df[~orders_df['order_id'].isin(processed_order_ids)]
            
            for _, order_row in unprocessed_orders.iterrows():
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
                profit_value = 0
                if not order_deals.empty:
                    # 计算总手续费、库存费和盈利
                    summary_record['commission'] = order_deals['commission'].sum()
                    summary_record['swap'] = order_deals['swap'].sum()
                    summary_record['profit'] = order_deals['profit'].sum()
                    profit_value = order_deals['profit'].sum()
                    
                    # 获取最后一条成交记录的注释作为平仓注释
                    summary_record['comment'] = order_deals.iloc[-1]['comment']
                    
                    # 获取平仓价格和时间
                    summary_record['close_price'] = order_deals.iloc[-1]['price']
                    summary_record['close_time'] = order_deals.iloc[-1]['deal_time']
                
                # 根据盈利金额更新状态
                summary_record['status'] = self._merge_status(order_row['status'], order_row['status'], profit_value)
                
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
                        summary_record['first_segment_length'] = round(abs(
                            first_right_segment['end_price'] - first_right_segment['start_price']
                        ), 2)
                
                summary_list.append(summary_record)
            
            # 转换为DataFrame
            summary_df = pd.DataFrame(summary_list)
            logger.info(f"处理完成，共生成 {len(summary_df)} 条汇总记录")
            return summary_df
            
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
        # 由于我们已经在_process_summary_data中处理了合并逻辑，这里直接返回
        return summary_df
    
    def _merge_status(self, entry_status, exit_status, profit=0):
        """
        合并订单状态
        
        Args:
            entry_status (str): 进场状态
            exit_status (str): 出场状态
            profit (float): 盈利金额
            
        Returns:
            str: 合并后的状态
        """
        # 如果任意一个是取消，则为取消
        if 'cancel' in str(entry_status).lower() or 'cancel' in str(exit_status).lower():
            return '取消'
        
        # 如果任意一个是过期，则为过期
        if 'expired' in str(entry_status).lower() or 'expired' in str(exit_status).lower():
            return '过期'
        
        # 根据盈利金额判断状态
        if profit > 0:
            return '盈利'
        elif profit < 0:
            return '亏损'
        else:
            return '持平'
        
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