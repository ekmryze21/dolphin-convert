#!/bin/bash
set -e
cd "$(dirname "$0")"
menu=~/.local/share/kio/servicemenus
if [[ $1 == --uninstall ]]; then
  rm -f ~/.local/bin/dolphin-convert "$menu"/dolphin-convert-{video,audio,image,pdf,office,spreadsheet,presentation}.desktop
  rm -rf ~/.local/share/dolphin-convert ~/.config/dolphin-convert
  kbuildsycoca6
  exit
fi
for c in ffmpeg ffprobe yad zenity kdialog notify-send magick pdftoppm pdftotext pdfunite; do
  command -v "$c" >/dev/null || echo "Missing: $c"
done
command -v soffice >/dev/null || echo "Optional, needed only for office documents: soffice (LibreOffice)"
install -Dm755 dolphin-convert ~/.local/bin/dolphin-convert
install -Dm644 -t ~/.local/share/dolphin-convert/lang lang/*.sh
install -Dm755 -t "$menu" menus/*.desktop
sed -i "s|^Exec=dolphin-convert|Exec=\"$HOME/.local/bin/dolphin-convert\"|" "$menu"/dolphin-convert-*.desktop
kbuildsycoca6
