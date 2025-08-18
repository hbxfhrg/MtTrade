# MtTrade - MT5 ZigZag 交易分析工具

## 项目概述

MtTrade 是一个基于 MetaTrader 5 (MT5) 平台的交易分析工具集，主要功能是通过 ZigZag 指标识别市场的峰谷点，并提供交易区间分析、趋势方向判断等功能。该工具可以帮助交易者更好地理解市场结构，识别潜在的交易机会。

## 主要功能

- 多周期 ZigZag 计算（小周期、中周期、大周期）
- 交易区间自动识别与分析
- 趋势方向判断
- 价格位置分析（在区间中的位置百分比）
- 图形化显示（峰谷点标记、信息面板等）

## 文件结构

- **MyZigzag.mq5**: 主指标文件，实现了多周期 ZigZag 计算和显示功能
- **ZigzagCalculator.mqh**: ZigZag 计算核心类，负责计算不同周期的 ZigZag 值
- **ZigzagExtremumPoint.mqh**: 极点类定义，用于存储和处理 ZigZag 的峰谷点信息
- **GraphicsUtils.mqh**: 图形工具类，用于绘制各种图形元素（标签、线条、面板等）
- **TradeAnalyzer.mqh**: 交易分析类，用于分析交易区间、趋势方向等
- **CommonUtils.mqh**: 通用工具类，提供各种辅助功能
- **TradeInfoPanel.mqh**: 交易信息面板类（注：功能已移至 GraphicsUtils.mqh）

## 类设计

### CZigzagCalculator 类
负责计算 ZigZag 指标值，可以处理不同周期的数据。

### CZigzagExtremumPoint 类
表示 ZigZag 的极点（峰值或谷值），存储极点的时间、价格、类型等信息。

### CInfoPanelManager 类
负责创建和管理信息面板，显示市场分析结果。主要功能包括：
- 创建信息面板
- 创建交易信息面板
- 创建简单信息面板

### CLabelManager 类
负责创建和管理文本标签，用于在图表上标记重要价格点。

### CLineManager 类
负责创建和管理线条，用于在图表上绘制趋势线等。

### CShapeManager 类
负责创建和管理图形，如矩形、三角形等。

### CTradeAnalyzer 类
负责分析交易区间、趋势方向等，提供交易决策支持。

## 使用方法

1. 将所有文件复制到 MT5 的 MQL5/Indicators 目录下
2. 重启 MT5 或刷新指标列表
3. 将 MyZigzag 指标添加到图表
4. 通过指标参数设置调整显示效果和计算参数

## 参数设置

- **InpDepth**: ZigZag 深度参数
- **InpDeviation**: ZigZag 偏差参数
- **InpBackstep**: ZigZag 回溯步数
- **InpShowLabels**: 是否显示峰谷值文本标签
- **InpLabelColor**: 标签文本颜色
- **InpShow5M**: 是否计算 5 分钟周期 ZigZag（小周期）
- **InpShow4H**: 是否显示 4 小时周期 ZigZag（大周期）
- **InpLabel4HColor**: 4 小时周期标签颜色
- **InpCacheTimeout**: 缓存超时时间（秒）
- **InpMaxBarsH1**: 1 小时周期最大计算 K 线数
- **InpShowInfoPanel**: 是否显示信息面板
- **InpInfoPanelColor**: 信息面板文字颜色
- **InpInfoPanelBgColor**: 信息面板背景颜色

## 代码结构优化

项目采用模块化设计，将不同功能分离到不同的类和文件中，使得代码结构清晰，便于维护和扩展：

1. **核心计算与数据处理**: ZigzagCalculator.mqh, ZigzagExtremumPoint.mqh
2. **图形界面与显示**: GraphicsUtils.mqh
3. **交易分析与决策**: TradeAnalyzer.mqh
4. **通用工具与辅助功能**: CommonUtils.mqh

这种设计使得各个组件可以独立开发和测试，同时也便于在不同项目中重用。例如，交易分析功能可以在不需要图形界面的 EA 中直接使用。

## 版本历史

### v1.0.0
- 初始版本，实现基本的 ZigZag 计算和显示功能

### v1.1.0
- 添加多周期支持（5M、当前周期、4H）
- 添加交易区间分析功能

### v1.2.0
- 添加信息面板显示
- 优化代码结构，实现模块化设计

### v1.3.0
- 重构图形类，将创建面板的方法移至 GraphicsUtils.mqh
- 优化性能，添加缓存机制减少计算量