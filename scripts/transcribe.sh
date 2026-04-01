#!/usr/bin/env bash
# transcribe.sh - Extract audio and transcribe with mlx-whisper
# Usage: transcribe.sh <video_path> <output_dir> [--method mlx|api] [--api-key <key>]
# Output: JSON on stdout with transcript file path

set -euo pipefail

VIDEO_PATH=""
OUTPUT_DIR=""
METHOD="mlx"
API_KEY=""
API_BASE="https://api.openai.com/v1"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --method)
      METHOD="$2"
      shift 2
      ;;
    --api-key)
      API_KEY="$2"
      shift 2
      ;;
    --api-base)
      API_BASE="$2"
      shift 2
      ;;
    *)
      if [[ -z "$VIDEO_PATH" ]]; then
        VIDEO_PATH="$1"
      elif [[ -z "$OUTPUT_DIR" ]]; then
        OUTPUT_DIR="$1"
      fi
      shift
      ;;
  esac
done

if [[ -z "$VIDEO_PATH" || -z "$OUTPUT_DIR" ]]; then
  echo "Usage: transcribe.sh <video_path> <output_dir> [--method mlx|api] [--api-key <key>]" >&2
  exit 1
fi

if ! command -v ffmpeg &>/dev/null; then
  echo '{"error": "ffmpeg not found. Install: brew install ffmpeg"}' >&2
  exit 1
fi

if [[ ! -f "$VIDEO_PATH" ]]; then
  echo "{\"error\": \"File not found: $VIDEO_PATH\"}" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Step 1: Extract audio as WAV
AUDIO_FILE="${OUTPUT_DIR}/audio.wav"
echo "Extracting audio..." >&2
ffmpeg -y -i "$VIDEO_PATH" -vn -acodec pcm_s16le -ar 16000-ac 1 "$AUDIO_FILE" 2>/dev/null

if [[ ! -f "$AUDIO_FILE" ]]; then
  echo '{"error": "Failed to extract audio from video"}' >&2
  exit 1
fi

# Step 2: Transcribe
TRANSCRIPT_FILE="${OUTPUT_DIR}/transcript.txt"
TRANSCRIPT_SRT="${OUTPUT_DIR}/transcript.srt"

if [[ "$METHOD" == "mlx" ]]; then
  # Use mlx-whisper locally
  if ! python3 -c "import mlx_whisper" 2>/dev/null; then
    echo '{"error": "mlx-whisper not installed. Run: pip3 install mlx-whisper"}' >&2
    exit 1
  fi

  echo "Transcribing with mlx-whisper (this may take a few minutes)..." >&2
  python3 -c "
import mlx_whisper
import json
import sys

result = mlx_whisper.transcribe(
    sys.argv[1],
    path_or_hf_repo_id='mlx-community/whisper-large-v3-turbo',
    language='zh',
    word_timestamps=True,
    verbose=False
)

# Save plain text
with open(sys.argv[2], 'w') as f:
    f.write(result['text'])

# Save SRT with timestamps
with open(sys.argv[3], 'w') as f:
    for i, seg in enumerate(result.get('segments', []), 1):
        start = seg['start']
        end = seg['end']
        text = seg['text'].strip()
        if not text:
            continue
        h1, m1, s1 = int(start//3600), int((start%3600)//60), start%60
        h2, m2, s2 = int(end//3600), int((end%3600)//60), end%60
        f.write(f'{i}\\n')
        f.write(f'{h1:02d}:{m1:02d}:{s1:05.3f} --> {h2:02d}:{m2:02d}:{s2:05.3f}\\n')
        f.write(f'{text}\\n\\n')

# Output JSON
output = {
    'text': result['text'],
    'segments': result.get('segments', []),
    'duration': result.get('segments', [{}])[-1].get('end', 0) if result.get('segments') else 0
}
with open(sys.argv[4], 'w') as f:
    json.dump(output, f, ensure_ascii=False)

print(json.dumps({
    'transcript': sys.argv[2],
    'srt': sys.argv[3],
    'full_json': sys.argv[4],
    'duration': output['duration'],
    'segment_count': len(result.get('segments', []))
}))
" "$AUDIO_FILE" "$TRANSCRIPT_FILE" "$TRANSCRIPT_SRT" "${OUTPUT_DIR}/transcript.json"

elif [[ "$METHOD" == "api" ]]; then
  # Use OpenAI-compatible Whisper API
  if [[ -z "$API_KEY" ]]; then
    echo '{"error": "API key required for api method. Use --api-key <key>"}' >&2
    exit 1
  fi

  echo "Transcribing with API..." >&2
  python3 -c "
import json, sys, requests

api_base = sys.argv[1]
api_key = sys.argv[2]
audio_file = sys.argv[3]
transcript_file = sys.argv[4]
srt_file = sys.argv[5]
json_file = sys.argv[6]

with open(audio_file, 'rb') as f:
    resp = requests.post(
        f'{api_base}/audio/transcriptions',
        headers={'Authorization': f'Bearer {api_key}'},
        files={'file': ('audio.wav', f, 'audio/wav')},
        data={
            'model': 'whisper-1',
            'language': 'zh',
            'response_format': 'verbose_json',
            'timestamp_granularities[]': 'segment'
        }
    )
    resp.raise_for_status()
    result = resp.json()

# Save plain text
with open(transcript_file, 'w') as f:
    f.write(result.get('text', ''))

# Save SRT
with open(srt_file, 'w') as f:
    for i, seg in enumerate(result.get('segments', []), 1):
        start = seg['start']
        end = seg['end']
        text = seg.get('text', '').strip()
        if not text:
            continue
        h1, m1, s1 = int(start//3600), int((start%3600)//60), start%60
        h2, m2, s2 = int(end//3600), int((end%3600)//60), end%60
        f.write(f'{i}\\n')
        f.write(f'{h1:02d}:{m1:02d}:{s2:05.3f} --> {h2:02d}:{m2:02d}:{s2:05.3f}\\n')
        f.write(f'{text}\\n\\n')

# Save full JSON
with open(json_file, 'w') as f:
    json.dump(result, f, ensure_ascii=False)

print(json.dumps({
    'transcript': transcript_file,
    'srt': srt_file,
    'full_json': json_file,
    'duration': result.get('duration', 0),
    'segment_count': len(result.get('segments', []))
}))
" "$API_BASE" "$API_KEY" "$AUDIO_FILE" "$TRANSCRIPT_FILE" "$TRANSCRIPT_SRT" "${OUTPUT_DIR}/transcript.json"

else
  echo "{\"error\": \"Unknown method: $METHOD. Use 'mlx' or 'api'.\"}" >&2
  exit 1
fi

# Clean up audio file to save space
rm -f "$AUDIO_FILE"
