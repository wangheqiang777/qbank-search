# 本地题库搜题 App（跨平台 iOS / Android）

一个**完全本地运行**的题库搜题工具：导入自己的题库（.xlsx / .csv），考试时
手动截图或粘贴题目文字，App 在**本机**题库里找出最匹配的题目和答案。
**题库不上传、不会员、无广告、不联网。**

> 设计原则：所有逻辑在手机本地跑，题库只存在你设备上。这也从源头规避了
> 商业搜题 App「要会员 + 拿你的题去云端大库硬凑导致找不准」的两个通病。

---

## 一、原型验证结果（已用你的真实题库跑通）

用 Python 原型解析你提供的 `新2025强基练兵题库单选、多选、判断.xlsx`：

- 解析出 **1453 道题**（单选 869 + 多选 255 + 判断 329）
- 自测（用原题当查询）：**干净查询 top1 命中率 99.5%**
- 模拟 OCR 残损（随机删 12% 字符）：**命中率仍 99%**
- 演示三道题，top1 全部精确命中、相似度 1.000，答案含选项展开

结论：导入 + 匹配环节已验证可靠，能根治「找不准」。

## 二、项目结构

```
qbank-search/
├── qbank_proto.py        # Python 原型：解析 + 匹配 + 自测（已验证）
├── bank.json             # 解析后的结构化题库（1453 题）
└── app/                  # Flutter 跨平台工程（iOS + Android 同一套代码）
    ├── pubspec.yaml
    └── lib/
        ├── main.dart
        ├── models/question.dart
        ├── services/
        │   ├── parser.dart      # 解析 xlsx/csv -> Question
        │   ├── search.dart      # 归一化 + n-gram 余弦匹配引擎
        │   └── database.dart    # 本地 SQLite 存储
        └── screens/
            ├── import_screen.dart   # 导入题库
            ├── search_screen.dart   # 搜题（粘贴 / 截图OCR）
            └── bank_screen.dart     # 浏览题库
```

## 三、构建步骤

### 前置
- 安装 Flutter SDK（https://flutter.dev/docs/get-started），`flutter doctor` 全绿。
- 安卓打包：Android Studio + 安卓 SDK（Windows/Mac/Linux 均可）。
- **苹果打包：必须在 Mac 上用 Xcode**（iOS 编译需要 macOS，Windows 无法出 ipa）。

### 生成原生工程并安装依赖
```bash
cd qbank-search/app
flutter create .          # 生成 android/ 和 ios/ 原生目录
flutter pub get           # 安装依赖
```

### 安卓
```bash
flutter build apk         # 产物: build/app/outputs/flutter-apk/app-release.apk
# 或连上手机直接跑：flutter run
```

### 苹果（需 Mac）
```bash
flutter build ios         # 用 Xcode 打开 ios/Runner.xcworkspace 存档出 ipa
# 或：flutter run
```

### iOS 权限配置（截图OCR用到相册）
在 `ios/Runner/Info.plist` 增加（Xcode 里加也行）：
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>用于从相册选择考试截图以识别题目</string>
```

## 四、使用流程

1. 打开 App → **导入** 页 → 选择题库文件（.xlsx / .csv）。
   你的题库会解析成结构化数据，**只存本机 SQLite，绝不联网上传**。
2. 考试时切到 **搜题** 页：
   - 方式 A（推荐）：手机截考试题 → 回到本 App → 点「截图OCR」→ 从相册选截图
     → ML Kit 离线识别文字 → 自动搜出答案。
   - 方式 B：直接粘贴题目文字 → 点「搜题」。
3. 返回 Top3 候选（带匹配度%），确认无误采用答案。

> 题库换了一份？重新导入即可，旧库会被覆盖。支持任意含「题目」「正确答案」
> 列的 xlsx/csv，不写死任何一套。

## 五、重要提醒

- **手动触发截图，不做后台自动截屏**。持续读屏/后台截屏可能触发考试平台
  的反作弊检测（切屏/录屏告警）。手动截图 + 相册选择是当前最低风险路径。
- **隐私**：题库与搜索全在本地，开发者（本项目）接触不到你的任何题目。
- 匹配靠「题目文字相似度」，所以题干越完整越准；只截到半句时命中率会下降，
  此时看 Top3 里匹配度最高的即可。
- 当前 v1 聚焦单选/多选/判断（你的主力题型）。填空/问答模板在 Excel 里是空模板，
  后续可按需扩展导入解析。
