# MtTrade - MT5 ZigZag 高级交易分析系统

## 项目概述

MtTrade 是一个基于 MetaTrader 5 平台的智能交易分析系统，通过多周期 ZigZag 指标实现市场结构分析、交易区间识别和趋势判断。系统采用模块化架构，支持实时图形化显示和深度技术分析。

## 核心功能

- **多周期 ZigZag 分析**：支持 5M、1H、4H 等多时间周期
- **智能线段管理**：自动识别主线段和子线段结构
- **支撑阻力分析**：动态识别关键价格水平
- **交易区间识别**：自动检测有效的交易区间
- **实时图形显示**：可视化标记峰谷点、线段和信息面板
- **缓存优化**：高效计算减少资源消耗

## 系统架构

### 核心计算模块
- **ZigzagCalculator.mqh** - ZigZag 指标核心计算引擎
- **ZigzagExtremumPoint.mqh** - 极值点数据模型
- **ZigzagSegment.mqh** - 线段数据结构
- **ZigzagSegmentManager.mqh** - 线段生命周期管理

### 交易分析模块  
- **TradeAnalyzer.mqh** - 主交易分析逻辑
- **SupportResistancePoint.mqh** - 支撑阻力点分析
- **DynamicPricePoint.mqh** - 动态价格点管理

### 图形显示模块
- **Graphics/InfoPanelManager.mqh** - 信息面板管理
- **Graphics/LabelManager.mqh** - 文本标签管理  
- **Graphics/LineManager.mqh** - 线条绘制管理
- **Graphics/ShapeManager.mqh** - 图形形状管理
- **Graphics/ExtremumPointDrawer.mqh** - 极值点绘制
- **Graphics/SegmentDrawer.mqh** - 线段绘制

### 工具模块
- **CommonUtils.mqh** - 通用工具函数
- **ConfigManager.mqh** - 配置管理
- **LogUtil.mqh** - 日志记录工具
- **GlobalInstances.mqh** - 全局实例管理
- **EnumDefinitions.mqh** - 枚举定义

## 安装使用

1. 将所有文件复制到 `MQL5/Experts/MtTrade/` 目录
2. 重启 MT5 或刷新导航器
3. 将 `MyZigzag` 指标拖放到图表
4. 根据需要调整输入参数

## 输入参数

- **InpShowLabels** - 显示极值点标签 (默认: true)
- **InpLabelColor** - 1H子线段标签颜色 (默认: clrWhite)  
- **InpLabel4HColor** - 4H主线段标签颜色 (默认: clrOrange)
- **InpShowInfoPanel** - 显示信息面板 (默认: true)
- **InpInfoPanelColor** - 面板文字颜色 (默认: clrWhite)
- **InpInfoPanelBgColor** - 面板背景颜色 (默认: clrNavy)
- **InpShowPenetratedPoints** - 显示已失效价格点 (默认: false)

## 技术特性

- **模块化设计**：各功能模块独立，便于维护和扩展
- **对象导向**：采用面向对象编程，代码结构清晰
- **性能优化**：缓存机制减少重复计算
- **多周期协同**：支持不同时间周期的协同分析
- **实时更新**：自动适应市场变化和新K线

## 开发说明

项目采用严格的代码规范，每个模块职责单一，便于团队协作和后续功能扩展。图形显示与业务逻辑完全分离，支持在不同类型的交易系统中复用核心分析功能。

## 支持文档

- `MyZigzag重构说明.md` - 系统重构详细说明
- `4H_测试说明.md` - 4H周期测试指南  
- `调试说明_主线段和子线段.md` - 线段调试指南