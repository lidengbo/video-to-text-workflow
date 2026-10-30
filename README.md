# Video to Text Workflow

一个面向抖音、B 站、小红书等视频分享链接的本地整理流程：解析直链、下载媒体、先判断音轨是 BGM 还是人声、必要时使用 Faster-Whisper 转写，再生成干净 Markdown、来源记录、归档资料并同步到 Obsidian。

## 流程

1. 解析分享链接，获得媒体直链、标题、内容编号和媒体类型。
2. 检查是否已有归档，避免重复下载或覆盖。
3. 下载视频、图片或音频到临时入口目录。
4. 从开头、中段、结尾各抽取约 5–8 秒音频样本，先判断是否有人声。
5. 确认有人声讲解、对白或旁白后，才对完整音轨运行 Faster-Whisper。
6. 纯 BGM、纯音效或无法确认人声时跳过完整转写，只整理画面、字幕和分享文案。
7. 生成原始 VTT（如有）、干净稿和 `来源.md`。
8. 按 `平台-内容编号` 归档，并将整理稿同步到 Obsidian。

## 快速开始（Windows）

```powershell
git clone https://github.com/lidengbo/video-to-text-workflow.git
cd video-to-text-workflow
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup.ps1
```

`setup.ps1` 会查询并下载 Faster-Whisper-XXL 的 Windows 包（约 1.4 GB，解压后约 3 GB，内含 ffmpeg），并建好 `_inbox/`、`视频/`、`_tools/models/` 目录。首次转写还会自动下载 medium 模型（约 1.5 GB）。

> 磁盘请**至少预留 5 GB**。本机实测：工具链 + medium 模型合计 **5.82 GB**。
>
> 很多 Windows 机器默认执行策略是 `Restricted`，所以要带 `-ExecutionPolicy Bypass`，否则会报“禁止运行脚本”。

装好后把视频丢进 `_inbox`，然后：

```powershell
.\scripts\transcribe.ps1 ".\_inbox\abc.mp4"                 # 输出 vtt
.\scripts\transcribe.ps1 ".\_inbox\abc.mp4" -KeepVideo       # 转完保留原视频
.\scripts\transcribe.ps1 ".\_inbox\abc.mp4" -Format vtt,txt,srt -Model large-v3
```

**默认会删除原视频**：转写成功后原文件被移除以省磁盘，想保留就加 `-KeepVideo`。

## 目录

- `SKILL.md`：完整工作流规范。
- `scripts/setup.ps1`：一键准备工具链（查版本、下载、解压、建目录、检查环境）。
- `scripts/transcribe.ps1`：CPU Faster-Whisper 转写包装脚本，支持多格式、多模型、指定输出目录。
- `scripts/_dl.cjs`：支持 HTTP/HTTPS 重定向的 Node.js 下载脚本。
- `scripts/sample_audio.ps1`：抽取开头、中段、结尾音频样本。
- `templates/`：整理稿和来源记录模板。
- `config.example.json`：本地路径配置示例。

## 环境配置

`setup.ps1` 负责的部分：

- Faster-Whisper-XXL（含 ffmpeg）：下载到 `_tools/app/`，整个仓库可整体搬家。
- 工作目录：`_inbox/`（待处理）、`视频/`（输出）、`_tools/models/`（模型）。

仍需你自己准备：

- **链接解析**：从抖音/B 站/小红书的分享链接拿到媒体直链。推荐 `winget install yt-dlp.yt-dlp`；也可用你自己的解析脚本或手工提供直链。
- **知识库目录**：Obsidian 或其他 Markdown 目录，用于同步整理稿。

工具装在别处时，设置环境变量 `VTT_ROOT` 指向该目录即可，脚本不用改。

默认本地 CPU 推理，不上传音频，不调用外部转写服务。

> 实测参考：medium 模型首次运行要把模型载入内存，一段 3 秒音频总耗时 108 秒，绝大部分是加载时间；批量处理长视频时这部分只付一次。

## 归档结构

```text
workspace/
├── _inbox/                         # 待处理媒体
├── 视频/
│   └── 平台-内容编号/
│       ├── 内容编号.mp4            # 视频原片（可按需删除）
│       ├── 内容编号.vtt            # 完整转写的原始字幕
│       ├── 内容编号.md             # 人工整理后的干净稿
│       └── 来源.md                 # 分享文本、解析和处理记录
└── output/                         # 解析日志和临时资料
```

图文帖没有视频时不伪造 MP4；BGM 或无法确认人声时不伪造 VTT。
