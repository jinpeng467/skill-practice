#!/bin/bash

# DDD领域划分工具
# 根据业务描述进行领域驱动设计分析

set -e

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${PWD}/ddd-output"
PLANTUML_CMD="plantuml"
VERBOSE=0
JSON_OUTPUT=0
INPUT_FILE=""
BUSINESS_DESCRIPTION=""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印帮助信息
print_help() {
    cat << EOF
DDD领域划分工具 v${VERSION}

用法: $0 [选项] [业务描述]

选项:
  -f, --file FILE        从文件读取业务描述
  -o, --output DIR       指定输出目录（默认: ./ddd-output）
  -v, --verbose          详细模式，显示更多信息
  -j, --json             生成JSON格式输出
  -h, --help             显示此帮助信息
  -V, --version          显示版本信息

示例:
  $0 "这是一个电商系统，包含用户管理、商品管理、订单处理等功能"
  $0 -f business.txt -o ./analysis
  $0 -v -j "银行系统，包含账户管理、转账、贷款等功能"

如果没有提供业务描述，工具会从标准输入读取。
EOF
}

# 打印版本信息
print_version() {
    echo "DDD领域划分工具 v${VERSION}"
}

# 打印带颜色的消息
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# 检查依赖
check_dependencies() {
    local missing_deps=0

    # 检查PlantUML
    if ! command -v plantuml &> /dev/null; then
        if [[ -f "$DDD_PLANTUML_PATH" ]]; then
            PLANTUML_CMD="java -jar $DDD_PLANTUML_PATH"
        else
            log_warning "PlantUML未安装。图表生成功能将不可用。"
            log_warning "安装方法: npm install -g plantuml"
            log_warning "或设置DDD_PLANTUML_PATH环境变量指向plantuml.jar"
            PLANTUML_CMD=""
        fi
    fi

    # 检查其他工具
    for cmd in jq awk sed; do
        if ! command -v $cmd &> /dev/null; then
            log_error "需要命令: $cmd"
            missing_deps=1
        fi
    done

    if [[ $missing_deps -eq 1 ]]; then
        log_error "请安装缺失的依赖后重试。"
        exit 1
    fi
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_help
                exit 0
                ;;
            -V|--version)
                print_version
                exit 0
                ;;
            -f|--file)
                INPUT_FILE="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -j|--json)
                JSON_OUTPUT=1
                shift
                ;;
            --)
                shift
                break
                ;;
            -*)
                log_error "未知选项: $1"
                print_help
                exit 1
                ;;
            *)
                BUSINESS_DESCRIPTION="$1"
                shift
                ;;
        esac
    done

    # 如果还有参数，合并为业务描述
    if [[ $# -gt 0 ]]; then
        if [[ -z "$BUSINESS_DESCRIPTION" ]]; then
            BUSINESS_DESCRIPTION="$*"
        else
            BUSINESS_DESCRIPTION="$BUSINESS_DESCRIPTION $*"
        fi
    fi

    # 如果没有业务描述且没有输入文件，尝试从标准输入读取
    if [[ -z "$BUSINESS_DESCRIPTION" && -z "$INPUT_FILE" ]]; then
        if [[ -t 0 ]]; then
            # 终端中没有输入
            log_error "错误: 需要提供业务描述"
            print_help
            exit 1
        else
            # 从管道读取
            log_info "从标准输入读取业务描述..."
            BUSINESS_DESCRIPTION=$(cat)
        fi
    fi
}

# 从文件读取业务描述
read_from_file() {
    if [[ ! -f "$INPUT_FILE" ]]; then
        log_error "文件不存在: $INPUT_FILE"
        exit 1
    fi

    BUSINESS_DESCRIPTION=$(cat "$INPUT_FILE")
    if [[ $VERBOSE -eq 1 ]]; then
        log_info "从文件读取内容: ${#BUSINESS_DESCRIPTION} 字符"
    fi
}

# 初始化输出目录
init_output_dir() {
    mkdir -p "$OUTPUT_DIR"
    if [[ $VERBOSE -eq 1 ]]; then
        log_info "输出目录: $OUTPUT_DIR"
    fi
}

# 分析业务描述
analyze_business_description() {
    local description="$1"

    if [[ $VERBOSE -eq 1 ]]; then
        log_info "开始分析业务描述..."
        log_info "描述长度: ${#description} 字符"
    fi

    # 简单的实体提取（实际实现会更复杂）
    echo "$description" | awk '{
        gsub(/[.,。，！!?？；;:"'"'"']/, " ")
        for(i=1; i<=NF; i++) {
            if(length($i) > 1 && !($i ~ /^[0-9]+$/)) {
                print $i
            }
        }
    }' | sort | uniq -c | sort -nr > "$OUTPUT_DIR/entities.txt"

    # 提取动词（关系）
    echo "$description" | awk '{
        gsub(/[.,。，！!?？；;:"'"'"']/, " ")
        for(i=1; i<=NF; i++) {
            if($i ~ /^[管理处理查看浏览下支付包含可以分为]$/) {
                print $i
            }
        }
    }' | sort | uniq -c | sort -nr > "$OUTPUT_DIR/verbs.txt"
}

