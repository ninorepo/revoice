#!/usr/bin/env bash

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 input.srt conjunctions.txt"
  exit 1
fi

INPUT="$1"
CONJ="$2"

awk -v conj_file="$CONJ" '

# =========================================================
# LOAD CONJUNCTIONS
# =========================================================
FNR==NR {
  gsub(/\r/, "")
  if ($1 != "") conj[$1] = 1
  next
}

# =========================================================
# RESET BLOCK STATE
# =========================================================
function reset_block() {
  seg_count = 0
  cur = ""
}

# =========================================================
# TRIM FUNCTION
# =========================================================
function trim(s) {
  gsub(/^[ \t]+|[ \t]+$/, "", s)
  return s
}

# =========================================================
# TIME: SRT -> MS
# =========================================================
function to_ms(t,   a,b,h,m,s,ms) {
  gsub(/\r/,"",t)
  split(t,a,":")
  split(a[3],b,",")
  h=a[1]; m=a[2]; s=b[1]; ms=b[2]
  return ((h*3600 + m*60 + s)*1000 + ms)
}

# =========================================================
# TIME: MS -> SRT
# =========================================================
function to_time(ms,   h,m,s) {
  h=int(ms/3600000); ms%=3600000
  m=int(ms/60000);   ms%=60000
  s=int(ms/1000);    ms%=1000
  return sprintf("%02d:%02d:%02d,%03d",h,m,s,ms)
}

# =========================================================
# PUSH SEGMENT (ORDER SAFE)
# =========================================================
function push_segment(txt) {
  txt = trim(txt)
  if (txt == "") return

  seg[++seg_count] = txt
  seg_len[seg_count] = length(txt)
}

# =========================================================
# FLUSH BLOCK (STRICT ORDER GUARANTEED)
# =========================================================
function flush_block(   i,total,start,seg_dur) {

  if (seg_count == 0) return

  total = 0
  for (i = 1; i <= seg_count; i++)
    total += seg_len[i]

  start = block_start

  for (i = 1; i <= seg_count; i++) {

    seg_dur = (total > 0) ? block_dur * seg_len[i] / total : 0

    printf "%d\n", ++out_idx
    printf "%s --> %s\n", to_time(start), to_time(start + seg_dur)
    printf "%s\n\n", seg[i]

    start += seg_dur
  }

  reset_block()
}

# =========================================================
# PROCESS TEXT LINE
# =========================================================
function process_line(line,   i,n,w,last,words) {

  gsub(/\r/,"",line)
  line = trim(line)
  if (line == "") return

  n = split(line, words, /[ ]+/)

  for (i = 1; i <= n; i++) {

    w = words[i]
    last = substr(w, length(w), 1)

    # -------------------------
    # CONJUNCTION RULE
    # -------------------------
    if (conj[w] == 1) {

      if (cur != "") {
        push_segment(cur)
        cur = ""
      }

      cur = w
      continue
    }

    # accumulate words
    cur = (cur == "") ? w : cur " " w

    # -------------------------
    # PUNCTUATION RULE
    # -------------------------
    if (last ~ /[.,;:!?]/) {
      push_segment(cur)
      cur = ""
    }
  }
}

# =========================================================
# MAIN SRT PARSER
# =========================================================
{
  gsub(/\r/,"")

  # -------------------------
  # INDEX LINE (ignored)
  # -------------------------
  if ($0 ~ /^[0-9]+$/) next

  # -------------------------
  # TIMESTAMP LINE
  # -------------------------
  if ($0 ~ /-->/) {
    split($0, t, " --> ")

    block_start = to_ms(t[1])
    block_end   = to_ms(t[2])
    block_dur   = block_end - block_start

    reset_block()
    next
  }

  # -------------------------
  # EMPTY LINE = END BLOCK
  # -------------------------
  if ($0 == "") {
    flush_block()
    next
  }

  # -------------------------
  # SUBTITLE TEXT
  # -------------------------
  process_line($0)
}

END {
  flush_block()
}

' "$CONJ" "$INPUT"



