# Video to Text Workflow

把抖音、B 站、小红书等平台的视频，在**本地**变成文字稿：先看平台有没有现成字幕，没有才用 Faster-Whisper 转写，最后归档成 Markdown。

全程不联网转写、不上传音视频。

## 三步上手

1. 在 GitHub 页面点 **Code → Download ZIP**，解压到任意目录
2. **双击 `安装.bat`**，等它跑完
3. 把链接或视频文件交给 `run.ps1`：

```powershell
.\scripts\run.ps1 "https://www.bilibili.com/video/BVxxxxxxxx"
```

前置条件：Windows 10/11、磁盘至少 5 GB、能访问 GitHub 和 HuggingFace。

## 安装

### 方式 A：双击（推荐给大多数人）

上面的三步就装完了。`安装.bat` 会：下载并解压工具链（含 ffmpeg）→ 检查目录 → 用 winget 装 yt-dlp → 打印用法。

**重复双击是安全的**，已装好的部分自动跳过。

### 方式 B：命令行

想看清楚每一步在干什么，或者要装到自定义位置：

```powershell
git clone https://github.com/lidengbo/video-to-text-workflow.git
cd video-to-text-workflow
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup.ps1
winget install yt-dlp.yt-dlp
```

`-ExecutionPolicy Bypass` 是必须的：多数 Windows 机器默认策略是 `Restricted`，直接跑 `.ps1` 会报“禁止运行脚本”。

### 要下多少东西

| 内容 | 大小 | 时机 |
|---|---|---|
| 工具链（Faster-Whisper-XXL + ffmpeg） | 约 1.4 GB 下载，解压后约 3 GB | 安装时 |
| medium 模型 | 约 1.5 GB | **第一次转写时**自动下载 |

合计约 **5.8 GB**（本机实测 5.82 GB）。

### GitHub 连不上时

手动下载安装包，再用 `-LocalPackage` 喂给脚本：

```powershell
.\scripts\setup.ps1 -LocalPackage "D:\下载\Faster-Whisper-XXL_r245.4_windows.7z"
```

下载页：<https://github.com/Purfview/whisper-standalone-win/releases>

## 使用

### 一条命令跑完

```powershell
.\scripts\run.ps1 "<链接>"
```

它会依次做：

1. 解析链接，拿到「平台 + 编号」
2. **先查平台有没有中文字幕**；有就直接归档，跳过转写
3. 没字幕才下载媒体到 `_inbox/`，再跑 Faster-Whisper
4. 归档到 `视频/<平台>-<编号>/`，打印字幕路径

### 常用开关

| 开关 | 作用 |
|---|---|
| `-KeepVideo` | 转完保留原视频（默认会删除） |
| `-NoTranscribe` | 只下载，不转写 |
| `-AllowAutoSubs` | 平台只有自动生成字幕时也接受 |
| `-SkipSubsCheck` | 不查字幕，直接下载 + 转写 |
| `-CookiesFrom chrome` | 需要登录才看得到字幕时（B 站常见） |
| `-Vault "D:\我的笔记"` | 顺带把 .md/.vtt 同步到知识库 |
| `-Model large-v3` | 换更大的模型（更准，更慢） |

本地文件直接当参数：

```powershell
.\scripts\run.ps1 ".\_inbox\abc.mp4" -KeepVideo
```

**默认会删除原视频**（转写成功后），需要留档就加 `-KeepVideo`。

### 关于字幕优先

默认只认**人工上传**的字幕。自动生成的字幕质量不稳定，要用 `-AllowAutoSubs` 显式同意。

用平台字幕时脚本会写一份 `来源.md`，记下「字幕来源：平台字幕（人工）」或「（自动生成）」。两种 `.vtt` 格式完全一样，不记来源事后分不清哪份可信。

### 同步到知识库（不需要 Obsidian）

产物就是普通的 `.md` / `.vtt`，用记事本、VS Code、Typora 都能打开。**不装 Obsidian 不影响任何功能。**

