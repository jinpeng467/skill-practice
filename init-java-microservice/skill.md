---
name: init-java-microservice
description: 通过Spring Initializr API快速初始化Java微服务项目的Bash脚本工具
version: 1.0.0
---

## 功能概述

`init-java-microservice.sh` 是一个用于快速初始化Java微服务项目的Bash脚本工具。它通过调用Spring Initializr API，自动化生成基于Spring Boot的微服务项目骨架，支持自定义配置和依赖管理。

## 核心功能

### 1. 项目配置
- **项目名称**: 必需参数，用于定义项目目录和artifact ID
- **包名**: 支持自定义Java包结构，默认 `com.example`
- **Java版本**: 指定Java SDK版本，默认Java 17
- **Spring Boot版本**: 固定使用Spring Boot 3.6.0

### 2. 依赖管理
- **预定义依赖集合**: 包含常见的Spring Boot依赖：
  - `web`: Spring Web (REST API)
  - `data-jpa`: Spring Data JPA (数据库访问)
  - `data-mongodb`: Spring Data MongoDB
  - `security`: Spring Security (安全认证)
  - `validation`: Bean Validation (数据校验)
  - `lombok`: Lombok (代码简化)
  - `devtools`: Spring Boot DevTools (开发工具)
  - `actuator`: Spring Boot Actuator (监控端点)
- **快捷依赖包**: 提供预配置的依赖组合：
  - `full-microservice`: 完整微服务依赖集（web+jpa+security+validation+lombok+devtools+actuator）
  - `web-service`: Web服务基础依赖（web+validation+lombok+devtools）
  - `data-service`: 数据服务基础依赖（web+jpa+validation+lombok+devtools）

### 3. 可选特性
- **Docker支持**: 通过 `--with-docker` 参数添加Docker配置
- **CI/CD集成**: 通过 `--with-ci` 参数支持GitHub Actions或Jenkins配置
- **输出目录控制**: 可指定项目生成的目标目录

### 4. 工具特性
- **参数验证**: 自动验证项目名称、包名、Java版本等参数的合法性
- **依赖扩展**: 自动将快捷包名扩展为具体的依赖列表
- **错误处理**: 完善的错误处理和用户友好的提示信息
- **临时文件清理**: 自动清理下载的临时ZIP文件
- **覆盖保护**: 当目标目录存在时提示用户确认覆盖

## 使用示例

### 基本用法
```bash
./init-java-microservice.sh -n my-service -p com.mycompany
```

### 完整配置示例
```bash
./init-java-microservice.sh \
  -n user-service \
  -p com.mycompany.user \
  -j 21 \
  -d web,jpa \
  --with-docker \
  --with-ci github
```

### 快捷包使用
```bash
./init-java-microservice.sh \
  -n api-service \
  -p com.example.api \
  -d full-microservice
```

## 技术实现

### 依赖检查
脚本自动检查系统是否安装必需工具：
- `curl`: 用于下载Spring Initializr生成的ZIP文件
- `unzip`: 用于解压项目文件

### API集成
通过构建参数化的URL调用Spring Initializr API：
```
https://start.spring.io/starter.zip?type=maven-project&language=java&...
```

### 输出结构
生成的标准Spring Boot项目包含：
- Maven包装器 (`mvnw`, `.mvn/`)
- 标准Maven目录结构 (`src/main/java`, `src/test/java`)
- `pom.xml` 包含指定的依赖和配置
- 主应用类（基于指定的包名）

## 适用场景

1. **快速原型开发**: 快速搭建微服务项目骨架
2. **团队标准化**: 确保团队成员使用统一的项目模板
3. **教学演示**: 快速生成示例项目用于教学目的
4. **CI/CD流水线**: 自动化生成测试或演示项目

## 注意事项

1. 需要网络连接访问Spring Initializr服务
2. 依赖Spring Initializr服务的可用性和API稳定性
3. 生成的项目基于标准Spring Boot模板，可后续自定义修改

## 版本信息

- 当前版本: 1.0.0
- 更新日期: 2026-03-24
