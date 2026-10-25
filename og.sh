# helpers for share-preview (og:*) tags, sourced by expose.sh

# meta_value KEY TEXT -> the trimmed value of the first "KEY: value" line
meta_value () {
	local key="$1"
	local line
	while IFS= read -r line
	do
		case "$line" in
		"$key":*)
			local value="${line#*:}"
			value=$(echo "$value" | tr -d '\r\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
			echo "$value"
			return
			;;
		esac
	done <<< "$2"
}

# slugify NAME -> url-friendly name, same transform expose.sh uses for dirs
slugify () {
	echo "$1" | sed 's/[^ a-zA-Z0-9]//g;s/ /-/g' | tr '[:upper:]' '[:lower:]'
}

# og_image_res MAXWIDTH RES... -> largest RES <= 1920 and <= MAXWIDTH;
# the smallest RES when nothing qualifies (e.g. a draft build)
og_image_res () {
	local maxwidth="$1"
	shift
	local best=""
	local smallest=""
	for res in "$@"
	do
		if [ -z "$smallest" ] || [ "$res" -lt "$smallest" ]
		then
			smallest="$res"
		fi
		if [ "$res" -le 1920 ] && [ "$res" -le "$maxwidth" ]
		then
			if [ -z "$best" ] || [ "$res" -gt "$best" ]
			then
				best="$res"
			fi
		fi
	done
	echo "${best:-$smallest}"
}
