#!/usr/bin/env bash
# probe_video.sh - Get video metadata via ffprobe
# Usage: probe_video.sh <video_path>
# Output: JSON on stdout

set -euo pipefail

if [[ -z "${1:-}" ]]; then
  echo "Usage: probe_video.sh <video_path>" >&2
  exit 1
fi

VIDEO_PATH="$1"

if ! command -v ffprobe &>/dev/null; then
  echo '{"error": "ffprobe not found. Install ffmpeg: brew install ffmpeg"}' >&2
  exit 1
fi

if [[ ! -f "$VIDEO_PATH" ]]; then
  echo "{\"error\": \"File not found: $VIDEO_PATH\"}" >&2
  exit 1
fi

ffprobe \
  -v quiet \
  -print_format json \
  -show_format \
  -show_streams \
  "$VIDEO_PATH" | python3 -c "
import json, sys

data = json.load(sys.stdin)
fmt = data.get('format', {})
streams = data.get('streams', [])

# Find video stream
video = next((s for s in streams if s.get('codec_type') == 'video'), {})
audio = next((s for s in streams if s.get('codec_type') == 'audio'), {})

result = {
    'duration_seconds': float(fmt.get('duration', 0)),
    'width': int(video.get('width', 0)),
    'height': int(video.get('height', 0)),
    'fps': video.get('r_frame_rate', '0'),
    'codec': video.get('codec_name', 'unknown'),
    'has_audio': audio is not None and audio != {}
}
print(json.dumps(result, indent=2))
"
