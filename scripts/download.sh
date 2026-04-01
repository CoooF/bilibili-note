#!/usr/bin/env bash
# download.sh - Download Bilibili video + subtitles + metadata via yt-dlp
# Usage: download.sh <url> <output_dir> [--cookies-from-browser <browser>] [--part <N>]
# Output: JSON on stdout

set -euo pipefail

URL=""
OUTPUT_DIR=""
COOKIES_FLAG=""
PART=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cookies-from-browser)
      COOKIES_FLAG="--cookies-from-browser $2"
      shift 2
      ;;
    --part)
      PART="$2"
      shift 2
      ;;
    *)
      if [[ -z "$URL" ]]; then
        URL="$1"
      elif [[ -z "$OUTPUT_DIR" ]]; then
        OUTPUT_DIR="$1"
      fi
      shift
      ;;
  esac
done

if [[ -z "$URL" || -z "$OUTPUT_DIR" ]]; then
  echo "Usage: download.sh <url> <output_dir> [--cookies-from-browser <browser>] [--part <N>]" >&2
  exit 1
fi

# Check dependencies
if ! command -v yt-dlp &>/dev/null; then
  echo '{"error": "yt-dlp not installed. Run: brew install yt-dlp"}' >&2
  exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Build download URL with part number if specified
DOWNLOAD_URL="$URL"
if [[ -n "$PART" ]]; then
  # Append ?p=N to URL
  if [[ "$URL" == *"?"* ]]; then
    DOWNLOAD_URL="${URL}&p=${PART}"
  else
    DOWNLOAD_URL="${URL}?p=${PART}"
  fi
fi

# Determine output filename
if [[ -n "$PART" ]]; then
  OUT_TEMPLATE="${OUTPUT_DIR}/video_p${PART}.%(ext)s"
else
  OUT_TEMPLATE="${OUTPUT_DIR}/video.%(ext)s"
fi

# Download video + subtitles + metadata
yt-dlp \
  --no-playlist \
  -f "bestvideo[height<=1080]+bestaudio/best[height<=1080]" \
  --merge-output-format mp4 \
  -o "$OUT_TEMPLATE" \
  --write-info-json \
  --write-subs --write-auto-subs \
  --sub-langs "zh-Hans,zh-Hant,en,chi,jpn" \
  --convert-subs srt \
  --no-check-certificates \
  $COOKIES_FLAG \
  "$DOWNLOAD_URL" 2>&1 || true

# Find the downloaded video file
VIDEO_FILE=""
for ext in mp4 mkv webm; do
  found=$(find "$OUTPUT_DIR" -maxdepth 1 -name "video*.${ext}" -type f 2>/dev/null | head -1)
  if [[ -n "$found" ]]; then
    VIDEO_FILE="$found"
    break
  fi
done

if [[ -z "$VIDEO_FILE" ]]; then
  echo '{"error": "Video download failed. Try adding --cookies-from-browser chrome for login-required videos."}' >&2
  exit 1
fi

# Find metadata file
METADATA_FILE=$(find "$OUTPUT_DIR" -maxdepth 1 -name "video*.info.json" -type f 2>/dev/null | head -1)

# Find subtitle files
SUBTITLE_FILES=()
while IFS= read -r f; do
  SUBTITLE_FILES+=("\"$f\"")
done < <(find "$OUTPUT_DIR" -maxdepth 1 -name "video*.srt" -type f 2>/dev/null)

# Get duration from metadata or ffprobe
DURATION=""
if [[ -n "$METADATA_FILE" ]] && command -v python3 &>/dev/null; then
  DURATION=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    d = json.load(f)
print(d.get('duration', ''))
" "$METADATA_FILE" 2>/dev/null || echo "")
fi

# Output JSON
if [[ ${#SUBTITLE_FILES[@]} -gt 0 ]]; then
  SUBLIST=$(IFS=,; echo "${SUBTITLE_FILES[*]}")
else
  SUBLIST=""
fi
cat <<EOF
{
  "video": "$VIDEO_FILE",
  "subtitles": [$SUBLIST],
  "metadata": "${METADATA_FILE:-}",
  "duration": ${DURATION:-0}
}
EOF
