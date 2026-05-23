#!/bin/bash

# Speed up MP3 using FFmpeg
#
# Usage:
# ./speedup.sh input.mp3 1.25 output.mp3
#
# Example:
# ./speedup.sh music.mp3 1.5 fast.mp3

INPUT="$1"
SPEED="$2"
OUTPUT="$3"

if [ ! -f "$INPUT" ]; then
    echo "Input file not found"
    exit 1
fi

if [ -z "$SPEED" ]; then
    echo "Missing speed factor"
    exit 1
fi

# FFmpeg atempo supports:
# 0.5 - 2.0
#
# Chain multiple filters for larger speeds

FILTER=""

CURRENT="$SPEED"

while (( $(echo "$CURRENT > 2.0" | bc -l) )); do
    FILTER="${FILTER}atempo=2.0,"
    CURRENT=$(echo "$CURRENT / 2.0" | bc -l)
done

FILTER="${FILTER}atempo=$CURRENT"

echo "Using filter: $FILTER"

ffmpeg \
    -i "$INPUT" \
    -filter:a "$FILTER" \
    -vn \
    -c:a libmp3lame \
    -q:a 2 \
    -y \
    "$OUTPUT"

echo "Done: $OUTPUT"

