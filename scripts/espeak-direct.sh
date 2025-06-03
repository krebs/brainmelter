#!/usr/bin/env bash
# espeak-direct.sh - Direct streaming of espeak to liquidsoap
# Usage: ./espeak-direct.sh "Text to speak" [--harbor harbor_name] [--voice voice_name] [--effect effect_name]

set -e

# Default values
HARBOR="main"
VOICE="en"
SPEED=150
PITCH=50
VOLUME=1.0
EFFECT="none"
TEXT=""

# Process arguments
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 \"Text to speak\" [OPTIONS]"
    echo "Options:"
    echo "  --harbor NAME    Harbor to stream to (main, fx1, fx2, ambient, drums)"
    echo "  --voice NAME     Voice to use (en, en-us, etc.)"
    echo "  --speed NUMBER   Words per minute (default: 150)"
    echo "  --pitch NUMBER   Pitch 0-99 (default: 50)"
    echo "  --volume NUMBER  Volume 0.0-2.0 (default: 1.0)"
    echo "  --effect NAME    Effect (none, echo, reverb, pitch, vocoder)"
    exit 1
fi

# First arg is the text if it doesn't start with --
if [[ $1 != --* ]]; then
    TEXT="$1"
    shift
fi

# Parse remaining args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --harbor)
            HARBOR="$2"
            shift 2
            ;;
        --voice)
            VOICE="$2"
            shift 2
            ;;
        --speed)
            SPEED="$2"
            shift 2
            ;;
        --pitch)
            PITCH="$2"
            shift 2
            ;;
        --volume)
            VOLUME="$2"
            shift 2
            ;;
        --effect)
            EFFECT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ -z "$TEXT" ]; then
    echo "Error: No text provided"
    exit 1
fi

# Create a temporary file
TEMP_WAV=$(mktemp --suffix=.wav)
trap 'rm -f "$TEMP_WAV"' EXIT

# Generate the speech
echo "Generating speech: \"$TEXT\""
espeak -v "$VOICE" -s "$SPEED" -p "$PITCH" -w "$TEMP_WAV" "$TEXT"

# Choose effect filter
EFFECT_FILTER=""
case "$EFFECT" in
    echo)
        EFFECT_FILTER="-af aecho=0.8:0.9:1000:0.3"
        ;;
    reverb)
        EFFECT_FILTER="-af areverse,aecho=0.8:0.88:60:0.4,areverse"
        ;;
    pitch)
        EFFECT_FILTER="-af asetrate=44100*0.9,aresample=44100"
        ;;
    vocoder)
        EFFECT_FILTER="-af afftfilt=real='hypot(re,im)*sin(0)':imag='hypot(re,im)*cos(0)':win_size=512:overlap=0.75"
        ;;
    none|*)
        EFFECT_FILTER=""
        ;;
esac

# Stream directly to Liquidsoap
echo "Streaming to harbor '$HARBOR' with effect '$EFFECT'..."
ffmpeg -hide_banner -loglevel error \
    -f wav -i "$TEMP_WAV" \
    $EFFECT_FILTER \
    -af "volume=$VOLUME" \
    -c:a libmp3lame -b:a 192k -content_type audio/mpeg \
    -f mp3 "icecast://source:hackme@localhost:8005/$HARBOR"

echo "Done!"