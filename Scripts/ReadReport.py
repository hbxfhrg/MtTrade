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

# 导入我们新创建的处理器模块
from TradeDataProcessor import TradeDataProcessor
from SegmentDataProcessor import SegmentDataProcessor
from TradeSummaryProcessor import TradeSummaryProcessor

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
        
        # 初始化数据处理器
        self.trade_processor = TradeDataProcessor(self.db_config)
        self.segment_processor = SegmentDataProcessor(self.db_config)
        self.summary_processor = TradeSummaryProcessor(self.db_config)
        
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
        
        # 交易历史操作框架
        trade_frame = tk.LabelFrame(main_frame, text="交易历史操作 - 读取和保存交易订单及成交记录", padx=5, pady=5)
        trade_frame.pack(fill=tk.X, pady=(0, 10))
        
        # 交易历史操作按钮
        tk.Button(trade_frame, text="读取交易历史", command=self.read_data, bg="#4CAF50", fg="white").pack(side=tk.LEFT, padx=(0, 5))
        tk.Button(trade_frame, text="保存CSV", command=self.save_csv, bg="#2196F3", fg="white").pack(side=tk.LEFT, padx=(0, 5))
        tk.Button(trade_frame, text="保存数据库", command=self.save_database, bg="#FF9800", fg="white").pack(side=tk.LEFT, padx=(0, 5))
        tk.Button(trade_frame, text="清空日志", command=self.clear_log, bg="#F44336", fg="white").pack(side=tk.LEFT)
        
        # 线段数据操作框架
        segment_frame = tk.LabelFrame(main_frame, text="线段数据操作 - 读取和保存线段信息数据", padx=5, pady=5)
        segment_frame.pack(fill=tk.X, pady=(0, 10))
        
        # 线段操作按钮
        tk.Button(segment_frame, text="读取线段列表", command=self.read_segment_data, bg="#9C27B0", fg="white").pack(side=tk.LEFT, padx=(0, 5))
        tk.Button(segment_frame, text="写入线段表", command=self.save_segment_database, bg="#607D8B", fg="white").pack(side=tk.LEFT, padx=(0, 5))
        
        # 汇总数据操作框架
        summary_frame = tk.LabelFrame(main_frame, text="汇总数据操作 - 生成订单、成交和线段综合分析数据", padx=5, pady=5)
        summary_frame.pack(fill=tk.X, pady=(0, 10))
        
        # 汇总操作按钮
        tk.Button(summary_frame, text="生成汇总表", command=self.generate_summary_data, bg="#FF5722", fg="white").pack(side=tk.LEFT, padx=(0, 5))
        tk.Button(summary_frame, text="保存汇总CSV", command=self.save_summary_csv, bg="#FF9800", fg="white").pack(side=tk.LEFT, padx=(0, 5))
        tk.Button(summary_frame, text="保存汇总数据库", command=self.save_summary_database, bg="#FFC107", fg="white").pack(side=tk.LEFT, padx=(0, 5))
        
        # 日志显示框架
        log_frame = tk.LabelFrame(main_frame, text="运行日志", padx=5, pady=5)
        log_frame.pack(fill=tk.BOTH, expand=True)
        
        # 日志文本框
        self.log_text = scrolledtext.ScrolledText(log_frame, height=20)
        self.log_text.pack(fill=tk.BOTH, expand=True)
        
        # 添加说明文本
        info_text = """
使用说明：
1. 在"交易历史操作"框中点击"读取交易历史"按钮选择并读取ReportTester.xlsx文件中的订单和成交记录
2. 在"交易历史操作"框中点击"保存CSV"按钮将数据保存为CSV文件
3. 在"交易历史操作"框中点击"保存数据库"按钮将数据保存到MySQL数据库
4. 在"交易历史操作"框中点击"清空日志"按钮清空日志显示
5. 在"线段数据操作"框中点击"读取线段列表"按钮选择并读取线段信息数据
6. 在"线段数据操作"框中点击"写入线段表"按钮将线段信息保存到数据库
        """
        tk.Label(main_frame, text=info_text, justify=tk.LEFT, fg="blue").pack(fill=tk.X, pady=(10, 0))
    
    def clear_log(self):
        """清空日志"""
        self.log_text.delete(1.0, tk.END)
    
    def read_data(self):
        """读取交易历史数据"""
        try:
            # 获取当前应用程序目录
            initial_dir = os.path.dirname(os.path.abspath(__file__)) if '__file__' in globals() else os.getcwd()
            
            # 让用户选择Excel文件
            file_path = filedialog.askopenfilename(
                title="选择交易历史Excel文件",
                initialdir=initial_dir,
                filetypes=[("Excel文件", "*.xlsx"), ("所有文件", "*.*")]
            )
            
            # 如果用户取消选择，直接返回
            if not file_path:
                return
            
            # 检查文件是否存在
            if not os.path.exists(file_path):
                messagebox.showerror("错误", f"文件不存在: {file_path}")
                return
            
            # 读取Excel文件
            logger.info("开始读取交易历史数据...")
            self.orders_df, self.deals_df = self.trade_processor.read_order_deal_data(file_path)
            logger.info("交易历史数据读取完成")
            messagebox.showinfo("成功", "交易历史数据读取完成")
        except Exception as e:
            logger.error(f"读取交易历史数据失败: {e}")
            messagebox.showerror("错误", f"读取交易历史数据失败: {e}")
    
    def save_csv(self):
        """保存CSV"""
        if not hasattr(self, 'orders_df') or not hasattr(self, 'deals_df'):
            messagebox.showerror("错误", "请先读取数据")
            return
        
        try:
            # 获取当前应用程序目录
            initial_dir = os.path.dirname(os.path.abspath(__file__)) if '__file__' in globals() else os.getcwd()
            
            # 选择保存目录
            save_dir = filedialog.askdirectory(title="选择保存目录", initialdir=initial_dir)
            if not save_dir:
                return
            
            orders_csv_path = os.path.join(save_dir, "orders.csv")
            deals_csv_path = os.path.join(save_dir, "deals.csv")
            
            self.trade_processor.save_to_csv(self.orders_df, self.deals_df, orders_csv_path, deals_csv_path)
            logger.info(f"CSV文件已保存到: {save_dir}")
            messagebox.showinfo("成功", f"CSV文件已保存到: {save_dir}")
        except Exception as e:
            logger.error(f"保存CSV失败: {e}")
            messagebox.showerror("错误", f"保存CSV失败: {e}")
    
    def save_database(self):
        """保存到数据库"""
        if not hasattr(self, 'orders_df') or not hasattr(self, 'deals_df'):
            messagebox.showerror("错误", "请先读取交易历史数据")
            return
        
        try:
            logger.info("开始保存到数据库...")
            if self.trade_processor.connect_db():
                if self.trade_processor.create_tables():
                    # 在保存新数据之前清除现有数据
                    self.trade_processor.clear_database()
                    # 使用默认文件名，因为我们现在不保存文件路径
                    orders_count = self.trade_processor.save_orders_to_db(self.orders_df, "ReportTester.xlsx")
                    deals_count = self.trade_processor.save_deals_to_db(self.deals_df, "ReportTester.xlsx")
                    logger.info(f"成功将 {orders_count} 条订单记录和 {deals_count} 条成交记录保存到数据库")
                    messagebox.showinfo("成功", f"成功将 {orders_count} 条订单记录和 {deals_count} 条成交记录保存到数据库")
                self.trade_processor.close_db()
            else:
                logger.error("无法连接到数据库")
                messagebox.showerror("错误", "无法连接到数据库")
        except Exception as e:
            logger.error(f"保存到数据库失败: {e}")
            messagebox.showerror("错误", f"保存到数据库失败: {e}")
    
    def read_segment_data(self):
        """读取线段数据"""
        try:
            # 获取当前应用程序目录
            initial_dir = os.path.dirname(os.path.abspath(__file__)) if '__file__' in globals() else os.getcwd()
            
            # 让用户选择segment_info.csv文件
            file_path = filedialog.askopenfilename(
                title="选择线段数据文件",
                initialdir=initial_dir,
                filetypes=[("CSV文件", "*.csv"), ("所有文件", "*.*")]
            )
            
            # 如果用户取消选择，直接返回
            if not file_path:
                return
            
            # 检查文件是否存在
            if not os.path.exists(file_path):
                messagebox.showerror("错误", f"线段信息文件不存在: {file_path}")
                return
            
            # 读取segment_info.csv文件
            self.segments_df = self.segment_processor.read_segment_data(file_path)
            if self.segments_df is not None:
                logger.info(f"成功读取线段数据，共 {len(self.segments_df)} 条记录")
                messagebox.showinfo("成功", f"成功读取线段数据，共 {len(self.segments_df)} 条记录")
            else:
                logger.error("读取线段数据失败")
                messagebox.showerror("错误", "读取线段数据失败")
        except Exception as e:
            logger.error(f"读取线段数据失败: {e}")
            messagebox.showerror("错误", f"读取线段数据失败: {e}")
    
    def save_segment_database(self):
        """保存线段数据到数据库"""
        if not hasattr(self, 'segments_df'):
            messagebox.showerror("错误", "请先读取线段数据")
            return
        
        try:
            logger.info("开始保存线段数据到数据库...")
            if self.segment_processor.connect_db():
                if self.segment_processor.create_tables():
                    # 在保存新数据之前清除现有线段数据
                    self.segment_processor.clear_segment_database()
                    segments_count = self.segment_processor.save_segments_to_db(self.segments_df)
                    logger.info(f"成功将 {segments_count} 条线段记录保存到数据库")
                    messagebox.showinfo("成功", f"成功将 {segments_count} 条线段记录保存到数据库")
                self.segment_processor.close_db()
            else:
                logger.error("无法连接到数据库")
                messagebox.showerror("错误", "无法连接到数据库")
        except Exception as e:
            logger.error(f"保存线段数据到数据库失败: {e}")
            messagebox.showerror("错误", f"保存线段数据到数据库失败: {e}")

    def generate_summary_data(self):
        """生成汇总数据"""
        try:
            logger.info("开始生成汇总数据...")
            if self.summary_processor.connect_db():
                # 创建汇总表
                if self.summary_processor.create_summary_table():
                    # 生成汇总数据
                    self.summary_df = self.summary_processor.generate_summary_data()
                    if self.summary_df is not None:
                        logger.info(f"成功生成汇总数据，共 {len(self.summary_df)} 条记录")
                        messagebox.showinfo("成功", f"成功生成汇总数据，共 {len(self.summary_df)} 条记录")
                    else:
                        logger.error("生成汇总数据失败")
                        messagebox.showerror("错误", "生成汇总数据失败")
                else:
                    logger.error("创建汇总表失败")
                    messagebox.showerror("错误", "创建汇总表失败")
                self.summary_processor.close_db()
            else:
                logger.error("无法连接到数据库")
                messagebox.showerror("错误", "无法连接到数据库")
        except Exception as e:
            logger.error(f"生成汇总数据失败: {e}")
            messagebox.showerror("错误", f"生成汇总数据失败: {e}")

    def save_summary_csv(self):
        """保存汇总数据为CSV"""
        if not hasattr(self, 'summary_df'):
            messagebox.showerror("错误", "请先生成汇总数据")
            return
        
        try:
            # 获取当前应用程序目录
            initial_dir = os.path.dirname(os.path.abspath(__file__)) if '__file__' in globals() else os.getcwd()
            
            # 选择保存目录
            save_dir = filedialog.askdirectory(title="选择保存目录", initialdir=initial_dir)
            if not save_dir:
                return
            
            summary_csv_path = os.path.join(save_dir, "trade_summary.csv")
            
            if self.summary_processor.save_summary_to_csv(self.summary_df, summary_csv_path):
                logger.info(f"汇总数据CSV文件已保存到: {summary_csv_path}")
                messagebox.showinfo("成功", f"汇总数据CSV文件已保存到: {summary_csv_path}")
            else:
                logger.error("保存汇总数据CSV文件失败")
                messagebox.showerror("错误", "保存汇总数据CSV文件失败")
        except Exception as e:
            logger.error(f"保存汇总数据CSV失败: {e}")
            messagebox.showerror("错误", f"保存汇总数据CSV失败: {e}")

    def save_summary_database(self):
        """保存汇总数据到数据库"""
        if not hasattr(self, 'summary_df'):
            messagebox.showerror("错误", "请先生成汇总数据")
            return
        
        try:
            logger.info("开始保存汇总数据到数据库...")
            if self.summary_processor.connect_db():
                # 创建汇总表
                if self.summary_processor.create_summary_table():
                    # 清除现有数据并保存新数据
                    self.summary_processor.clear_summary_database()
                    summary_count = self.summary_processor.save_summary_to_db(self.summary_df)
                    logger.info(f"成功将 {summary_count} 条汇总记录保存到数据库")
                    messagebox.showinfo("成功", f"成功将 {summary_count} 条汇总记录保存到数据库")
                else:
                    logger.error("创建汇总表失败")
                    messagebox.showerror("错误", "创建汇总表失败")
                self.summary_processor.close_db()
            else:
                logger.error("无法连接到数据库")
                messagebox.showerror("错误", "无法连接到数据库")
        except Exception as e:
            logger.error(f"保存汇总数据到数据库失败: {e}")
            messagebox.showerror("错误", f"保存汇总数据到数据库失败: {e}")

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