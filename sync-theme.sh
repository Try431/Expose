#!/usr/bin/env bash
# Copies the site's shared runtime files into theme1 so `expose -d` previews
# and new galleries behave like the live site. The site repo is canonical:
# edit the files there, then run this.
#
# Usage: ./sync-theme.sh [path-to-site-repo]
set -e
scriptdir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
site=${1:-"$scriptdir/../Try431.github.io"}

if [ ! -f "$site/global.js" ]
then
	echo "site repo not found at $site" >&2
	exit 1
fi

for f in global.js global.css cookie.js json.js nav.js site.js viewer.js jquery.min.js
do
	cp "$site/$f" "$scriptdir/theme1/$f"
done

for f in camera.png camera_mask.png monitor.png monitor_mask.png text.png text_mask.png favicon.png
do
	cp "$site/img/$f" "$scriptdir/theme1/img/$f"
done

echo "theme1 synced from $site"
