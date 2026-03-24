#!/bin/bash
# init-java-microservice.sh - Java微服务项目初始化脚本
# 通过Spring Initializr API快速生成Spring Boot微服务项目

set -e  # 遇到错误立即退出

# 版本信息
VERSION="1.0.0"
SCRIPT_NAME=$(basename "$0")

# 默认配置
DEFAULT_PACKAGE="com.example"
DEFAULT_JAVA_VERSION="17"
DEFAULT_OUTPUT_DIR="."
DEFAULT_SPRING_BOOT_VERSION="3.6.0"

# 预定义依赖集合
PREDEFINED_DEPS=(
    "web"           # Spring Web
    "data-jpa"      # Spring Data JPA
    "data-mongodb"  # Spring Data MongoDB
    "security"      # Spring Security
    "validation"    # Validation
    "lombok"        # Lombok
    "devtools"      # Spring Boot DevTools
    "actuator"      # Spring Boot Actuator
)

# 快捷依赖包
DEPENDENCY_PACKAGES=(
    "full-microservice:web,data-jpa,security,validation,lombok,devtools,actuator"
    "web-service:web,validation,lombok,devtools"
    "data-service:web,data-jpa,validation,lombok,devtools"
)

# 全局变量
PROJECT_NAME=""
PACKAGE_NAME="$DEFAULT_PACKAGE"
JAVA_VERSION="$DEFAULT_JAVA_VERSION"
DEPENDENCIES=""
OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"
WITH_DOCKER=false
WITH_CI=""
VERBOSE=false
QUIET=false
PROJECT_DIR=""
TEMP_ZIP_FILE=""

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 输出函数
log_info() {
    if [ "$QUIET" = false ]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

log_success() {
    if [ "$QUIET" = false ]; then
        echo -e "${GREEN}[SUCCESS]${NC} $1"
    fi
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "[DEBUG] $1"
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
${SCRIPT_NAME} - Java微服务项目初始化工具 v${VERSION}

用法: ${SCRIPT_NAME} [选项]

必需选项:
  -n, --name <名称>          项目名称（必需）
  -p, --package <包名>       项目包名（默认: ${DEFAULT_PACKAGE}）

可选选项:
  -j, --java-version <版本>  Java版本（默认: ${DEFAULT_JAVA_VERSION}）
  -d, --dependencies <依赖>  额外依赖，逗号分隔
                             预定义依赖: ${PREDEFINED_DEPS[*]}
                             快捷包: full-microservice, web-service, data-service
  -o, --output-dir <目录>    输出目录（默认: 当前目录）
  --with-docker              包含Docker配置
  --with-ci <类型>           包含CI/CD配置 (github 或 jenkins)
  --verbose                  显示详细输出
  --quiet                    安静模式，只显示错误
  -h, --help                 显示此帮助信息
  -v, --version              显示版本信息

示例:
  ${SCRIPT_NAME} -n my-service -p com.mycompany
  ${SCRIPT_NAME} -n user-service -p com.mycompany.user -j 21 -d web,jpa --with-docker --with-ci github
  ${SCRIPT_NAME} -n api-service -p com.example.api -d full-microservice

注意:
  1. 需要 curl 和 unzip 工具
  2. 依赖列表参考: https://start.spring.io/#dependencies
EOF
}

# 显示版本信息
show_version() {
    echo "${SCRIPT_NAME} v${VERSION}"
}

# 检查必需的工具
check_dependencies() {
    local missing_tools=()

    if ! command -v curl &> /dev/null; then
        missing_tools+=("curl")
    fi

    if ! command -v unzip &> /dev/null; then
        missing_tools+=("unzip")
    fi

    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "缺少必需的工具: ${missing_tools[*]}"
        log_info "请安装缺少的工具:"
        for tool in "${missing_tools[@]}"; do
            case $tool in
                "curl")
                    echo "  macOS: brew install curl"
                    echo "  Ubuntu/Debian: sudo apt-get install curl"
                    ;;
                "unzip")
                    echo "  macOS: brew install unzip"
                    echo "  Ubuntu/Debian: sudo apt-get install unzip"
                    ;;
            esac
        done
        exit 1
    fi

    log_debug "所有必需工具已安装"
}

