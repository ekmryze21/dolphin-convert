#!/bin/bash
# Runs real conversions in a temporary folder with stubbed dialogs
cd "$(dirname "$0")" || exit 1
app=$PWD/dolphin-convert
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/home/.local/share/dolphin-convert" "$work/my.dir"
cp -r lang "$work/home/.local/share/dolphin-convert/"
cd "$work" || exit 1
export HOME=$work/home PATH=$work/bin:$PATH LANGUAGE=en
unset XDG_CONFIG_HOME
stub() { printf '#!/bin/bash\n%s\n' "$2" >"bin/$1"; chmod +x "bin/$1"; }
stub yad 'printf "%s\n" "$@" >"$HOME/yad"; echo "$ANSWER"'
stub zenity 'cat >"$HOME/progress"'
stub notify-send 'printf "%s\n" "$@" >"$HOME/notify"; [[ $1 == -A ]] && echo open'
stub kdialog 'printf "%s\n" "$@" >"$HOME/error"'
stub dolphin 'echo "$@" >"$HOME/dolphin"'

fails=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi; }
codec() { ffprobe -v error -select_streams "$2" -show_entries stream=codec_name -of csv=p=0 "$1" | head -n1; }
length() { ffprobe -v error -show_entries format=duration -of csv=p=0 "$1" | cut -d. -f1; }
go() { rm -f "$HOME"/{error,notify,dolphin}; "$app" "$@" >/dev/null 2>"$HOME/stderr"; rc=$?; sleep 0.3; }

ffmpeg -v error -f lavfi -i testsrc=d=4:s=301x201 -f lavfi -i sine=d=4 -c:v libx264 -c:a aac "my.dir/a [1]% & b.mkv"
v="my.dir/a [1]% & b.mkv"
cp "$v" my.dir/noext
cp "$v" ./-dash.mkv
cp "$v" відео.mkv
cp "$v" .hidden
ffmpeg -v error -f lavfi -i sine=d=3 s.wav
magick -size 301x201 xc:'rgba(255,0,0,0.5)' png:- >'i [x]%d.png'
ffmpeg -v error -f lavfi -i color=red:s=64x64 -frames:v 1 p.avif
magick -size 80x80 xc:red xc:blue doc.pdf
sha256sum -- "$v" my.dir/noext -dash.mkv відео.mkv .hidden s.wav ./i* p.avif doc.pdf >"$HOME/sums"

base=${v%.mkv}
for fmt in h264 h265 vp9 gif mp3 copy-mp4 copy-mkv; do go video $fmt "$v"; check "video $fmt" '(( rc == 0 ))'; done
check "codecs" '[[ $(codec "$base.mp4" v) == h264 && $(codec "$base (1).mp4" v) == hevc && $(codec "$base.webm" v) == vp9 && $(codec "$base (2).mp4" v) == h264 ]]'
check "even size" '[[ $(ffprobe -v error -select_streams v -show_entries stream=width,height -of csv=p=0 "$base.mp4") == 302,202* ]]'
go video mp3 my.dir/noext ./-dash.mkv -dash.mkv відео.mkv .hidden
check "awkward names" '[[ $rc == 0 && -s my.dir/noext.mp3 && -s ./-dash.mp3 && -s "./-dash (1).mp3" && -s відео.mp3 && -s .hidden.mp3 && ! -e my.mp3 ]]'
check "open folder" '[[ $(<"$HOME/dolphin") == "--select $work/.hidden.mp3" ]]'
check "per-file progress" 'grep -q "^# 5 of 5: .hidden" "$HOME/progress"'
for fmt in mp3 m4a opus ogg flac wav; do go audio $fmt s.wav; check "audio $fmt" '(( rc == 0 ))'; done
for fmt in jpg png webp tiff pdf; do go image $fmt ./i*.png p.avif; check "image $fmt" '[[ $rc == 0 && -s p.$fmt ]]'; done
check "image types" '[[ $(file -b --mime-type "i [x]%d.jpg") == image/jpeg && $(file -b --mime-type p.webp) == image/webp ]]'
for fmt in png jpg txt; do go pdf $fmt doc.pdf; check "pdf $fmt" '(( rc == 0 ))'; done
check "pdf pages" '[[ $(ls doc | wc -l) == 2 && $(ls "doc (1)" | wc -l) == 2 ]]'

