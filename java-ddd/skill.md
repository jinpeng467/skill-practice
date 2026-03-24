# DDD领域划分工具

## 功能描述
这是一个基于shell脚本的工具，用于根据输入的业务描述进行DDD（领域驱动设计）领域划分。工具能够：
1. 分析业务描述文本
2. 识别核心领域、支撑子域、通用子域
3. 划分限界上下文
4. 生成领域模型图（使用PlantUML）

## 安装要求
- Bash shell环境
- PlantUML（用于生成图表）：
  ```bash
  # 安装PlantUML
  npm install -g plantuml  # 或使用其他安装方式
  # 或安装Java版本
  # 下载 plantuml.jar
  ```

## 使用方法
```bash
# 基本用法
./ddd-analyzer.sh "业务描述文本"

# 从文件读取业务描述
./ddd-analyzer.sh -f business-description.txt

# 指定输出目录
./ddd-analyzer.sh -o output/ "业务描述文本"

# 详细模式
./ddd-analyzer.sh -v "业务描述文本"

# 生成JSON格式结果
./ddd-analyzer.sh -j "业务描述文本"
```

## 输入格式
工具接受以下格式的输入：
1. 直接字符串参数
2. 文本文件（-f选项）
3. 标准输入（管道）

业务描述应包含：
- 业务目标和价值
- 主要业务流程
- 关键实体和关系
- 用户角色和交互

## 输出内容
工具生成以下内容：
1. 领域分析报告（文本格式）
2. 限界上下文划分（JSON格式）
3. 领域模型图（PNG格式）
4. 上下文映射图（PNG格式）

## 文件结构
```
.
├── ddd-analyzer.sh          # 主脚本
├── skill.md                 # 本文档
├── examples/               # 示例目录
│   ├── ecommerce/         # 电商示例
│   ├── banking/           # 银行系统示例
│   └── hospital/          # 医院系统示例
└── lib/                   # 工具库
    ├── domain_parser.sh   # 领域解析逻辑
    ├── diagram_generator.sh # 图表生成
    └── template/          # 模板文件
```

## 示例
```bash
# 电商系统分析
./ddd-analyzer.sh "这是一个电商系统，包含用户管理、商品管理、订单处理、支付结算、物流跟踪等功能。用户可以分为买家和卖家，买家可以浏览商品、下订单、支付；卖家可以管理商品、处理订单、查看销售统计。"

# 输出结果示例：
# - ddd-report.txt      # 详细分析报告
# - contexts.json       # 限界上下文定义
# - domain-model.png    # 领域模型图
# - context-map.png     # 上下文映射图
```

## 算法原理
1. **文本预处理**：分词、词性标注、实体识别
2. **实体提取**：识别名词短语作为候选实体
3. **关系分析**：分析动词和介词短语确定实体关系
4. **聚类分析**：基于实体关系进行上下文划分
5. **模式匹配**：识别常见的DDD模式（聚合、值对象等）

## 自定义配置
通过环境变量配置：
```bash
export DDD_PLANTUML_PATH=/path/to/plantuml.jar
export DDD_OUTPUT_FORMAT=json  # 或 text, html
export DDD_LANG=zh  # 或 en
```

## 故障排除
1. **PlantUML未安装**：安装PlantUML或设置DDD_PLANTUML_PATH
2. **权限问题**：确保脚本有执行权限 `chmod +x ddd-analyzer.sh`
3. **内存不足**：减少输入文本长度或使用更简单的模式

## 贡献指南
欢迎提交PR改进：
1. 添加新的业务领域模板
2. 改进自然语言处理算法
3. 增加输出格式支持
4. 优化性能