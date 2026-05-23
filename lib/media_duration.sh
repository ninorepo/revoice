#!/bin/bash

# ==========================================
# Total Audio Duration Calculator
# ==========================================
#
# Usage:
#
# File:
# ./duration.sh audio.mp3
#
# Folder:
# ./duration.sh ./music
#
# With output format:
# ./duration.sh ./music seconds
# ./duration.sh ./music milliseconds
# ./duration.sh ./music minutes
# ./duration.sh ./music hours
# ./duration.sh ./music hms
#
# Formats:
#   seconds       (default)
#   milliseconds
#   minutes
#   hours
#   hms           -> HH:MM:SS
#
# ==========================================

set -euo pipefail

TARGET="${1:-}"
FORMAT="${2:-seconds}"

if [[ -z "$TARGET" ]]; then
    echo "Usage:"
    echo "  $0 <file-or-folder> [format]"
    exit 1
fi

total=0

get_duration() {
    ffprobe -v error \
        -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 \
        "$1"
}

# ------------------------------------------
# Collect duration
# ------------------------------------------

if [[ -f "$TARGET" ]]; then

    duration=$(get_duration "$TARGET")
    total="$duration"

elif [[ -d "$TARGET" ]]; then

    while IFS= read -r -d '' file; do

        duration=$(get_duration "$file")

        [[ -z "$duration" ]] && continue

        total=$(awk "BEGIN {print $total + $duration}")

    done < <(find "$TARGET" -type f \( \
    	-iname "*.mp3"  -o \
    	-iname "*.wav"  -o \
    	-iname "*.flac" -o \
    	-iname "*.m4a"  -o \
    	-iname "*.ogg"  -o \
    	-iname "*.aac"  -o \
    	-iname "*.mp4"  -o \
    	-iname "*.mkv"  -o \
    	-iname "*.webm" -o \
    	-iname "*.mov"  -o \
    	-iname "*.avi"  -o \
    	-iname "*.m4v"  -o \
    	-iname "*.ts"   -o \
    	-iname "*.mts"  -o \
    	-iname "*.3gp" \
     	\) -print0)	
  
else
    echo "Invalid path"
    exit 1
fi

# ------------------------------------------
# Output formatting
# ------------------------------------------

case "$FORMAT" in

    seconds)
        printf "%.3f\n" "$total"
        ;;

    milliseconds|ms)
        awk "BEGIN {printf \"%.0f\n\", $total * 1000}"
        ;;

    minutes|min)
        awk "BEGIN {printf \"%.3f\n\", $total / 60}"
        ;;

    hours|hr)
        awk "BEGIN {printf \"%.3f\n\", $total / 3600}"
        ;;

    hms|string)

        hours=$(awk "BEGIN {print int($total/3600)}")
        minutes=$(awk "BEGIN {print int(($total%3600)/60)}")
        seconds=$(awk "BEGIN {print int($total%60)}")

        printf "%02d:%02d:%02d\n" \
            "$hours" "$minutes" "$seconds"
        ;;

    *)
        echo "Unknown format: $FORMAT"
        echo
        echo "Supported formats:"
        echo "  seconds"
        echo "  milliseconds"
        echo "  minutes"
        echo "  hours"
        echo "  hms"
        exit 1
        ;;
esac
exit 0
