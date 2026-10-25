#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."
. ./og.sh

fail(){ echo "FAIL: $1"; exit 1; }

[ "$(meta_value og_cover "$(printf 'width: 30\nog_cover:  007 \nfoo: bar')")" = "007" ] || fail "meta_value basic"
[ -z "$(meta_value og_cover 'width: 30')" ] || fail "meta_value missing key"
[ "$(meta_value og_description 'og_description: A 2-week trip: Scotland')" = "A 2-week trip: Scotland" ] || fail "meta_value colon in value"
[ "$(slugify 'Iceland (Laugavegur)')" = "iceland-laugavegur" ] || fail "slugify"
[ "$(og_image_res 3840 3840 2560 1920 1280)" = "1920" ] || fail "og_image_res normal"
[ "$(og_image_res 1600 3840 2560 1920 1280)" = "1280" ] || fail "og_image_res small source"
[ "$(og_image_res 4000 1024)" = "1024" ] || fail "og_image_res draft build"

echo PASS
