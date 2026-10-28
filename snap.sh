#!/usr/bin/env bash
# snap — capture stills from a Mac/Continuity camera with a live preview,
# an audible countdown, or a burst.
#
# Why this exists: imagesnap's -w warmup is an invisible timer whose progress
# prints in the agent's terminal, not anywhere the user is looking. And the
# iPhone shows no viewfinder when acting as a Continuity Camera. So without
# help the user is aiming blind against a clock they can't see.
set -euo pipefail

DEV=""; MODE="count"; SECS=6; SHOTS=6; EVERY=2
OUTDIR="${TMPDIR:-/tmp}/snap"; QUIET=0; PREVIEW=1; SETTLE=4

usage() {
  cat <<'USAGE'
snap — capture stills from a Mac or Continuity (iPhone) camera

  snap                     countdown capture, built-in camera
  snap -i                  countdown capture, iPhone
  snap -b                  burst: 6 shots, 2s apart (no timing pressure)
  snap -i -b -n 10 -e 1.5  iPhone burst, 10 shots, 1.5s apart
  snap -l                  list cameras
  snap -s 12               12-second countdown (more time to aim)
  snap -o ~/Desktop        keep the files somewhere durable

  -i          iPhone Continuity camera
  -d NAME     specific device by name (substring match)
  -b          burst mode
  -n COUNT    burst: number of shots (default 6)
  -e SECS     burst: seconds between shots (default 2)
  -s SECS     countdown length (default 6)
  -o DIR      output directory (default $TMPDIR/snap)
  -P          no live preview window
  -q          no speech or sounds
  -l          list devices
  -h          this help

A live ffplay preview opens by default so you can see what you're aiming at —
the iPhone itself shows only a "Connected to Mac" screen, never a viewfinder.
The preview closes automatically after the capture.
USAGE
}

while getopts "id:bn:e:s:o:Pqlh" o; do
  case "$o" in
    i) DEV="iPhone" ;;      d) DEV="$OPTARG" ;;
    b) MODE="burst" ;;      n) SHOTS="$OPTARG" ;;
    e) EVERY="$OPTARG" ;;   s) SECS="$OPTARG" ;;
    o) OUTDIR="$OPTARG" ;;  P) PREVIEW=0 ;;
    q) QUIET=1 ;;           l) MODE="list" ;;
    h) usage; exit 0 ;;     *) usage; exit 1 ;;
  esac
done

command -v imagesnap >/dev/null || { echo "imagesnap not installed: brew install imagesnap" >&2; exit 1; }
command -v ffplay    >/dev/null || PREVIEW=0

# imagesnap fails with a misleading "the file doesn't exist" when the PARENT
# directory is missing, so create it up front.
mkdir -p "$OUTDIR"

if [ "$MODE" = list ]; then imagesnap -l 2>/dev/null | grep -v '^$'; exit 0; fi

# Resolve a substring to the full device name. Continuity names contain a
# curly apostrophe (e.g. “Alex’s iPhone Camera”) that is painful to type.
if [ -n "$DEV" ]; then
  # NOTE: `|| true` is load-bearing. Under `set -e` + `pipefail` a non-matching
  # grep fails the whole assignment and kills the script BEFORE the error
  # message below can print — a silent exit 1 with no explanation.
  FULL=$(imagesnap -l 2>/dev/null | sed -n 's/^=> //p' | grep -i -- "$DEV" | head -1 || true)
  if [ -z "$FULL" ]; then
    echo "No camera matching '$DEV'." >&2
    echo "Available now:" >&2
    imagesnap -l 2>/dev/null | sed -n 's/^=> /  /p' >&2
    case "$DEV" in
      *[iI]*[pP]hone*) cat >&2 <<'HINT'

