#!/bin/bash

API_KEY="${OPENAI_API_KEY}"

SRT_FILE="$1"
OUTPUT="$2"
INSTRUCTION="${3:-none}"
PROMPT_FILE="$global_path/prompt/prompt.txt"

if [ -z "$SRT_FILE" ]; then
    echo "Usage: ./generate_scene.sh subtitle.srt"
    exit 1
fi

if [ ! -f "$SRT_FILE" ]; then
    echo "SRT file not found"
    exit 1
fi

if [ ! -f "$PROMPT_FILE" ]; then
    echo "prompt.txt not found"
    exit 1
fi

if [[ -e "$OUTPUT" ]]; then
	echo "skip : scene.text already exist"
	exit 1
fi

PROMPT=$(cat "$PROMPT_FILE")
SRT_CONTENT=$(cat "$SRT_FILE")

FULL_PROMPT="$PROMPT

ADDITIONAL INSTRUCTION:
$INSTRUCTION

SRT INOUT :
$SRT_CONTENT"

JSON=$(jq -n \
    --arg chat "$CHAT" \
    --arg prompt "$FULL_PROMPT" \
    '{
        model: $chat,
        messages: [
            {
                role: "user",
                content: $prompt
            }
        ],
        temperature: 0.8
    }')

echo "model: $CHAT"
curl "$HOST"/chat/completions \
    -s \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "$JSON" \
| jq  -r '.choices[0].message.content' > "$OUTPUT"
