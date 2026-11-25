#!/bin/bash
set -e
cd "$(dirname "$0")"
menu=~/.local/share/kio/servicemenus
if [[ $1 == --uninstall ]]; then
  rm -f ~/.local/bin/dolphin-convert "$menu"/dolphin-convert-{video,audio,image,pdf,office,spreadsheet,presentation}.desktop
  rm -f ~/.local/share/icons/hicolor/{scalable,16x16,22x22}/apps/dolphin-convert.svg ~/.local/share/icons/hicolor/symbolic/apps/dolphin-convert-symbolic.svg ~/.local/share/icons/hicolor/scalable/apps/dolphin-convert-outline.svg
  rm -f ~/.local/share/applications/dolphin-convert.desktop
  rm -rf ~/.local/share/dolphin-convert ~/.config/dolphin-convert
  kbuildsycoca6
  exit
fi
for c in ffmpeg ffprobe kdialog notify-send magick pdftoppm pdftotext pdfunite; do
  command -v "$c" >/dev/null || echo "Missing: $c"
done
/usr/bin/python3 -c 'import gi; gi.require_version("Adw", "1")' 2>/dev/null || echo "Missing: python3-gobject, libadwaita"
command -v soffice >/dev/null || echo "Optional, needed only for office documents: soffice (LibreOffice)"
install -Dm755 dolphin-convert ~/.local/bin/dolphin-convert
install -Dm644 -t ~/.local/share/dolphin-convert/lang lang/*.sh
install -Dm755 -t ~/.local/share/dolphin-convert ui.py
install -Dm644 -t ~/.local/share/applications dolphin-convert.desktop
install -Dm644 -t ~/.local/share/icons/hicolor/scalable/apps icons/dolphin-convert.svg icons/dolphin-convert-outline.svg
install -Dm644 -t ~/.local/share/icons/hicolor/symbolic/apps icons/dolphin-convert-symbolic.svg
for s in 16x16 22x22; do
  install -Dm644 icons/dolphin-convert-small.svg ~/.local/share/icons/hicolor/$s/apps/dolphin-convert.svg
done
install -Dm755 -t "$menu" menus/*.desktop
sed -i "s|^Exec=dolphin-convert|Exec=\"$HOME/.local/bin/dolphin-convert\"|" "$menu"/dolphin-convert-*.desktop
kbuildsycoca6