The iPhone is not currently offered as a Continuity Camera. To bring it back:
  - wake the phone and keep it near the Mac
  - Wi-Fi and Bluetooth on, same Apple ID
  - Settings -> General -> AirPlay & Continuity -> Continuity Camera = on
  - it drops off on its own after a period of inactivity; waking it is usually enough
HINT
      ;;
    esac
    exit 1
  fi
  DEV_ARGS=(-d "$FULL"); LABEL="$FULL"
else
  DEV_ARGS=(); LABEL=$(imagesnap -l 2>/dev/null | sed -n 's/^=> //p' | head -1)
fi

# ffplay addresses devices by AVFoundation index, not name — map across.
dev_index() {
  ffmpeg -f avfoundation -list_devices true -i "" 2>&1 \
    | sed -n 's/^\[AVFoundation indev @ [^]]*\] \[\([0-9]*\)\] \(.*\)$/\1 \2/p' \
    | awk -v want="$1" 'index($0, want) { print $1; exit }'
}

say_()  { [ "$QUIET" = 1 ] || say "$@" >/dev/null 2>&1 || true; }
ding_() { [ "$QUIET" = 1 ] || afplay /System/Library/Sounds/Tink.aiff >/dev/null 2>&1 || true; }

PV=""
start_preview() {
  [ "$PREVIEW" = 1 ] || return 0
  local idx; idx=$(dev_index "$LABEL" 2>/dev/null || true)
  [ -n "$idx" ] || { echo "(preview unavailable: no index for '$LABEL')" >&2; return 0; }
  ffplay -loglevel quiet -f avfoundation -framerate 30 -i "$idx" \
         -window_title "snap preview — aim now" >/dev/null 2>&1 &
  PV=$!
  # A cold Continuity link hands ffplay dark frames while the phone wakes and
  # the sensor auto-exposes, and ffplay never re-exposes. Let it settle BEFORE
  # the user's aiming window starts, so the feed is live when they look at it.
  sleep "$SETTLE"
  echo "preview: live window open (device $idx)"
}
stop_preview() { [ -n "$PV" ] && kill "$PV" 2>/dev/null || true; }
trap stop_preview EXIT INT TERM HUP

STAMP=$(date +%Y%m%d-%H%M%S)
echo "camera: $LABEL"

if [ "$MODE" = burst ]; then
  OUT="$OUTDIR/burst-$STAMP.jpg"
  echo "burst : $SHOTS shots, ${EVERY}s apart -> $OUTDIR"
  start_preview
  say_ "Burst starting. Aim now."
  imagesnap -q -w 3 \
    ${DEV_ARGS[@]+"${DEV_ARGS[@]}"} -t "$EVERY" -n "$SHOTS" "$OUT" 2>/dev/null || true
  ding_; say_ "Done."
  stop_preview
  ls -1 "$OUTDIR"/burst-"$STAMP"* 2>/dev/null || { echo "no files written" >&2; exit 1; }
else
  OUT="$OUTDIR/snap-$STAMP.jpg"
  echo "capture in ${SECS}s -> $OUT"
  start_preview
  say_ "Capturing in $SECS seconds"

  # ONE imagesnap call only. Calling it twice (once to burn lead time) opened
  # and closed the device twice, which made Continuity visibly disconnect and
  # reconnect mid-countdown. Speak the last three seconds from a background
  # subshell instead, while the single capture warms up.
  if [ "$QUIET" = 0 ]; then
    LEAD=$(awk -v s="$SECS" 'BEGIN{d=s-3.2; print (d>0)?d:0}')
    ( sleep "$LEAD"; for n in 3 2 1; do say "$n" >/dev/null 2>&1; done ) &
  fi

  imagesnap -q -w "$SECS" ${DEV_ARGS[@]+"${DEV_ARGS[@]}"} "$OUT" 2>/dev/null || true
  wait 2>/dev/null || true
  ding_
  stop_preview
  [ -s "$OUT" ] && echo "$OUT" || { echo "capture failed (empty file)" >&2; exit 1; }
fi
