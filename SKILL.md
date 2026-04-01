---
name: bilibili-note
version: 2.0.0
description: >
  Bilibili video note generation with full audio transcription and keyframe illustration.
  When the user provides a Bilibili URL (bilibili.com/video/BV...)
  and asks to summarize, take notes, generate notes, analyze a video,
  or create a structured breakdown of a B站视频, use this skill.
  Triggers for requests like "帮我分析这个视频", "做笔记", "生成笔记",
  "帮我整理这个视频内容", "generate notes from this video".
metadata:
  requires:
    bins: ["yt-dlp", "ffmpeg"]
---

# Bilibili Video Note Generator

You are an AI note-taking assistant. Given a Bilibili video URL, you will:
1. Download the video
2. Transcribe the full audio content
3. Analyze the transcript to create comprehensive, structured notes
4. Extract keyframes as illustrations at the most visually important moments
5. Produce a Markdown note where **content is king** and keyframes are supplementary illustrations

**Core principle**: Notes are driven by AUDIO CONTENT, not by keyframes. Keyframes are illustrations placed at relevant points, not the organizing structure.

## Step 0: Dependency Check

Check that `yt-dlp` and `ffmpeg` are installed:

```bash
which yt-dlp && yt-dlp --version
which ffmpeg && ffmpeg -version | head -1
```

Also check transcription capability:

```bash
python3 -c "import mlx_whisper; print('mlx-whisper OK')" 2>/dev/null || echo "mlx-whisper not available"
```

If yt-dlp or ffmpeg is missing, tell the user to install:
`brew install yt-dlp ffmpeg`

If mlx-whisper is not available, the skill will fall back to:
1. B站 CC subtitles (if available)
2. Ask the user for an OpenAI API key for API-based transcription

## Step 1: Ask User for Output Directory

Ask the user where to save the output. Example:
"请告诉我你想把笔记保存到哪个目录？（默认保存到当前目录）"

Create a subdirectory `bilibili-note-<BVid>/` under the chosen path.

## Step 2: Download Video + Metadata

Extract the BV ID from the URL, then run:

```bash
bash ~/.agents/skills/bilibili-note/scripts/download.sh \
  "https://www.bilibili.com/video/BVxxxxx" \
  /tmp/bilibili-note-BVxxxxx
```

For login-required videos, add cookies:
`--cookies-from-browser chrome`

For multi-part videos, specify part:
`--part 2`

After download, read the output JSON for file paths.

## Step 3: Read Video Metadata

Read the `info.json` file. Extract:
- `title`, `uploader`, `duration`, `upload_date`, `description`, `tags`, `chapters`

## Step 4: Transcribe Audio

This is the MOST IMPORTANT step. The transcript is the foundation of the notes.

**Priority order for getting transcript:**

1. **CC subtitles** — If the download step found `.srt` subtitle files, use them directly.
2. **mlx-whisper (local)** — Default method, no API key needed:

```bash
bash ~/.agents/skills/bilibili-note/scripts/transcribe.sh \
  /tmp/bilibili-note-BVxxxxx/video.mp4 \
  /tmp/bilibili-note-BVxxxxx \
  --method mlx
```

3. **API transcription** — If mlx-whisper is unavailable and user provides an API key:

```bash
bash ~/.agents/skills/bilibili-note/scripts/transcribe.sh \
  /tmp/bilibili-note-BVxxxxx/video.mp4 \
  /tmp/bilibili-note-BVxxxxx \
  --method api \
  --api-key <key>
```

The transcription outputs:
- `transcript.txt` — Full plain text transcript
- `transcript.srt` — Timestamped subtitles
- `transcript.json` — Full structured data with segments and timestamps

**Important**: Tell the user this step takes time. For mlx-whisper on a 15-minute video, expect 2-5 minutes. For longer videos, proportionally more.

## Step 5: Analyze Transcript and Generate Notes

Read the full `transcript.txt` (or subtitle `.srt` file).

Based on the COMPLETE transcript, generate comprehensive structured notes:

1. **Understand the full content** — Read every word, identify all topics, arguments, data points, examples, and conclusions.

2. **Organize into sections** — Group related content into logical sections based on topic flow, NOT based on keyframe timestamps. Sections should reflect the video's natural structure.

3. **Write detailed notes** — For each section, write substantive notes that capture:
   - Key arguments and reasoning
   - Specific data points, numbers, formulas mentioned
   - Practical advice and actionable takeaways
   - Examples given by the speaker
   - Nuances and caveats mentioned

4. **Identify keyframe timestamps** — AFTER writing the content, go back and identify 5-10 moments where a visual screenshot would enhance understanding. Prioritize:
   - Diagrams, charts, or data tables shown on screen
   - Slides with key formulas or lists
   - Demonstrations or visual examples
   - Section transitions with title cards

5. **Don't force keyframes** — Some sections may not need a keyframe. That's fine. Keyframes are optional illustrations, not required for every section.

## Step 6: Extract Keyframes

Using the timestamps identified in Step 5:

```bash
bash ~/.agents/skills/bilibili-note/scripts/extract_keyframes.sh \
  /tmp/bilibili-note-BVxxxxx/video.mp4 \
  /tmp/bilibili-note-BVxxxxx/frames \
  00:01:15 00:03:42 00:07:20 ...
```

Then read each extracted frame image to describe what's in it.

## Step 7: Write Final Markdown Note

The note structure should be:

```markdown
# {Video Title}

> Source: [link](url) | Author: {name} | Duration: {HH:MM:SS} | Date: {date}

## 摘要

{3-5 sentence comprehensive summary based on full transcript}

---

## {Section 1 Title}

{Detailed notes from transcript for this section. Capture all key points, data, advice.}

![Section illustration](frames/frame_XX_XX_XX.jpg)

{Continue with more details if needed.}

## {Section 2 Title}

{Detailed notes...}

{Some sections may not have keyframes — that's perfectly fine.}

---

## 要点总结

- {Key takeaway 1}
- {Key takeaway 2}
- ...

## 时间索引

| # | Timestamp | Section |
|---|-----------|---------|
| 1 | HH:MM:SS | Section Title |
```

**Key differences from v1:**
- Notes are organized by CONTENT sections, not by keyframe timestamps
- Keyframes are embedded WITHIN sections as illustrations, not as section headers
- Notes are comprehensive, based on full transcript analysis
- Some sections may not have keyframes
- Summary and key takeaways sections are added

## Step 8: Deliver and Cleanup

Copy results to user's output directory:

```bash
cp -r /tmp/bilibili-note-BVxxxxx/frames "<user_output_dir>/frames"
cp notes.md "<user_output_dir>/notes.md"
```

Ask user about cleaning up temp video file.

## Edge Cases

### No Transcription Available
If neither subtitles nor whisper transcription works:
- Fall back to metadata + evenly-spaced keyframes
- Clearly label the notes as "estimated content, no transcript available"

### Multi-Part Videos
Ask user: "This video has N parts. Process all, or a specific part?"

### Very Long Videos (>60 min)
- Warn about processing time
- Cap keyframes at 15
- Consider suggesting the user specify a time range

### Download Failures
- **403**: Suggest `--cookies-from-browser chrome`
- **Timeout**: Suggest `--retries 3`
- **Not found**: Verify URL

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `scripts/download.sh` | Download video + subs + metadata |
| `scripts/transcribe.sh` | Extract audio and transcribe (mlx-whisper or API) |
| `scripts/probe_video.sh` | Get video tech info |
| `scripts/extract_keyframes.sh` | Extract frames at timestamps |