# 扩展快捷依赖包
expand_dependency_package() {
    local deps="$1"

    # 检查是否为快捷包
    for package in "${DEPENDENCY_PACKAGES[@]}"; do
        local package_name="${package%%:*}"
        local package_deps="${package#*:}"

        if [ "$deps" = "$package_name" ]; then
            echo "$package_deps"
            return 0
        fi
    done

    # 不是快捷包，直接返回
    echo "$deps"
}

# 验证依赖
validate_dependencies() {
    if [ -z "$DEPENDENCIES" ]; then
        return 0
    fi

    # 扩展快捷包
    DEPENDENCIES=$(expand_dependency_package "$DEPENDENCIES")
    log_debug "扩展后的依赖: $DEPENDENCIES"

    # 简单的依赖验证（在实际实现中可以更复杂）
    local invalid_deps=()
    IFS=',' read -ra deps_array <<< "$DEPENDENCIES"

    for dep in "${deps_array[@]}"; do
        dep=$(echo "$dep" | xargs)  # 去除空格

        # 检查是否为预定义依赖
        local is_predefined=false
        for predefined_dep in "${PREDEFINED_DEPS[@]}"; do
            if [ "$dep" = "$predefined_dep" ]; then
                is_predefined=true
                break
            fi
        done

        if [ "$is_predefined" = false ]; then
            log_debug "依赖 '$dep' 不是预定义依赖，将直接传递给Spring Initializr"
        fi
    done

    return 0
}

# 解析参数
parse_arguments() {
    # 如果没有参数，显示帮助
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    while [ $# -gt 0 ]; do
        case $1 in
            -n|--name)
                if [ -z "$2" ] || [[ "$2" == -* ]]; then
                    log_error "选项 $1 需要一个参数"
                    exit 1
                fi
                PROJECT_NAME="$2"
                shift 2
                ;;
            -p|--package)
                if [ -z "$2" ] || [[ "$2" == -* ]]; then
                    log_error "选项 $1 需要一个参数"
                    exit 1
                fi
                PACKAGE_NAME="$2"
                shift 2
                ;;
            -j|--java-version)
                if [ -z "$2" ] || [[ "$2" == -* ]]; then
                    log_error "选项 $1 需要一个参数"
                    exit 1
                fi
                JAVA_VERSION="$2"
                shift 2
                ;;
            -d|--dependencies)
                if [ -z "$2" ] || [[ "$2" == -* ]]; then
                    log_error "选项 $1 需要一个参数"
                    exit 1
                fi
                DEPENDENCIES="$2"
                shift 2
                ;;
            -o|--output-dir)
                if [ -z "$2" ] || [[ "$2" == -* ]]; then
                    log_error "选项 $1 需要一个参数"
                    exit 1
                fi
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --with-docker)
                WITH_DOCKER=true
                shift
                ;;
            --with-ci)
                if [ -z "$2" ] || [[ "$2" == -* ]]; then
                    log_error "选项 $1 需要一个参数"
                    exit 1
                fi
                if [ "$2" != "github" ] && [ "$2" != "jenkins" ]; then
                    log_error "CI类型必须是 'github' 或 'jenkins'"
                    exit 1
                fi
                WITH_CI="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --quiet)
                QUIET=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 验证参数
