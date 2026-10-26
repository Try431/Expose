#!/usr/bin/env bash
# Tests for mobile-videos.sh and expose.sh's mobile pass, with ffmpeg stubbed
# so nothing is really encoded. Creates a fake site: two video folders with
# fake mp4s that carry a real-looking x264 settings string.

set -u
scriptdir=$(cd "$(dirname "$0")" && pwd)
expose_dir=$(cd "$scriptdir/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0

check(){
	if [ "$2" != "$3" ]; then
		echo "FAIL: $1 (expected [$3], got [$2])"
		fail=1
	fi
}

# --- fake ffmpeg: logs args, creates the output file (last arg) ---
mkdir "$tmp/bin"
cat > "$tmp/bin/ffmpeg-stub" <<'EOF'
#!/usr/bin/env bash
echo "$@" >> "$FFMPEG_LOG"
out="${@: -1}"
[ "$out" = "/dev/null" ] || mkdir -p "$(dirname "$out")"
[ "$out" = "/dev/null" ] || printf 'stub' > "$out"
exit 0
EOF
chmod +x "$tmp/bin/ffmpeg-stub"
export FFMPEG="$tmp/bin/ffmpeg-stub"
export FFMPEG_LOG="$tmp/ffmpeg.log"

mkvideo(){
	# mkvideo <dir> <res> <bitrate-kbps>
	mkdir -p "$1"
	{
		printf 'x264 - core 164 - H.264/MPEG-4 AVC codec - Copyleft 2003-2022 - '
		printf 'options: cabac=1 ref=16 bframes=8 rc=2pass bitrate=%s vbv_maxrate=%d\n' "$3" "$((3*2))"
		head -c 4096 /dev/zero 2>/dev/null || true
	} > "$1/$2-h264.mp4"
}

site="$tmp/site"
mkdir -p "$site/gal1/000" "$site/gal1/001" "$site/gal2/005" "$site/gal2/007"

# gal1/000: full ladder 3840->1280, gal2/005: 1920+1280 only,
# gal1/001: 1280 only, gal2/007: already has a mobile file
mkvideo "$site/gal1/000" 3840 42000
mkvideo "$site/gal1/000" 2560 35000
mkvideo "$site/gal1/000" 1920 16000
mkvideo "$site/gal1/000" 1280 7000
mkvideo "$site/gal1/001" 1280 7000
mkvideo "$site/gal2/005" 1920 12000
mkvideo "$site/gal2/005" 1280 7000
mkvideo "$site/gal2/007" 1280 7000
touch "$site/gal2/007/1280-h264-mobile.mp4"

# --- run the batch script ---
"$expose_dir/mobile-videos.sh" "$site" >/dev/null || { echo "FAIL: script exited non-zero"; fail=1; }

check "1920 mobile for gal1/000" "$([ -f "$site/gal1/000/1920-h264-mobile.mp4" ] && echo yes)" "yes"
check "1280 mobile for gal1/000" "$([ -f "$site/gal1/000/1280-h264-mobile.mp4" ] && echo yes)" "yes"
check "no 2560 mobile for gal1/000" "$([ -f "$site/gal1/000/2560-h264-mobile.mp4" ] && echo yes)" ""
check "1280 mobile for gal1/001" "$([ -f "$site/gal1/001/1280-h264-mobile.mp4" ] && echo yes)" "yes"
check "1920+1280 mobile for gal2/005" "$([ -f "$site/gal2/005/1920-h264-mobile.mp4" ] && [ -f "$site/gal2/005/1280-h264-mobile.mp4" ] && echo yes)" "yes"

# one pass-1 per encoded video (3 videos: gal1/000, gal1/001, gal2/005)
check "pass 1 count" "$(grep -c -- '-pass 1' "$FFMPEG_LOG")" "3"
# pass-2 count = 1920+1280 + 1280 + 1920+1280 = 5
check "pass 2 count" "$(grep -c -- '-pass 2' "$FFMPEG_LOG")" "5"
check "ref/bframes override" "$(grep -c 'ref=4:bframes=3' "$FFMPEG_LOG" | awk 'NR==1')" "$(grep -c . "$FFMPEG_LOG")"
check "veryslow preset kept" "$(grep -c -- '-preset veryslow' "$FFMPEG_LOG")" "8"
check "no -r flag (framerate kept)" "$(grep -c -- ' -r ' "$FFMPEG_LOG")" "0"
# bitrate matching: gal1/000 1920 file was 16000kbps -> 16M; 1280 -> 7M
check "1920 bitrate from file" "$(grep -- '-pass 2' "$FFMPEG_LOG" | grep -c 'b:v 16M')" "1"
check "1920 bitrate gal2" "$(grep -- '-pass 2' "$FFMPEG_LOG" | grep -c 'b:v 12M')" "1"
check "1280 bitrate" "$(grep -- '-pass 2' "$FFMPEG_LOG" | grep -c 'b:v 7M')" "3"
# source is the largest existing file: gal1/000 -> 3840
check "source is largest res" "$(grep -c "gal1/000/3840-h264.mp4" "$FFMPEG_LOG" | awk 'NR==1')" "3"
# pass log prefix is the per-video mobile log
check "mobile passlog" "$(grep -c 'passlogfile.*ffmpeg-mobile' "$FFMPEG_LOG")" "8"

# --- resume: second run encodes nothing new ---
rm -f "$FFMPEG_LOG"
"$expose_dir/mobile-videos.sh" "$site" >/dev/null
check "resume encodes nothing" "$([ -f "$FFMPEG_LOG" ] && wc -l < "$FFMPEG_LOG" || echo 0)" "0"

# --- --force re-encodes ---
"$expose_dir/mobile-videos.sh" "$site" --force >/dev/null
check "--force re-encodes" "$(grep -c -- '-pass 2' "$FFMPEG_LOG")" "6"

# --- dry run writes nothing ---
rm -f "$site"/gal*/0*/{1920,1280}-h264-mobile.mp4 "$FFMPEG_LOG"
"$expose_dir/mobile-videos.sh" "$site" --dry-run >/dev/null
check "dry run makes no files" "$(ls "$site"/gal*/0*/*-mobile.mp4 2>/dev/null | wc -l)" "0"

# --- expose.sh wires up mobile.sh and gates on mobile_video ---
check "expose.sh sources mobile.sh" "$(grep -c 'scriptdir/mobile.sh' "$expose_dir/expose.sh")" "1"
check "mobile block gated on mobile_video" "$(grep -c 'mobile_video" = true' "$expose_dir/expose.sh")" "1"
check "mobile encode uses mobile_pass" "$(grep -c 'mobile_pass[12]' "$expose_dir/expose.sh")" "2"

[ "$fail" = 0 ] && echo "PASS" || echo "FAILED"
exit "$fail"
