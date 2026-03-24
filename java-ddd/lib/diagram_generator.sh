#!/bin/bash

# 图表生成库
# 生成PlantUML图表

# 检查PlantUML是否可用
check_plantuml() {
    if command -v plantuml &> /dev/null; then
        echo "plantuml"
        return 0
    elif [[ -n "$DDD_PLANTUML_PATH" && -f "$DDD_PLANTUML_PATH" ]]; then
        echo "java -jar $DDD_PLANTUML_PATH"
        return 0
    else
        return 1
    fi
}

# 生成领域模型图
generate_domain_model_diagram() {
    local output_dir="$1"
    local contexts_file="$2"

    local plantuml_cmd
    plantuml_cmd=$(check_plantuml)
    if [[ $? -ne 0 ]]; then
        echo "PlantUML不可用，跳过图表生成" >&2
        return 1
    fi

    cat > "$output_dir/domain-model.puml" << 'EOF'
@startuml
title 领域模型图

!define CORE_COLOR #FFAAAA
!define SUPPORT_COLOR #AAAAFF
!define GENERIC_COLOR #AAFFAA

skinparam class {
    BackgroundColor White
    BorderColor Black
    ArrowColor Black
}
EOF

    # 从contexts.json读取上下文并生成
    if [[ -f "$contexts_file" ]]; then
        local contexts
        contexts=$(jq -c '.bounded_contexts[]' "$contexts_file" 2>/dev/null || echo "")

        if [[ -n "$contexts" ]]; then
            while IFS= read -r context; do
                local name=$(echo "$context" | jq -r '.name')
                local type=$(echo "$context" | jq -r '.type')
                local entities=$(echo "$context" | jq -r '.entities | join(", ")')

                echo "" >> "$output_dir/domain-model.puml"
                echo "package \"$name\" {" >> "$output_dir/domain-model.puml"

                # 根据类型设置颜色
                case "$type" in
                    "core")
                        echo "  BackgroundColor CORE_COLOR" >> "$output_dir/domain-model.puml"
                        ;;
                    "support")
                        echo "  BackgroundColor SUPPORT_COLOR" >> "$output_dir/domain-model.puml"
                        ;;
                    "generic")
                        echo "  BackgroundColor GENERIC_COLOR" >> "$output_dir/domain-model.puml"
                        ;;
                esac

                # 添加实体
                echo "$entities" | tr ',' '\n' | while read -r entity; do
                    entity=$(echo "$entity" | xargs) # 去除空格
                    if [[ -n "$entity" ]]; then
                        echo "  class $entity {" >> "$output_dir/domain-model.puml"
                        echo "    +ID" >> "$output_dir/domain-model.puml"
                        echo "    +名称" >> "$output_dir/domain-model.puml"
                        echo "  }" >> "$output_dir/domain-model.puml"
                    fi
                done

                echo "}" >> "$output_dir/domain-model.puml"
            done <<< "$contexts"
        fi
    fi

    # 默认内容（如果没有上下文数据）
    if [[ ! -s "$output_dir/domain-model.puml" ]]; then
        cat >> "$output_dir/domain-model.puml" << 'EOF'

package "用户管理" {
  class 用户 {
    +ID
    +用户名
    +密码
    +邮箱
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
  }

  class 订单项 {
    +ID
    +商品ID
    +数量
    +单价
  }

  订单 "1" -- "*" 订单项 : 包含
}
EOF
    fi

    echo "@enduml" >> "$output_dir/domain-model.puml"

    # 生成PNG
    $plantuml_cmd "$output_dir/domain-model.puml" 2>/dev/null || true
}

# 生成上下文映射图
generate_context_map_diagram() {
    local output_dir="$1"
    local contexts_file="$2"

    local plantuml_cmd
    plantuml_cmd=$(check_plantuml)
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    cat > "$output_dir/context-map.puml" << 'EOF'
@startuml
title 限界上下文映射图

!define CORE_COLOR #FFAAAA
!define SUPPORT_COLOR #AAAAFF
!define GENERIC_COLOR #AAFFAA
EOF

    # 从contexts.json读取上下文
    if [[ -f "$contexts_file" ]]; then
        local contexts
        contexts=$(jq -c '.bounded_contexts[]' "$contexts_file" 2>/dev/null || echo "")

        if [[ -n "$contexts" ]]; then
            while IFS= read -r context; do
                local name=$(echo "$context" | jq -r '.name')
                local type=$(echo "$context" | jq -r '.type')
                local responsibilities=$(echo "$context" | jq -r '.responsibilities | join("\\n")')

                echo "[$name] as [$(echo "$name" | sed 's/上下文//' | tr -d ' ')]" >> "$output_dir/context-map.puml"

                # 添加备注
                echo "note right of [$(echo "$name" | sed 's/上下文//' | tr -d ' ')]" >> "$output_dir/context-map.puml"
                echo "  $type 领域" >> "$output_dir/context-map.puml"
                if [[ -n "$responsibilities" && "$responsibilities" != "null" ]]; then
                    echo "  职责:" >> "$output_dir/context-map.puml"
                    echo "$responsibilities" | while read -r resp; do
                        echo "  - $resp" >> "$output_dir/context-map.puml"
                    done
                fi
                echo "end note" >> "$output_dir/context-map.puml"
            done <<< "$contexts"

            # 添加默认关系
            echo "" >> "$output_dir/context-map.puml"
            echo "[用户管理] --> [订单处理] : 用户信息" >> "$output_dir/context-map.puml"
            echo "[商品管理] --> [订单处理] : 商品信息" >> "$output_dir/context-map.puml"
        fi
    fi

    echo "@enduml" >> "$output_dir/context-map.puml"

    # 生成PNG
    $plantuml_cmd "$output_dir/context-map.puml" 2>/dev/null || true
}

# 生成聚合图
generate_aggregate_diagram() {
    local output_dir="$1"
    local aggregate_name="$2"
    local entities="$3"

    local plantuml_cmd
    plantuml_cmd=$(check_plantuml)
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    cat > "$output_dir/aggregate-$aggregate_name.puml" << EOF
@startuml
title 聚合: $aggregate_name

skinparam class {
    BackgroundColor White
    BorderColor Black
}

!define AGGREGATE_ROOT_COLOR #FFCCCC
!define ENTITY_COLOR #CCFFCC
!define VALUE_OBJECT_COLOR #CCCCFF
EOF

    # 解析实体
    echo "class ${aggregate_name}Root << (A,AGGREGATE_ROOT_COLOR) 聚合根 >> {" >> "$output_dir/aggregate-$aggregate_name.puml"
    echo "  +ID" >> "$output_dir/aggregate-$aggregate_name.puml"
    echo "  +创建时间" >> "$output_dir/aggregate-$aggregate_name.puml"
    echo "}" >> "$output_dir/aggregate-$aggregate_name.puml"

    # 添加实体
    for entity in $entities; do
        echo "class $entity << (E,ENTITY_COLOR) 实体 >> {" >> "$output_dir/aggregate-$aggregate_name.puml"
        echo "  +ID" >> "$output_dir/aggregate-$aggregate_name.puml"
        echo "}" >> "$output_dir/aggregate-$aggregate_name.puml"

        echo "${aggregate_name}Root *-- $entity : 包含" >> "$output_dir/aggregate-$aggregate_name.puml"
    done

    echo "@enduml" >> "$output_dir/aggregate-$aggregate_name.puml"

    $plantuml_cmd "$output_dir/aggregate-$aggregate_name.puml" 2>/dev/null || true
}