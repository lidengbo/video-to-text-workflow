# Video to Text Workflow

一个面向抖音、B 站、小红书等视频分享链接的本地整理流程：解析直链、下载媒体、先用 Faster-Whisper 在本地转写，再生成干净 Markdown 和来源记录。

## 流程

1. 解析分享链接，获得媒体直链、标题、内容编号和媒体类型。
2. 检查是否已有归档，避免重复下载或覆盖。
3. 下载视频、图片或音频到临时入口目录。
4. 从开头、中段、结尾各抽取约 5–8 秒音频样本，先判断是否有人声。
5. 确认有人声讲解、对白或旁白后，才对完整音轨运行 Faster-Whisper。
6. 纯 BGM、纯音效或无法确认人声时跳过完整转写，只整理画面、字幕和分享文案。
7. 生成原始 VTT（如有）、干净稿和 `来源.md`。
8. 按 `平台-内容编号` 归档；需要时再同步到 Markdown 知识库（可选）。

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

装好工具链后，装一个 yt-dlp 用来解析链接（只需一次）：

```powershell
winget install yt-dlp.yt-dlp
```

然后一条命令跑完整条链路：

```powershell
.\scripts\run.ps1 "https://www.bilibili.com/video/BVxxxxxxxx"
```

它会：解析链接拿到「平台 + 编号」→ 下载到 `_inbox/` → 转写到 `视频/<平台>-<编号>/` → 打印 vtt 路径。常用开关：

```powershell
.\scripts\run.ps1 "<链接>" -KeepVideo        # 转完保留原视频
.\scripts\run.ps1 "<链接>" -NoTranscribe     # 只下载，不转写
.\scripts\run.ps1 ".\_inbox\abc.mp4"         # 也可以直接给本地文件
```

**默认会删除原视频**（转写成功后），想保留就加 `-KeepVideo`。

### 同步到知识库（可选，不需要 Obsidian）

产物就是普通的 `.md` / `.vtt` 文件，放在 `视频/平台-编号/` 里，用记事本、VS Code、Typora 都能打开。**没有 Obsidian 不影响任何功能。**

想把整理稿收进自己的知识库时，转写时顺带同步：

```powershell
.\scripts\run.ps1 "<链接>" -Vault "D:\我的笔记\视频解析"
```

或者整理完（有了 .md）再单独同步一次：

```powershell
.\scripts\publish.ps1 -Archive ".\视频\抖音-xxxx" -Vault "D:\我的笔记\视频解析"
```

目标目录下会建一个同名的 `平台-编号` 文件夹，里面是 `.md` 和 `.vtt`。

只想单独用转写那一步时：

```powershell
.\scripts\transcribe.ps1 ".\_inbox\abc.mp4" -Format vtt,txt,srt -Model large-v3
```

## 从 VTT 到 Markdown 笔记

脚本跑到 vtt 就停了：那是**带时间码、无标点的原始字幕**，直接看很费劲。最后一步是把 vtt 交给 AI 整理，或者按 `templates/note.md` 手工写。

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

产出的 `.md` 放回 `视频/<平台>-<编号>/`，和 vtt、来源记录放在一起。

## 目录

- `SKILL.md`：完整工作流规范（给 Agent 用的）。
- `scripts/run.ps1`：**推荐入口**。链接/本地文件 → 下载 → 转写，一条命令。
- `scripts/setup.ps1`：一键准备工具链（查版本、下载、解压、建目录、检查环境）。
- `scripts/transcribe.ps1`：CPU Faster-Whisper 转写包装脚本，支持多格式、多模型、指定输出目录。
- `scripts/publish.ps1`：把某个归档目录的 .md/.vtt 复制到你的知识库目录（可选步骤）。
- `scripts/_dl.cjs`：支持 HTTP/HTTPS 重定向的 Node.js 下载脚本。
- `scripts/sample_audio.ps1`：抽取开头、中段、结尾音频样本。
- `templates/`：整理稿和来源记录模板。
- `config.example.json`：本地路径配置示例。

## 环境配置

`setup.ps1` 负责的部分：

- Faster-Whisper-XXL（含 ffmpeg）：下载到 `_tools/app/`，整个仓库可整体搬家。
- 工作目录：`_inbox/`（待处理）、`视频/`（输出）、`_tools/models/`（模型）。

GitHub 访问不通时，手动下载安装包后喂给脚本：

```powershell
.\scripts\setup.ps1 -LocalPackage "D:\下载\Faster-Whisper-XXL_r245.4_windows.7z"
```

仍需你自己准备：

- **yt-dlp**：`winget install yt-dlp.yt-dlp`。只用本地文件时可跳过。
- **知识库目录（可选）**：任意 Markdown 目录都行——Obsidian、Logseq，或者干脆一个普通文件夹。**不装 Obsidian 完全不影响使用**，这一步只是把整理稿多复制一份。

> `config.example.json` 只是路径示意，脚本不读取它，参数请走命令行。

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