# 识别核心领域
identify_core_domains() {
    local description="$1"

    # 常见核心领域关键词
    local core_keywords="订单 商品 用户 账户 支付 交易 产品 服务 客户"
    local support_keywords="管理 统计 报表 日志 配置 权限 消息 通知"
    local generic_keywords="时间 地址 文件 图片 文档 数据 信息"

    echo "# 领域分析报告" > "$OUTPUT_DIR/domain-report.txt"
    echo "生成时间: $(date)" >> "$OUTPUT_DIR/domain-report.txt"
    echo "业务描述: ${description:0:100}..." >> "$OUTPUT_DIR/domain-report.txt"
    echo "" >> "$OUTPUT_DIR/domain-report.txt"

    echo "## 核心领域" >> "$OUTPUT_DIR/domain-report.txt"
    for keyword in $core_keywords; do
        if echo "$description" | grep -q "$keyword"; then
            echo "- $keyword" >> "$OUTPUT_DIR/domain-report.txt"
        fi
    done

    echo "" >> "$OUTPUT_DIR/domain-report.txt"
    echo "## 支撑子域" >> "$OUTPUT_DIR/domain-report.txt"
    for keyword in $support_keywords; do
        if echo "$description" | grep -q "$keyword"; then
            echo "- $keyword" >> "$OUTPUT_DIR/domain-report.txt"
        fi
    done

    echo "" >> "$OUTPUT_DIR/domain-report.txt"
    echo "## 通用子域" >> "$OUTPUT_DIR/domain-report.txt"
    for keyword in $generic_keywords; do
        if echo "$description" | grep -q "$keyword"; then
            echo "- $keyword" >> "$OUTPUT_DIR/domain-report.txt"
        fi
    done
}

# 划分限界上下文
identify_bounded_contexts() {
    # 简单示例：基于常见模式划分
    cat > "$OUTPUT_DIR/contexts.json" << EOF
{
  "version": "1.0",
  "generated_at": "$(date -Iseconds)",
  "bounded_contexts": [
    {
      "name": "用户管理上下文",
      "type": "core",
      "responsibilities": ["用户注册", "用户认证", "权限管理"],
      "entities": ["用户", "角色", "权限"]
    },
    {
      "name": "商品管理上下文",
      "type": "core",
      "responsibilities": ["商品发布", "商品分类", "库存管理"],
      "entities": ["商品", "分类", "库存"]
    },
    {
      "name": "订单处理上下文",
      "type": "core",
      "responsibilities": ["订单创建", "订单状态管理", "订单查询"],
      "entities": ["订单", "订单项", "收货地址"]
    }
  ]
}
EOF
}

# 生成领域模型图
generate_domain_diagram() {
    if [[ -z "$PLANTUML_CMD" ]]; then
        log_warning "跳过图表生成: PlantUML未安装"
        return
    fi

    log_info "生成领域模型图..."

    cat > "$OUTPUT_DIR/domain-model.puml" << EOF
@startuml
title 领域模型图

package "用户管理" {
  class 用户 {
    +ID
    +用户名
    +密码
    +邮箱
    +注册时间
  }

  class 角色 {
    +ID
    +名称
    +权限列表
  }

  用户 "1" -- "*" 角色 : 拥有
}

package "商品管理" {
  class 商品 {
    +ID
    +名称
    +价格
    +库存
    +描述
  }

  class 分类 {
    +ID
    +名称
    +父分类
  }

  商品 "1" -- "1" 分类 : 属于
}

package "订单处理" {
  class 订单 {
    +ID
    +用户ID
    +总金额
    +状态
    +创建时间
  }

  class 订单项 {
    +ID
    +商品ID
    +数量
    +单价
  }

  订单 "1" -- "*" 订单项 : 包含
}

用户 "1" -- "*" 订单 : 创建
商品 "1" -- "*" 订单项 : 被购买

@enduml
EOF

    $PLANTUML_CMD "$OUTPUT_DIR/domain-model.puml" 2>/dev/null || true
}

# 生成上下文映射图
generate_context_map() {
    if [[ -z "$PLANTUML_CMD" ]]; then
        return
    fi

    log_info "生成上下文映射图..."

    cat > "$OUTPUT_DIR/context-map.puml" << EOF
@startuml
title 限界上下文映射图

[用户管理上下文] as [UM]
[商品管理上下文] as [PM]
[订单处理上下文] as [OM]

[UM] --> [OM] : 用户信息
[PM] --> [OM] : 商品信息

note right of [UM]
  核心领域
  处理用户相关业务
end note

note right of [PM]
  核心领域
  处理商品相关业务
end note

note right of [OM]
  核心领域
  处理订单生命周期
end note

@enduml
EOF

    $PLANTUML_CMD "$OUTPUT_DIR/context-map.puml" 2>/dev/null || true
}

# 生成JSON输出
generate_json_output() {
    if [[ $JSON_OUTPUT -eq 1 ]]; then
        log_info "生成JSON格式输出..."
        jq . "$OUTPUT_DIR/contexts.json" > "$OUTPUT_DIR/contexts-pretty.json"
    fi
}

# 主函数
main() {
    parse_args "$@"

    if [[ -n "$INPUT_FILE" ]]; then
        read_from_file
    fi

    if [[ -z "$BUSINESS_DESCRIPTION" ]]; then
        log_error "错误: 没有业务描述可分析"
        exit 1
    fi

    check_dependencies
    init_output_dir

    log_info "开始DDD领域分析..."

    analyze_business_description "$BUSINESS_DESCRIPTION"
    identify_core_domains "$BUSINESS_DESCRIPTION"
    identify_bounded_contexts
    generate_domain_diagram
    generate_context_map
    generate_json_output

    log_success "分析完成!"
    log_success "输出文件位于: $OUTPUT_DIR"

    if [[ $VERBOSE -eq 1 ]]; then
        echo ""
        echo "生成的文件:"
        ls -la "$OUTPUT_DIR/"
    fi
}

# 执行主函数
main "$@"