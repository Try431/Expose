#!/usr/bin/env bash
# Encode phone-friendly "-mobile" versions of a site's h264 gallery videos.
#
#   mobile-videos.sh <site-or-gallery-dir> [--force] [--dry-run]
#
# For every <res>-h264.mp4 in a video folder where <res> is one of
# $mobile_video_resolutions (default "1920 1280"), writes <res>-h264-mobile.mp4
# next to it. Re-encodes from the largest existing version of the video
# (3840 where it exists). Skips videos that already have a -mobile file
# (unless --force), so a run can be stopped and resumed. Writes to a temp
# name and renames on success, so interrupted runs leave no half files.
#
# Bitrate for each output is the one the gallery's existing file was encoded
# at (read from the x264 settings string embedded in it), so mobile files
# match gallery quality. See mobile.sh for the shared settings.

set -uo pipefail
scriptdir=$(cd "$(dirname "$0")" && pwd)
. "$scriptdir/mobile.sh"

dir=""
force=false
dry_run=false
for arg in "$@"; do
	case "$arg" in
		--force) force=true ;;
		--dry-run) dry_run=true ;;
		-*) echo "unknown flag: $arg" >&2; exit 1 ;;
		*) dir="$arg" ;;
	esac
done
[ -z "$dir" ] && { echo "usage: $0 <site-or-gallery-dir> [--force] [--dry-run]" >&2; exit 1; }
[ -d "$dir" ] || { echo "no such directory: $dir" >&2; exit 1; }

if [ "$dry_run" = true ]; then
	FFMPEG="echo"
else
	command -v "$FFMPEG" >/dev/null || { echo "error: ffmpeg not found" >&2; exit 1; }
fi

# fallback when a file's embedded bitrate can't be read (Expose's defaults)
fallback_mbit(){ case "$1" in 1920) echo 16 ;; 1280) echo 7 ;; *) echo 7 ;; esac; }

encoded=0
skipped=0
failed=0

# find folders that contain h264 videos (video folders hold <res>-h264.mp4)
while IFS= read -r d; do
	# source = largest existing resolution of this video
	src=""
	for r in 3840 2560 1920 1280; do
		[ -f "$d/$r-h264.mp4" ] && { src="$d/$r-h264.mp4"; break; }
	done
	[ -z "$src" ] && continue

	# targets = mobile resolutions present as normal encodes, without a -mobile yet
	targets=()
	for r in $mobile_video_resolutions; do
		[ -f "$d/$r-h264.mp4" ] || continue
		if [ "$force" = true ] || [ ! -f "$d/$r-h264-mobile.mp4" ]; then
			targets+=("$r")
		fi
	done
	if [ "${#targets[@]}" -eq 0 ]; then
		skipped=$((skipped + 1))
		continue
	fi

	echo "== ${d#./}  (source: $(basename "$src")$( [ "$(basename "$src")" = "1280-h264.mp4" ] && echo " — smallest only, quality caveat" ))"

	# one pass 1 per video, at the bitrate of the largest target (mirrors expose.sh)
	first="${targets[0]}"
	kb=$(x264_bitrate_of "$d/$first-h264.mp4")
	mbit=$(( ${kb:-0} > 0 ? kb / 1000 : $(fallback_mbit "$first") ))
	logp="$d/ffmpeg-mobile"
	if mobile_pass1 "$src" "$mbit" "$logp"; then
		for r in "${targets[@]}"; do
			kb=$(x264_bitrate_of "$d/$r-h264.mp4")
			tmbit=$(( ${kb:-0} > 0 ? kb / 1000 : $(fallback_mbit "$r") ))
			out="$d/$r-h264-mobile.mp4.tmp"
			echo "    $r-h264-mobile.mp4 (${tmbit}M target)"
			if mobile_pass2 "$src" "$r" "$tmbit" "$logp" "$out" -an && { [ "$dry_run" = true ] || [ -s "$out" ]; }; then
				[ "$dry_run" = true ] || mv -f "$out" "$d/$r-h264-mobile.mp4"
				encoded=$((encoded + 1))
			else
				rm -f "$out"
				echo "    FAILED: $d/$r" >&2
				failed=$((failed + 1))
			fi
		done
	else
		echo "    FAILED pass 1: $d" >&2
		failed=$((failed + ${#targets[@]}))
	fi
	rm -f "$logp".log "$logp".log.mbtree "$logp"-0.log "$logp"-0.log.mbtree 2>/dev/null
done < <(find "$dir" -type d | sort)

echo
echo "done: $encoded encoded, $skipped already up-to-date, $failed failed"
[ "$failed" -eq 0 ]
