#!/bin/bash
# install.sh [--uninstall]; install.sh --package DESTDIR copies everything into DESTDIR/usr for packagers
set -e
cd "$(dirname "$0")"
has() { command -v "$1" >/dev/null; }

# copy_files PREFIX
copy_files() {
  local s icons=$1/share/icons/hicolor
  install -Dm755 dolphin-convert "$1/bin/dolphin-convert"
  install -Dm644 -t "$1/share/dolphin-convert/lang" lang/*.sh
  install -Dm644 -t "$1/share/dolphin-convert" VERSION
  install -Dm755 -t "$1/share/dolphin-convert" ui.py
  install -Dm644 -t "$1/share/applications" dolphin-convert.desktop
  install -Dm644 -t "$icons/scalable/apps" icons/dolphin-convert.svg icons/dolphin-convert-outline.svg
  install -Dm644 -t "$icons/symbolic/apps" icons/dolphin-convert-symbolic.svg
  for s in 16x16 22x22; do
    install -Dm644 icons/dolphin-convert-small.svg "$icons/$s/apps/dolphin-convert.svg"
  done
  install -Dm755 -t "$1/share/kio/servicemenus" menus/*.desktop
}

if [[ $1 == --package ]]; then
  copy_files "${2:?DESTDIR is required}/usr"
  exit
fi

prefix=~/.local
menu=$prefix/share/kio/servicemenus
if [[ $1 == --uninstall ]]; then
  rm -f ~/.local/bin/dolphin-convert ~/.local/share/applications/dolphin-convert.desktop
  rm -f "$menu"/dolphin-convert-{video,audio,image,pdf,office,spreadsheet,presentation,ebook}.desktop
  rm -f ~/.local/share/icons/hicolor/{scalable,symbolic,16x16,22x22}/apps/dolphin-convert{,-outline,-symbolic}.svg
  rm -rf ~/.local/share/dolphin-convert ~/.config/dolphin-convert
  kbuildsycoca6
  exit
fi

# Package names by distribution family: Fedora, Arch, Debian, openSUSE
family=
if [[ -r /etc/os-release ]]; then . /etc/os-release; fi
case " $ID $ID_LIKE " in
  *" fedora "*) family=1 ;;
  *" arch "*) family=2 ;;
  *" debian "*|*" ubuntu "*) family=3 ;;
  *suse*) family=4 ;;
esac
package() {
  local row
  case $1 in
    ffmpeg|ffprobe) row=(ffmpeg ffmpeg ffmpeg ffmpeg) ;;
    kdialog) row=(kdialog kdialog kdialog kdialog) ;;
    notify-send) row=(libnotify libnotify libnotify-bin libnotify-tools) ;;
    magick) row=(ImageMagick imagemagick imagemagick ImageMagick) ;;
    pdf*) row=(poppler-utils poppler poppler-utils poppler-tools) ;;
    windows) row=("python3-gobject libadwaita" "python-gobject libadwaita" "python3-gi gir1.2-adw-1" "python3-gobject typelib-1_0-Adw-1") ;;
    soffice) row=(libreoffice libreoffice-fresh libreoffice libreoffice) ;;
    gs) row=(ghostscript ghostscript ghostscript ghostscript) ;;
    ocrmypdf) row=(ocrmypdf ocrmypdf ocrmypdf ocrmypdf) ;;
    ebook-convert) row=(calibre calibre calibre calibre) ;;
  esac
  echo "${row[family-1]}"
}

missing=() packages=()
for c in ffmpeg ffprobe kdialog notify-send magick pdftoppm pdftotext pdfunite pdfseparate; do
  has "$c" || missing+=("$c")
done
/usr/bin/python3 -c 'import gi; gi.require_version("Adw", "1")' 2>/dev/null || missing+=(windows)
if (( ${#missing[@]} )); then
  echo "Missing: ${missing[*]/windows/PyGObject and libadwaita}"
  if [[ $family ]]; then
    if [[ -e /run/ostree-booted ]]; then get=(rpm-ostree install)
    else
      case $family in
        1) get=(sudo dnf install) ;;
        2) get=(sudo pacman -S --needed) ;;
        3) get=(sudo apt install) ;;
        4) get=(sudo zypper install) ;;
      esac
    fi
    read -ra packages <<<"$(for c in "${missing[@]}"; do package "$c"; done | tr ' ' '\n' | sort -u | tr '\n' ' ')"
    echo "  ${get[*]} ${packages[*]}"
    if [[ -t 0 ]]; then
      read -rp "Run this command now? [y/N] " answer || true
      if [[ $answer == [yY]* ]]; then "${get[@]}" "${packages[@]}" || echo "Some packages were not installed."; fi
    fi
  fi
fi

if has ffmpeg; then
  encoders=$(ffmpeg -hide_banner -encoders 2>/dev/null) lacking=
  for e in libx264 libx265 libsvtav1 libaom-av1 libvpx-vp9 libopus libvorbis libmp3lame; do
    [[ $encoders == *" $e "* ]] || lacking+=" $e"
  done
  if [[ $lacking ]]; then
    echo "Your ffmpeg has no$lacking; those conversions will not work."
    if [[ $family == 1 ]]; then echo "  Install the full ffmpeg: https://rpmfusion.org/Configuration"; fi
  fi
fi

copy_files "$prefix"
hint=
# without TOOL FEATURE [MENU...]: hide the menus of a tool that is not installed
without() {
  if has "$1"; then return; fi
  hint+="  $2: $1"
  if [[ $family ]]; then hint+=" (package $(package "$1"))"; fi
  hint+=$'\n'
  local f
  for f in "${@:3}"; do rm -f "$menu/dolphin-convert-$f.desktop"; done
}
without soffice "Office documents" office spreadsheet presentation
without ebook-convert "E-books" ebook
without gs "PDF compression"
without ocrmypdf "Text recognition"
if ! has gs; then sed -i '/^Actions=/s/compress;//' "$menu/dolphin-convert-pdf.desktop"; fi
if ! has ocrmypdf; then sed -i '/^Actions=/s/ocr;//' "$menu/dolphin-convert-pdf.desktop"; fi
sed -i "s|^Exec=dolphin-convert|Exec=\"$prefix/bin/dolphin-convert\"|" "$menu"/dolphin-convert-*.desktop
kbuildsycoca6 || true

teal= coral= bold= reset=
if [[ -t 1 ]]; then teal=$'\e[36m' coral=$'\e[91m' bold=$'\e[1m' reset=$'\e[0m'; fi
cat <<END

            $coral⣾⣷⣶⣦⣄
           $coral⢰⣿⣿⣿⣿⣿⣦
           $coral⣾⣿⣿⣿⣿⣿⡏
           $coral⠛⠛⠿⢿⣿⣿⠁$reset$bold  dolphin-convert $(<VERSION)$reset is ready
      $teal⢀⣠⣤⣤⣤⣀⣠⣴⣶
  $teal⠰⢶⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠁   $reset  Right-click a file in Dolphin
    $teal⢹⣿⣿⣿⣿⣿⣿⠋⠁     $reset  and choose ${bold}Convert to…$reset
    $teal⢸⣿⣿⡿⠛⢿⣿⡆
    $teal⠈⢿⣿⣧
      $teal⠹⣿⣿⡷⢦
       $teal⠿⠁$reset

END
if [[ $hint ]]; then printf 'Optional. Install and run ./install.sh again to get:\n%s\n' "$hint"; fi
echo "No menu? Restart Dolphin. Remove with ./install.sh --uninstall"
