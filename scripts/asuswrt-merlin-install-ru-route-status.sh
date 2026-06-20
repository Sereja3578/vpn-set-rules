#!/bin/sh

set -u

ADDON_DIR=${ADDON_DIR:-/jffs/addons/ru-restricted-status}
PAGE_SOURCE=${PAGE_SOURCE:-$ADDON_DIR/ru-restricted-status.asp}
PAGE_STATE=${PAGE_STATE:-$ADDON_DIR/webui-page}
MENU_TITLE=${MENU_TITLE:-RU Routes}

if [ ! -r /usr/sbin/helper.sh ] || [ ! -r "$PAGE_SOURCE" ]; then
  logger -t ru-restricted-status "missing Addons API helper or page source"
  exit 1
fi

# shellcheck disable=SC1091
. /usr/sbin/helper.sh

saved_page=
if [ -r "$PAGE_STATE" ]; then
  saved_page=$(sed -n '1p' "$PAGE_STATE")
fi

case "$saved_page" in
  user[0-9].asp|user[0-9][0-9].asp)
    if [ -f "/www/user/$saved_page" ]; then
      am_webui_page=$saved_page
    else
      am_get_webui_page "$PAGE_SOURCE"
    fi
    ;;
  *)
    am_get_webui_page "$PAGE_SOURCE"
    ;;
esac

if [ "$am_webui_page" = "none" ]; then
  logger -t ru-restricted-status "no free custom web page slot"
  exit 1
fi

cp "$PAGE_SOURCE" "/www/user/$am_webui_page"
printf '%s\n' "$am_webui_page" > "$PAGE_STATE"

if [ ! -f /tmp/menuTree.js ]; then
  cp /www/require/modules/menuTree.js /tmp/menuTree.js
fi

sed -i '/tabName: "RU Routes"/d' /tmp/menuTree.js
sed -i "/url: \"Tools_OtherSettings.asp\", tabName:/a\\{url: \"$am_webui_page\", tabName: \"$MENU_TITLE\"}," /tmp/menuTree.js

umount /www/require/modules/menuTree.js 2>/dev/null || true
mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js

logger -t ru-restricted-status "mounted as $am_webui_page"
printf '%s\n' "$am_webui_page"
