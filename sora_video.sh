#!/usr/bin/env bash

# Simple helper for calling Sora's video generation API.
# Usage: sora_video.sh IMAGE_URL [-r RESOLUTION] [-d DURATION_SECONDS] [-p PROMPT]

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: sora_video.sh IMAGE_URL [-r RESOLUTION] [-d DURATION_SECONDS] [-p PROMPT]

Required arguments:
  IMAGE_URL             Public URL to the source image.

Optional flags:
  -r RESOLUTION         Output resolution, defaults to 1280x720.
  -d DURATION_SECONDS   Video length in seconds, defaults to 10.
  -p PROMPT             Text prompt to guide video generation, defaults to none.

Environment:
  OPENAI_API_KEY must be set with your API key.
USAGE
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

image_input=$1
shift

resolution="1280x720"
duration_seconds="10"
prompt=""

while getopts ":r:d:p:h" opt; do
  case $opt in
    r) resolution=$OPTARG ;;
    d) duration_seconds=$OPTARG ;;
    p) prompt=$OPTARG ;;
    h)
      usage
      exit 0
      ;;
    \?)
      echo "Unknown option: -$OPTARG" >&2
      usage
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z ${OPENAI_API_KEY:-} ]]; then
  echo "Error: OPENAI_API_KEY environment variable is not set." >&2
  exit 1
fi

payload=$(python3 - "$image_input" "$resolution" "$duration_seconds" "$prompt" <<'PYCODE'
import json
import sys

image_input, resolution, duration_seconds, prompt = sys.argv[1:5]

try:
    duration_value = int(duration_seconds)
except ValueError:
    print(f"Invalid duration (must be an integer): {duration_seconds}", file=sys.stderr)
    sys.exit(1)

body = {
    "image_input": image_input,
    "resolution": resolution,
    "duration_seconds": duration_value,
}

if prompt:
    body["prompt"] = prompt

print(json.dumps(body))
PYCODE
)

curl -X POST "https://api.sora.com/v1/videos" \
  -H "Authorization: Bearer ${OPENAI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "${payload}"
