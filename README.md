# scan_ai_excel_app

一个纯前端 Flutter MVP：

- 导入 `.xlsx`
- 按规则解析为任务列表
- 文档扫描（自动裁边/纠偏由插件提供）
- 本地生成 PDF
- 直连用户自配的云端多模态模型（OpenAI Compatible Chat Completions 协议）
- 将 AI 核验结果写回 Excel 最后一列
- 导出新的 `.xlsx`

## Android 配置

你至少需要确认：

- 已声明网络权限 `android.permission.INTERNET`
- `minSdk >= 21`

## iOS 配置

你至少需要确认：

- `platform :ios, '13.0'`
- `Info.plist` 中加入 `NSCameraUsageDescription`

## 运行

```bash
flutter pub get
flutter run
```

## 默认设置

### AI 配置

你可以在“我的”页面配置：

- Endpoint：默认 `https://api.openai.com/v1/chat/completions`
- API Key
- Model：默认 `gpt-4.1-mini`
- Timeout

本项目只适配**一套统一协议**：

- OpenAI Compatible Chat Completions
- 多模态图片输入
- 返回 JSON 文本

### Excel 规则默认值

- Sheet：`Sheet1`
- 表头行：`1`
- 任务名称列：`单号`
- PDF 命名列：`单号`
- 核验列：`客户名称,金额,日期`
- 结果列：`AI核验结果`

## 目录说明

```text
lib/
  controllers/
  models/
  pages/
  services/
  widgets/
platform_setup/
  android/
  ios/
```

## 当前实现边界

已实现：

- 单工作簿导入
- 按指定 sheet + 表头解析
- 单条任务扫描
- 多页图片扫描
- 本地 PDF 生成
- AI 核验
- Excel 写回
- 本地导出

未实现：

- 后端代理
- 云端同步
- 多协议模型适配
- OCR 离线引擎
- 批量后台队列
- 历史任务数据库

## 建议测试方式

先准备一个简单的 Excel：

| 单号 | 客户名称 | 金额 | 日期 |
|---|---|---|---|
| A001 | 张三公司 | 1880 | 2026-03-24 |
| A002 | 李四公司 | 5200 | 2026-03-24 |

导入后点击某条任务，扫描纸质文件，再在“我的”里配置可用模型，完成核验与导出。
