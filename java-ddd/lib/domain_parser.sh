#!/bin/bash

# 领域解析库
# 提供实体提取、关系分析等函数

# 提取实体（名词）
extract_entities() {
    local text="$1"
    echo "$text" | awk '
    BEGIN {
        # 中文停用词
        stopwords["的"] = 1
        stopwords["了"] = 1
        stopwords["在"] = 1
        stopwords["是"] = 1
        stopwords["和"] = 1
        stopwords["与"] = 1
        stopwords["或"] = 1
    }
    {
        # 替换标点为空格
        gsub(/[.,。，！!?？；;:"'"'"'（）()《》【】\[\]]/, " ", $0)

        for(i=1; i<=NF; i++) {
            word = $i
            # 过滤停用词和短词
            if(length(word) > 1 && !(word in stopwords) && word !~ /^[0-9]+$/) {
                print word
            }
        }
    }' | sort | uniq -c | sort -nr
}

# 提取关系（动词）
extract_relations() {
    local text="$1"
    echo "$text" | awk '
    {
        gsub(/[.,。，！!?？；;:"'"'"'（）()《》【】\[\]]/, " ", $0)

        # 常见动词/关系词
        for(i=1; i<=NF; i++) {
            if($i ~ /^[管理处理查看浏览下支付包含可以分为有提供支持]$/) {
                print $i
            }
        }
    }' | sort | uniq -c | sort -nr
}

# 分析句子结构
analyze_sentence_structure() {
    local text="$1"
    echo "$text" | awk -F '[.,。，！!?？；;]' '
    {
        for(i=1; i<=NF; i++) {
            if(length($i) > 5) {
                print "句子:", $i
                # 简单的主谓宾分析
                words = split($i, arr, " ")
                if(words >= 3) {
                    printf "  可能的主语: %s\n", arr[1]
                    printf "  可能的谓语: %s\n", arr[2]
                    printf "  可能的宾语: %s\n", arr[3]
                }
            }
        }
    }'
}

# 识别领域类型
identify_domain_type() {
    local entity="$1"

    # 核心领域关键词
    local core_keywords="订单 商品 用户 账户 支付 交易 产品 服务 客户 业务 销售"
    # 支撑子域关键词
    local support_keywords="管理 统计 报表 日志 配置 权限 消息 通知 审核 监控"
    # 通用子域关键词
    local generic_keywords="时间 地址 文件 图片 文档 数据 信息 编号 ID 代码"

    for keyword in $core_keywords; do
        if [[ "$entity" == *"$keyword"* ]]; then
            echo "core"
            return
        fi
    done

    for keyword in $support_keywords; do
        if [[ "$entity" == *"$keyword"* ]]; then
            echo "support"
            return
        fi
    done

    for keyword in $generic_keywords; do
        if [[ "$entity" == *"$keyword"* ]]; then
            echo "generic"
            return
        fi
    done

    echo "unknown"
}

# 计算实体重要性
calculate_entity_importance() {
    local entity="$1"
    local frequency="$2"
    local domain_type="$3"

    local importance=$frequency

    # 根据领域类型调整重要性
    case "$domain_type" in
        "core")
            importance=$((importance * 3))
            ;;
        "support")
            importance=$((importance * 2))
            ;;
        "generic")
            # 通用子域重要性较低
            importance=$((importance / 2))
            ;;
    esac

    echo $importance
}