validate_arguments() {
    # 检查必需参数
    if [ -z "$PROJECT_NAME" ]; then
        log_error "必须提供项目名称 (-n, --name)"
        show_help
        exit 1
    fi

    # 验证项目名称（只允许字母、数字、连字符）
    if ! [[ "$PROJECT_NAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
        log_error "项目名称只能包含字母、数字和连字符"
        exit 1
    fi

    # 验证包名
    if ! [[ "$PACKAGE_NAME" =~ ^[a-zA-Z0-9_.]+$ ]]; then
        log_error "包名格式无效"
        exit 1
    fi

    # 验证Java版本
    if ! [[ "$JAVA_VERSION" =~ ^[0-9]+$ ]]; then
        log_error "Java版本必须是数字"
        exit 1
    fi

    # 验证输出目录
    if [ ! -d "$OUTPUT_DIR" ]; then
        log_info "创建输出目录: $OUTPUT_DIR"
        mkdir -p "$OUTPUT_DIR"
    fi

    # 验证依赖
    validate_dependencies

    log_debug "参数验证通过"
}

# 显示当前配置
show_configuration() {
    if [ "$QUIET" = false ]; then
        echo "========================================"
        echo "        项目配置信息"
        echo "========================================"
        echo "项目名称:      $PROJECT_NAME"
        echo "包名:          $PACKAGE_NAME"
        echo "Java版本:      $JAVA_VERSION"
        echo "Spring Boot:   $DEFAULT_SPRING_BOOT_VERSION"
        echo "依赖:          ${DEPENDENCIES:-无}"
        echo "输出目录:      $OUTPUT_DIR"
        echo "Docker配置:    $WITH_DOCKER"
        echo "CI/CD配置:     ${WITH_CI:-无}"
        echo "========================================"
    fi
}

# 构建Spring Initializr API URL
build_api_url() {
    local base_url="https://start.spring.io/starter.zip"
    local params=""

    # 基本参数
    params+="type=maven-project"
    params+="&language=java"
    params+="&bootVersion=${DEFAULT_SPRING_BOOT_VERSION}"
    params+="&baseDir=${PROJECT_NAME}"
    params+="&groupId=${PACKAGE_NAME}"
    params+="&artifactId=${PROJECT_NAME}"
    params+="&name=${PROJECT_NAME}"
    params+="&description=Spring+Boot+project+generated+by+${SCRIPT_NAME}"
    params+="&packageName=${PACKAGE_NAME}"
    params+="&javaVersion=${JAVA_VERSION}"

    # 依赖参数
    if [ -n "$DEPENDENCIES" ]; then
        params+="&dependencies=${DEPENDENCIES}"
    fi

    echo "${base_url}?${params}"
}

# 下载Spring Boot项目
download_project() {
    local url="$1"
    local output_file="$2"

    log_info "正在下载Spring Boot项目..."

    if ! curl --fail --silent --show-error --max-time 30 \
         --output "$output_file" "$url"; then
        log_error "下载失败，请检查网络连接和参数"
        log_error "尝试的URL: ${url}"
        exit 1
    fi

    log_success "项目下载完成"
}

# 解压项目文件
extract_project() {
    local zip_file="$1"
    local target_dir="$2"

    log_info "正在解压项目文件..."

    if ! unzip -q "$zip_file" -d "$target_dir"; then
        log_error "解压失败，请检查zip文件是否完整"
        exit 1
    fi

    # 检查是否解压成功
    local project_dir="$target_dir/$PROJECT_NAME"
    if [ ! -d "$project_dir" ]; then
        log_error "解压后未找到项目目录: $project_dir"
        exit 1
    fi

    log_success "项目解压完成: $project_dir"
}

# 清理临时文件
cleanup_temp_files() {
    if [ -f "$TEMP_ZIP_FILE" ]; then
        rm -f "$TEMP_ZIP_FILE"
        log_debug "清理临时文件: $TEMP_ZIP_FILE"
    fi
}

# 生成项目
generate_project() {
    local project_dir="$OUTPUT_DIR/$PROJECT_NAME"

    # 检查项目目录是否已存在
    if [ -d "$project_dir" ]; then
        log_warn "项目目录已存在: $project_dir"
        read -p "是否覆盖? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "操作取消"
            exit 0
        fi
        log_info "覆盖现有目录..."
        rm -rf "$project_dir"
    fi

    # 构建API URL
    local api_url
    api_url=$(build_api_url)
    log_debug "API URL: $api_url"

    # 创建临时文件
    TEMP_ZIP_FILE=$(mktemp)
    trap cleanup_temp_files EXIT

    # 下载项目
    download_project "$api_url" "$TEMP_ZIP_FILE"

    # 解压项目
    extract_project "$TEMP_ZIP_FILE" "$OUTPUT_DIR"

    # 显示生成的项目信息
    log_success "项目生成成功!"
    log_info "项目目录: $project_dir"
    log_info "可以使用以下命令进入项目:"
    echo "  cd $project_dir"
    echo "  ./mvnw spring-boot:run"

    # 返回项目目录路径
    echo "$project_dir"
}

# 主函数
main() {
    log_info "Java微服务项目初始化工具 v${VERSION}"

    # 检查依赖
    check_dependencies

    # 解析参数
    parse_arguments "$@"

    # 验证参数
    validate_arguments

    # 显示配置
    show_configuration

    log_success "参数解析完成，准备生成项目"

    # 生成项目
    PROJECT_DIR=$(generate_project)

    log_success "Java微服务项目初始化完成!"
}

# 运行主函数
main "$@"
