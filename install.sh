#!/bin/bash
set -e
cd "$(dirname "$0")"
for c in ffmpeg ffprobe yad zenity kdialog notify-send magick pdftoppm pdftotext; do
  command -v "$c" >/dev/null || echo "Missing: $c"
done
command -v soffice >/dev/null || echo "Optional, needed only for office documents: soffice (LibreOffice)"
menu=~/.local/share/kio/servicemenus
install -Dm755 dolphin-convert ~/.local/bin/dolphin-convert
install -Dm644 -t ~/.local/share/dolphin-convert/lang lang/*.sh
install -Dm755 -t "$menu" menus/*.desktop
sed -i "s|^Exec=dolphin-convert|Exec=\"$HOME/.local/bin/dolphin-convert\"|" "$menu"/dolphin-convert-*.desktop
kbuildsycoca6
