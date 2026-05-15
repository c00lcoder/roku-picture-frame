#!/usr/bin/env bash
# Build a sideloadable .zip for the Roku Picture Frame channel.
#
# Usage:
#   ./build.sh                  # produces picture-frame.zip
#   ./build.sh ROKU_IP USER PW  # build + upload to the Roku dev installer

set -euo pipefail
cd "$(dirname "$0")"

OUT="picture-frame.zip"
rm -f "$OUT"

# Generate icon + splash assets if they aren't checked in yet.
if [ ! -f images/icon_focus_hd.png ]; then
    python3 scripts/gen_assets.py
fi

zip -rq "$OUT" \
    manifest \
    source \
    components \
    images \
    config \
    sample

echo "Built $OUT"

if [ "$#" -ge 1 ]; then
    ROKU_IP="$1"
    ROKU_USER="${2:-rokudev}"
    ROKU_PASS="${3:-}"
    if [ -z "$ROKU_PASS" ]; then
        echo "Provide ROKU_USER and ROKU_PASS to sideload (developer password set on the Roku)."
        exit 1
    fi
    echo "Uploading to http://$ROKU_IP/plugin_install ..."
    curl -s --user "$ROKU_USER:$ROKU_PASS" --digest \
        -F "mysubmit=Install" \
        -F "archive=@$OUT" \
        "http://$ROKU_IP/plugin_install" \
        | grep -oE '<font color="red">[^<]*</font>' || true
    echo "Done. Check the Roku screen."
fi
