#!/usr/bin/env bash
# Checks that theme1 is in sync with the site repo and that the template
# produces mobile-ready, shared-nav pages.
set -e
cd "$(dirname "$0")/.."
SITE=${1:-/home/isaac/Try431.github.io}

./sync-theme.sh "$SITE" >/dev/null

for f in global.js global.css cookie.js json.js nav.js site.js viewer.js jquery.min.js; do
	diff -q "$SITE/$f" "theme1/$f" >/dev/null || { echo "FAIL: theme1/$f out of sync"; exit 1; }
done

t=theme1/template.html
grep -q '<meta name="viewport" content="width=device-width, initial-scale=1">' "$t" || { echo "FAIL: no viewport"; exit 1; }

# script order jquery -> nav.js -> site.js -> viewer.js -> global.js
n1=$(grep -n '{{basepath}}jquery.min.js' "$t" | cut -d: -f1)
n2=$(grep -n '{{basepath}}nav.js' "$t" | cut -d: -f1)
n3=$(grep -n '{{basepath}}site.js' "$t" | cut -d: -f1)
n4=$(grep -n '{{basepath}}viewer.js' "$t" | cut -d: -f1)
n5=$(grep -n '{{basepath}}global.js' "$t" | cut -d: -f1)
[ -n "$n1" ] && [ "$n1" -lt "$n2" ] && [ "$n2" -lt "$n3" ] && [ "$n3" -lt "$n4" ] && [ "$n4" -lt "$n5" ] || { echo "FAIL: script order"; exit 1; }

grep -q '<h1><a href="/">{{sitetitle}}</a></h1>' "$t" || { echo "FAIL: title link"; exit 1; }
grep -q '<ul id="nav"></ul>' "$t" || { echo "FAIL: nav not shared"; exit 1; }
for k in og_title og_url og_description og_image; do
	grep -q "{{$k}}" "$t" || { echo "FAIL: missing {{$k}}"; exit 1; }
done
! grep -q 'modal-div\|{{navigation}}' "$t" || { echo "FAIL: leftover modal/navigation"; exit 1; }
[ ! -e theme1/img/arrow_cursor.png ] || { echo "FAIL: arrow_cursor.png still exists"; exit 1; }
[ ! -e theme1/img/left_arrow.png ] || { echo "FAIL: left_arrow.png still exists"; exit 1; }

echo PASS
