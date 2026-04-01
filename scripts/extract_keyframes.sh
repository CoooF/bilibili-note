#!/usr/bin/env bash
# extract_keyframes.sh - Extract frames at specific timestamps via ffmpeg
# Usage: extract_keyframes.sh <video_path> <output_dir> <timestamp1> [timestamp2] ...
# Timestamps format: HH:MM:SS or MM:SS or seconds
# Output: JSON array on stdout

set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: extract_keyframes.sh <video_path> <output_dir> <timestamp1> [timestamp2] ..." >&2
  exit 1
fi

VIDEO_PATH="$1"
OUTPUT_DIR="$2"
shift 2
TIMESTAMPS=("$@")

if ! command -v ffmpeg &>/dev/null; then
  echo '{"error": "ffmpeg not found. Install: brew install ffmpeg"}' >&2
  exit 1
fi

if [[ ! -f "$VIDEO_PATH" ]]; then
  echo "{\"error\": \"Video file not found: $VIDEO_PATH\"}" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Get video duration for validation
DURATION=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$VIDEO_PATH" 2>/dev/null || echo "0")
DURATION_SEC=${DURATION%%.*}

RESULTS=("[")
FIRST=true

for TS in "${TIMESTAMPS[@]}"; do
  # Convert timestamp to seconds for validation
  TS_SEC=0
  IFS=':' read -ra PARTS <<< "$TS"
  if [[ ${#PARTS[@]} -eq 3 ]]; then
    TS_SEC=$((10#${PARTS[0]} * 3600 + 10#${PARTS[1]} * 60 + 10#${PARTS[2]}))
  elif [[ ${#PARTS[@]} -eq 2 ]]; then
    TS_SEC=$((10#${PARTS[0]} * 60 + 10#${PARTS[1]}))
  else
    TS_SEC=$((10#${TS}))
  fi

  # Skip if timestamp exceeds duration
  if [[ "$DURATION_SEC" -gt 0 && "$TS_SEC" -gt "$((DURATION_SEC + 5))" ]]; then
    echo "Warning: timestamp $TS exceeds video duration, skipping" >&2
    continue
  fi

  # Sanitize timestamp for filename
  SAFE_TS=$(echo "$TS" | tr ':' '_')
  OUT_FILE="${OUTPUT_DIR}/frame_${SAFE_TS}.jpg"

  # Extract frame using input-level seeking (fast)
  if ffmpeg -y -ss "$TS" -i "$VIDEO_PATH" -frames:v 1 -q:v 2 "$OUT_FILE" 2>/dev/null; then
        if [[ "$FIRST" == true ]]; then
      FIRST=false
    else
      RESULTS+=(",")
    fi
    RESULTS+=("{\"timestamp\": \"$TS\", \"file\": \"$OUT_FILE\"}")
  else
    echo "Warning: failed to extract frame at $TS" >&2
  fi
done

RESULTS+=("]")
echo "${RESULTS[@]}"
