# 上大人字牌游戏 - APK生成产品需求文档

## Overview
- **Summary**: 为上大人字牌游戏生成Android APK安装包，支持Flutter和Capacitor两种构建方式
- **Purpose**: 提供可安装的移动应用版本，让用户能够在Android设备上离线玩上大人字牌游戏
- **Target Users**: 喜欢玩上大人字牌游戏的Android用户

## Goals
- 成功生成Flutter项目的APK文件
- 成功生成Capacitor项目的APK文件
- 确保APK能够在Android设备上正常安装和运行
- 解决构建过程中的网络和依赖问题

## Non-Goals (Out of Scope)
- iOS应用构建
- Web应用部署
- 游戏功能修改或优化
- 应用商店发布

## Background & Context
- 项目包含两个版本：Flutter版本和Capacitor版本
- 之前构建过程中遇到了网络问题，需要使用国内镜像
- 已经配置了Flutter SDK和Android SDK
- 项目使用WebView加载游戏HTML内容

## Functional Requirements
- **FR-1**: 生成Flutter项目的APK文件
- **FR-2**: 生成Capacitor项目的APK文件
- **FR-3**: 确保APK包含所有游戏资源文件
- **FR-4**: 确保APK能够正常安装和运行

## Non-Functional Requirements
- **NFR-1**: 构建过程稳定，能够解决网络依赖问题
- **NFR-2**: APK大小合理，不超过100MB
- **NFR-3**: 构建时间不超过30分钟

## Constraints
- **Technical**: 需要Flutter SDK和Android SDK
- **Network**: 需要使用国内镜像解决依赖下载问题
- **Dependencies**: 依赖webview_flutter等包

## Assumptions
- Flutter SDK已经正确安装
- Android SDK已经正确安装
- 项目代码已经完整，无需修改

## Acceptance Criteria

### AC-1: Flutter项目APK生成
- **Given**: Flutter项目配置正确，依赖已安装
- **When**: 运行构建命令
- **Then**: 生成APK文件，位于指定输出目录
- **Verification**: `programmatic`
- **Notes**: 需要使用国内镜像解决依赖问题

### AC-2: Capacitor项目APK生成
- **Given**: Capacitor项目配置正确，依赖已安装
- **When**: 运行构建命令
- **Then**: 生成APK文件，位于指定输出目录
- **Verification**: `programmatic`
- **Notes**: 需要确保web目录内容正确打包

### AC-3: APK安装和运行
- **Given**: 生成的APK文件
- **When**: 在Android设备上安装并运行
- **Then**: 游戏能够正常启动和运行
- **Verification**: `human-judgment`
- **Notes**: 检查游戏是否能够正常加载和操作

## Open Questions
- [ ] Flutter SDK路径是否正确配置
- [ ] Android SDK路径是否正确配置
- [ ] 国内镜像配置是否有效