想把整理稿收进自己的知识库：

```powershell
.\scripts\publish.ps1 -Archive ".\视频\抖音-xxxx" -Vault "D:\我的笔记\视频解析"
```

目标目录下会建一个同名的 `平台-编号` 文件夹。

### 只用转写那一步

```powershell
.\scripts\transcribe.ps1 ".\_inbox\abc.mp4" -Format vtt,txt,srt -Model large-v3
```

## 输出在哪

```
video-to-text-workflow/
├── _inbox/                     # 下载中转，转完会清掉原文件
├── 视频/
│   └── 平台-编号/
│       ├── 编号.vtt            # 字幕（平台字幕或转写所得）
│       ├── 编号.txt            # 纯文本
│       ├── 编号.md             # 你或 AI 整理后的笔记
│       └── 来源.md             # 链接、字幕来源、处理记录
└── _tools/                     # 工具链和模型（约 5.8 GB，不入库）
```

## 从 VTT 到 Markdown 笔记

脚本跑到 vtt 就停了：那是**带时间码、无标点的原始字幕**。最后一步交给 AI，或者按 `templates/note.md` 手工写。

把下面这段连同 vtt 内容一起发给 Claude Code / DSH / ChatGPT：

```text
下面是一段视频的原始字幕（VTT，带时间码）。请整理成 Markdown 笔记：

1. 去掉时间码，合并成通顺的段落，补上标点；不要删掉信息，只做去噪和重组。
2. 开头写 YAML front matter：title、platform、id、source、date。
3. 正文按主题分段，每段加小标题。
4. 结尾加一个「要点速记」表格，和「待核对」清单——把可能识别错的
   专有名词、数字、产品名单独列出来，标注为需要人工确认。
5. 不要编造字幕里没有的内容。

【字幕开始】
（粘贴 vtt 内容）
【字幕结束】
```

产出的 `.md` 放回 `视频/<平台>-<编号>/`。

## 常见问题

**抖音链接解析失败？** yt-dlp 对 B 站、YouTube 支持成熟，对抖音时好时坏。失败时先把视频手动下载下来，再用本地文件路径运行。

**B 站看不到字幕？** 字幕通常要登录态，加 `-CookiesFrom chrome`（或 `edge`、`firefox`）。

**报“禁止运行脚本”？** 换成 `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\xxx.ps1`。

**只下到没声音的文件？** yt-dlp 合并音视频需要 ffmpeg 在 PATH 里，而自带的那份在 `_tools\app\Faster-Whisper-XXL\`。把该目录加进 PATH，或把 ffmpeg.exe 复制到系统 PATH 下的目录。

**第一次转写特别慢？** 要把模型载入内存。实测：一段 3 秒音频总耗时 108 秒，绝大部分是加载时间；同一批里后续视频不用再付这份开销。

**想搬到别的盘？** 整个文件夹直接复制走即可，路径都是相对仓库根目录的。工具装在别处时设置环境变量 `VTT_ROOT`。

## 目录说明

| 路径 | 说明 |
|---|---|
| `安装.bat` | 双击的一键安装入口 |
| `scripts/install.ps1` | 安装流程本体 |
| `scripts/setup.ps1` | 只负责工具链（下载、解压、建目录、检查） |
| `scripts/run.ps1` | **日常入口**：链接/文件 → 字幕 |
| `scripts/transcribe.ps1` | 只做转写，支持多格式、多模型 |
| `scripts/publish.ps1` | 归档 → 知识库 |
| `scripts/sample_audio.ps1` | 抽取开头/中段/结尾音频样本 |
| `scripts/_dl.cjs` | 旧方案：Node.js 下载器（yt-dlp 支持的站点用不上） |
| `SKILL.md` | 完整工作流规范，给 Agent 用 |
| `templates/` | 整理稿和来源记录模板 |
| `config.example.json` | 路径示意，**脚本不读取**，参数请走命令行 |
