#!/bin/bash
# =============================================================================
# Dev launcher for AiTranscribe (system-audio-only fork)
# =============================================================================
# Launches the Debug build and tells it to run the Python backend from this
# repo's slim venv (so Whisper transcription works without the bundled server).
#
# Prereqs (one-time):
#   python3 -m venv venv
#   ./venv/bin/pip install fastapi uvicorn pydantic numpy scipy requests \
#       huggingface_hub psutil omegaconf setproctitle sounddevice python-multipart
#   brew install portaudio whisper-cpp
#   # plus a multilingual ggml model in ~/Library/Application Support/AiTranscribe/models/whisper/
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APP="$(find "$HOME/Library/Developer/Xcode/DerivedData/AiTranscribe-"*/Build/Products/Debug \
  -maxdepth 1 -name 'AiTranscribe.app' 2>/dev/null | head -1)"

if [ -z "$APP" ]; then
  echo "Build not found. Build it first in Xcode (or with xcodebuild), then re-run."
  exit 1
fi

export AITRANSCRIBE_PYTHON="$SCRIPT_DIR/venv/bin/python3"
export AITRANSCRIBE_BACKEND_PATH="$SCRIPT_DIR/backend"

# Stop any previous instance and free the backend port.
pkill -x AiTranscribe 2>/dev/null || true
lsof -ti:8765 | xargs kill -9 2>/dev/null || true
sleep 1

echo "Launching: $APP"
echo "  python : $AITRANSCRIBE_PYTHON"
echo "  backend: $AITRANSCRIBE_BACKEND_PATH"
exec "$APP/Contents/MacOS/AiTranscribe"
