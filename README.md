# bilibili-note

一个 Claude Code Skill，用于将 B 站视频自动转化为结构化 Markdown 笔记。

**核心思路**：先转录完整音频，基于全量内容生成笔记，再在关键位置插入视频截图作为配图。

## 功能特点

- 输入一个 B 站视频链接，输出一份完整的 Markdown 笔记
- 支持**完整音频转录**（mlx-whisper 本地运行 或 OpenAI API）
- AI 驱动的**内容分析**：基于转录文本组织章节、提取要点
- 自动截取视频**关键帧截图**，作为笔记配图
- 支持 B 站多 P 视频、登录视频（cookie）、超长视频
- 输出纯 Markdown，方便在任何平台使用

## 工作流程

```
用户输入 B 站 URL
       ↓
Step 1: yt-dlp 下载视频 + 元数据
       ↓
Step 2: 提取音频 → mlx-whisper / API 转录
       ↓
Step 3: AI 分析完整转录文本，生成结构化笔记
       ↓
Step 4: 在关键位置截取视频帧作为配图
       ↓
输出: notes.md + frames/*.jpg + transcript.txt
```

## 安装

### 1. 安装依赖

```bash
brew install yt-dlp ffmpeg
pip3 install mlx-whisper   # 本地转录（推荐 Apple Silicon 用户）
```

### 2. 安装 Skill

```bash
# 克隆仓库
git clone https://github.com/CoooF/bilibili-note.git

# 复制到 Claude Code Skills 目录
mkdir -p ~/.agents/skills
cp -r bilibili-note ~/.agents/skills/bilibili-note

# 创建符号链接
ln -sf ../../.agents/skills/bilibili-note ~/.claude/skills/bilibili-note
```

## 使用方法

在 Claude Code 中直接说：

```
帮我分析这个视频：https://www.bilibili.com/video/BVxxxxx
```

或者：

```
把这个 B 站视频做成笔记：https://www.bilibili.com/video/BVxxxxx
```

Skill 会自动触发，依次执行下载、转录、分析、截图、生成笔记的完整流程。

## 文件结构

```
bilibili-note/
├── SKILL.md                        # Skill 主定义（Claude Code 读取）
├── scripts/
│   ├── download.sh                 # yt-dlp 下载视频 + 字幕 + 元数据
│   ├── transcribe.sh               # 音频转录（支持 mlx / api 两种模式）
│   ├── probe_video.sh              # 视频信息探测
│   └── extract_keyframes.sh        # 按时间戳截取关键帧
└── references/
    └── output-template.md          # Markdown 输出模板
```

## 输出示例

对于每个视频，输出目录包含：

```
bilibili-note-BVxxxxx/
├── notes.md           # 结构化 Markdown 笔记（主要内容）
├── transcript.txt     # 完整音频转录文本
├── transcript.srt     # 带时间戳的字幕文件
├── video.mp4          # 原始视频（可选保留）
└── frames/            # 关键帧截图
    ├── frame_00_03_00.jpg
    ├── frame_00_06_15.jpg
    └── ...
```

笔记内容基于完整音频转录，组织为：
- 标题 + 来源信息
- 内容摘要
- 按主题划分的详细章节（含配图）
- 要点总结
- 时间索引表

## 转录方式

### 方式一：mlx-whisper（本地，推荐）

Apple Silicon Mac 上最快，无需联网，无需 API Key。

```bash
pip3 install mlx-whisper
```

使用 `whisper-large-v3-turbo` 模型，16 分钟视频约 2 分钟完成转录。

### 方式二：OpenAI API

如果你有 OpenAI API Key，可以调用 Whisper API 进行转录：

```bash
# 在使用时指定
--method api --api-key sk-xxxxx
```

也支持兼容 OpenAI 接口的第三方服务，通过 `--api-base` 指定地址。

## 常见问题

### 视频下载失败（403）

部分视频需要登录才能下载，添加 cookie：

```bash
--cookies-from-browser chrome
```

### 转录速度慢

mlx-whisper 首次运行需要下载模型（约 800MB），之后会缓存。建议使用 `whisper-large-v3-turbo`（默认）兼顾速度和质量。

### 支持多 P 视频吗？

支持。默认处理第一 P，也可以指定处理所有分 P。

## 致谢

灵感来源：[把 YouTube 视频变成 LaTeX-rendered 学术 PDF](https://waytoagi.feishu.cn/wiki/DB29w2Ai8i4YvykVc61c9wpCnEf)

## License

MIT