ANSWER='MP4 (H.264)|High|Original|0:01|0:03||FALSE|'; export ANSWER
go video ask -dash.mkv
check "trim" '[[ $rc == 0 && $(length ./-dash.mp4) == 2 ]]'
ANSWER='GIF|Small file|480||||FALSE|' go video ask -dash.mkv
ANSWER='GIF|Small file|480||||FALSE|' go video ask -dash.mkv
check "remembers choice" 'grep -qx "MP4 (H.264)!MP4 (H.265)!WebM (VP9)!^GIF!.*" "$HOME/yad" && grep -qx "Original!1080!720!^480" "$HOME/yad"'
for a in '1:99x||' '5|2|' '99||' '||0' '||abc'; do
  IFS='|' read -r s e z <<<"$a"
  ANSWER="MP4 (H.264)|High|Original|$s|$e|$z|FALSE|" go video ask відео.mkv
  check "rejects $a" '[[ $rc == 1 && -s $HOME/error && ! -e відео.mp4 ]]'
done
ANSWER='GIF|High|Original|||5|FALSE|' go video ask відео.mkv
check "rejects GIF size" '[[ $rc == 1 && ! -e відео.gif ]]'
ffmpeg -v error -f lavfi -i "testsrc2=d=25:s=1280x720,noise=alls=60:allf=t" -f lavfi -i sine=d=25 -c:v libx264 -preset ultrafast -qp 15 big.mkv
for fmt in 'MP4 (H.264)' 'MP4 (H.265)' 'WebM (VP9)'; do
  ANSWER="$fmt|Normal|480|||2|FALSE|" go video ask big.mkv
  out=$(ls -t big*.mp4 big*.webm 2>/dev/null | head -n1)
  check "2 MB $fmt: $(stat -c %s "$out")" '(( rc == 0 && $(stat -c %s "$out") <= 2000000 ))'
done
go video 10mb big.mkv
out=$(ls -t big*.mp4 | head -n1)
check "10 MB" '(( rc == 0 && $(stat -c %s "$out") <= 10000000 && $(stat -c %s "$out") > 5000000 ))'
ANSWER='MP4 (H.265)|Normal|Original||||TRUE|' go video ask big.mkv відео.mkv
check "GPU or fallback" '[[ $rc == 0 && $(codec відео.mp4 v) == hevc ]]'
ANSWER='MP4 (H.264)|Мала|Оригінал|' LANGUAGE=uk go image jpg p.avif
check "Ukrainian" 'grep -q "Готово: 1 з 1" "$HOME/notify"'
echo broken >broken.mkv
go video h264 broken.mkv s.wav
check "reports failure" '[[ $rc == 1 && ! -e broken.mp4 ]] && grep -q broken.mkv "$HOME/error"'

stub zenity 'sleep 1'
ffmpeg -v error -f lavfi -i testsrc=d=120:s=1920x1080 -c:v mpeg4 long.mkv
go video h265 long.mkv
check "cancel" '[[ $rc == 1 && ! -e long.mp4 ]] && ! pgrep -f "ffmpeg.*$work/long.mkv" >/dev/null'
stub soffice 'while (( $# > 1 )); do [[ $1 == --outdir ]] && d=$2; shift; done; mkdir -p "$d"; echo pdf >"$d/x.pdf"'
stub zenity 'cat >/dev/null'
echo hi >w.docx; go office pdf w.docx
check "office (stubbed)" '[[ $(<w.pdf) == pdf ]]'

check "originals intact" 'sha256sum --quiet -c "$HOME/sums"'
check "no leftovers" '[[ -z $(find . -name ".dolphin-convert*") ]]'
echo "Failed: $fails"
(( fails == 0 ))
