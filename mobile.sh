# Phone-friendly h264 encodes, shared by expose.sh and mobile-videos.sh.
#
# Mobile decoders struggle with the "veryslow" defaults expose uses
# (ref=16, bframes=8 → H.264 level 5.0, heavy memory + reordering work).
# These encode the same way as the normal files — two passes, same preset,
# same target bitrate and 2x VBV caps — except ref/bframes are limited so
# the hardware decoder can keep up. Framerate is left alone.

mobile_video=${mobile_video:-true}            # encode -mobile files by default
mobile_video_resolutions=${mobile_video_resolutions:-1920 1280}  # widths (1080p, 720p)
mobile_x264_params=${mobile_x264_params:-"ref=4:bframes=3"}
mobile_preset=${mobile_preset:-veryslow}      # same as h264_encodespeed default
FFMPEG=${FFMPEG:-ffmpeg}

# mobile_pass1 <input> <mbit> <logprefix> [extra ffmpeg args...]
# Pass 1 at source resolution, once per video. x264 requires pass 2 to have
# the same bframes count as pass 1, so the mobile encodes get their own log
# (ffmpeg-mobile* — already covered by expose.sh's ffmpeg*.log/.mbtree cleanup).
mobile_pass1(){
	local input="$1" mbit="$2" logprefix="$3"; shift 3
	local max=$((mbit * 2))
	"$FFMPEG" -loglevel error -nostdin -y -i "$input" -c:v libx264 \
		-threads "${ffmpeg_threads:-0}" "$@" \
		-profile:v high -pix_fmt yuv420p -preset "$mobile_preset" \
		-x264-params "$mobile_x264_params" \
		-b:v "${mbit}M" -maxrate "${max}M" -bufsize "${max}M" \
		-pass 1 -passlogfile "$logprefix" -an -f mp4 /dev/null
}

# mobile_pass2 <input> <res> <mbit> <logprefix> <output> [extra ffmpeg args...]
# Pass 2 scaled to <res>, same bitrate math as expose.sh (2x maxrate/bufsize).
# The audio flag comes through the extra args (-an or -c:a copy, like $audio
# in expose.sh).
mobile_pass2(){
	local input="$1" res="$2" mbit="$3" logprefix="$4" output="$5"; shift 5
	local max=$((mbit * 2))
	"$FFMPEG" -loglevel error -nostdin -y -i "$input" -c:v libx264 \
		-threads "${ffmpeg_threads:-0}" "$@" \
		-vf "scale=$res:trunc(ow/a/2)*2" \
		-profile:v high -pix_fmt yuv420p -preset "$mobile_preset" \
		-x264-params "$mobile_x264_params" \
		-b:v "${mbit}M" -maxrate "${max}M" -bufsize "${max}M" \
		-pass 2 -passlogfile "$logprefix" -movflags +faststart -f mp4 "$output"
}

# x264_bitrate_of <file> → echoes the target bitrate in kbps (e.g. 7000),
# read from the encoder settings string x264 embeds in the file.
# Prints nothing if it can't find one.
x264_bitrate_of(){
	head -c 400000 "$1" 2>/dev/null | strings -n 20 | grep -o -m1 'bitrate=[0-9]*' | cut -d= -f2
}
