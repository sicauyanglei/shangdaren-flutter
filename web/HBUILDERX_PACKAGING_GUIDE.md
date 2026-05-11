# HBuilderX打包APK指南

## 准备工作

### 1. 下载并安装HBuilderX
- 访问HBuilderX官网：https://www.dcloud.io/hbuilderx.html
- 下载HBuilderX标准版或App开发版
- 解压到任意目录即可使用

### 2. 项目结构
确保项目目录结构如下：
```
shangdaren-game/
├── web/
│   ├── index.html          # 游戏主页
│   ├── game.js             # 游戏逻辑
│   ├── manifest.json       # HBuilderX配置文件
│   └── images/             # 图片资源
│       ├── back.png
│       ├── shang.png
│       ├── da.png
│       └── ...
```

## 打包步骤

### 方法一：使用HBuilderX可视化界面

#### 1. 导入项目
1. 打开HBuilderX
2. 点击菜单：`文件` -> `导入` -> `从本地目录导入`
3. 选择 `E:\AI-PRJ\shangdaren-game\web` 目录
4. 点击`选择`完成导入

#### 2. 配置项目
1. 在项目根目录创建 `manifest.json` 文件（已创建）
2. 双击 `manifest.json` 打开可视化配置界面
3. 配置以下信息：
   - **基础配置**：
     - 应用名称：上大人字牌游戏
     - 应用版本名称：1.0.0
     - 应用版本号：100
   - **App图标**：
     - 点击`浏览`选择图标文件
     - 建议尺寸：1024x1024
   - **App启动界面**：
     - 选择启动图片
     - 建议尺寸：1080x1920

#### 3. 云端打包
1. 在项目上右键点击
2. 选择：`发行` -> `原生App-云打包`
3. 选择打包平台：
   - Android（勾选）
   - iOS（可选）
4. 选择证书：
   - **测试版**：使用DCloud公用证书（免费）
   - **正式版**：使用自有证书（需要申请）
5. 点击`打包`按钮
6. 等待打包完成（约5-10分钟）
7. 打包完成后会自动下载APK文件

### 方法二：使用命令行打包

#### 1. 安装HBuilderX命令行工具
```bash
# 下载HBuilderX命令行工具
# 将HBuilderX安装目录添加到环境变量PATH中
```

#### 2. 执行打包命令
```bash
cd E:\AI-PRJ\shangdaren-game\web

# 打包Android
hbuilderx pack --platform android --type release

# 打包iOS
hbuilderx pack --platform ios --type release
```

### 方法三：本地打包（离线打包）

#### 1. 准备Android Studio环境
- 安装Android Studio
- 配置Android SDK
- 安装JDK 8或以上版本

#### 2. 下载离线打包SDK
- 访问：https://nativesupport.dcloud.net.cn/AppDocs/download/android
- 下载Android离线SDK

#### 3. 配置项目
1. 解压离线SDK
2. 将 `web` 目录下的文件复制到 `assets/apps/__UNI__SHANGDAREN/www/` 目录
3. 使用Android Studio打开项目
4. 配置应用信息
5. 编译生成APK

## 证书配置

### 测试证书（DCloud公用证书）
- 适用于测试阶段
- 无需申请，直接使用
- 有一定的功能限制

### 正式证书（自有证书）
1. **生成证书**：
```bash
keytool -genkey -alias shangdaren -keyalg RSA -keysize 2048 -validity 36500 -keystore shangdaren.keystore
```

2. **配置证书**：
   - 在 `manifest.json` 中配置证书信息
   - 或在云端打包时上传证书

## 常见问题

### 1. 打包失败
- 检查 `manifest.json` 配置是否正确
- 检查资源文件是否完整
- 检查网络连接是否正常

### 2. 应用闪退
- 检查JavaScript代码是否有错误
- 检查资源路径是否正确
- 使用真机调试查看日志

### 3. 图标不显示
- 检查图标文件格式（PNG）
- 检查图标尺寸是否符合要求
- 检查图标路径是否正确

### 4. 启动界面不显示
- 检查启动图片格式和尺寸
- 检查启动界面配置

## 优化建议

### 1. 性能优化
- 压缩图片资源
- 合并CSS和JavaScript文件
- 使用CDN加载资源

### 2. 用户体验优化
- 添加启动动画
- 优化加载速度
- 添加离线缓存

### 3. 安全优化
- 使用HTTPS
- 混淆JavaScript代码
- 添加防篡改机制

## 发布应用

### 1. 应用商店发布
- **Google Play**：需要开发者账号（$25一次性费用）
- **国内应用商店**：需要开发者账号和软件著作权

### 2. 自己分发
- 上传到自己的服务器
- 提供二维码下载
- 通过第三方平台分发

## 相关链接

- HBuilderX官网：https://www.dcloud.io/hbuilderx.html
- HBuilderX文档：https://hx.dcloud.net.cn/
- 5+App开发文档：https://www.html5plus.org/doc/
- Android离线打包：https://nativesupport.dcloud.net.cn/AppDocs/download/android
- iOS离线打包：https://nativesupport.dcloud.net.cn/AppDocs/download/ios

## 技术支持

如有问题，请访问：
- DCloud社区：https://ask.dcloud.net.cn/
- DCloud官方文档：https://uniapp.dcloud.io/
