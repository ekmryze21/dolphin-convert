#!/bin/bash
# Runs real conversions in a temporary folder with stubbed dialogs
cd "$(dirname "$0")" || exit 1
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
app=$work/home/.local/bin/dolphin-convert
mkdir -p "$work/bin" "$work/home/.local/bin" "$work/home/.local/share/dolphin-convert" "$work/my.dir"
cp dolphin-convert "$app"
cp -r lang VERSION "$work/home/.local/share/dolphin-convert/"
cd "$work" || exit 1
export HOME=$work/home PATH=$work/bin:$PATH LANGUAGE=en
unset XDG_CONFIG_HOME
stub() { printf '#!/bin/bash\n%s\n' "$2" >"bin/$1"; chmod +x "bin/$1"; }
ui_stub() {
  printf '#!/bin/bash\n[[ $1 == progress ]] && { %s; exit; }\nprintf "%%s\\n" "$@" >"$HOME/form"; echo "$ANSWER"\n' "$1" >"$HOME/.local/share/dolphin-convert/ui.py"
  chmod +x "$HOME/.local/share/dolphin-convert/ui.py"
}
ui_stub 'cat >"$HOME/progress"'
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
for fmt in h264 h265 vp9 av1 gif mp3 copy-mp4 copy-mkv; do go video $fmt "$v"; check "video $fmt" '(( rc == 0 ))'; done
mkdir acts
printf '1\n00:00:00,000 --> 00:00:02,000\nhello\n' >s.srt
ffmpeg -v error -i "$v" -i s.srt -map 0 -map 1 -c copy -c:s srt acts/a.mkv
for fmt in mute rotate-left rotate-right srt; do go video $fmt acts/a.mkv; check "video $fmt" '(( rc == 0 ))'; done
check "mute" '[[ -z $(codec "acts/a (1).mkv" a) && $(codec "acts/a (1).mkv" v) == h264 ]]'
check "rotate" '[[ $(ffprobe -v error -select_streams v -show_entries stream=width,height -of csv=p=0 acts/a.mp4) == 202,302* ]]'
check "subtitles" 'grep -q hello acts/a.srt'
go video srt "$v"
check "no subtitles" '[[ $rc == 1 ]] && grep -q "No subtitles" "$HOME/error"'
stub ffmpeg 'echo " V..... mpeg4 "'
go video h264 "$v"; rm bin/ffmpeg
check "missing encoder" '[[ $rc == 1 ]] && grep -q libx264 "$HOME/error"'
check "version" '[[ $("$app" --version) == $(<"$HOME/.local/share/dolphin-convert/VERSION") ]]'
check "codecs" '[[ $(codec "$base.mp4" v) == h264 && $(codec "$base (1).mp4" v) == hevc && $(codec "$base.webm" v) == vp9 && $(codec "$base (2).mp4" v) == av1 && $(codec "$base (3).mp4" v) == h264 ]]'
check "even size" '[[ $(ffprobe -v error -select_streams v -show_entries stream=width,height -of csv=p=0 "$base.mp4") == 302,202* ]]'
go video mp3 my.dir/noext ./-dash.mkv -dash.mkv відео.mkv .hidden
check "awkward names" '[[ $rc == 0 && -s my.dir/noext.mp3 && -s ./-dash.mp3 && -s "./-dash (1).mp3" && -s відео.mp3 && -s .hidden.mp3 && ! -e my.mp3 ]]'
check "open folder" '[[ $(<"$HOME/dolphin") == "--select $work/.hidden.mp3" ]]'
check "notification name" 'grep -qx dolphin-convert "$HOME/notify"'
check "per-file progress" 'grep -q "^# 5 of 5: .hidden" "$HOME/progress"'
for fmt in mp3 m4a opus ogg flac wav; do go audio $fmt s.wav; check "audio $fmt" '(( rc == 0 ))'; done
for fmt in jpg png webp avif jxl tiff gif bmp ico pdf; do go image $fmt ./i*.png p.avif; check "image $fmt" '[[ $rc == 0 && -s p.$fmt ]]'; done
stub heif-dec 'cp p.png "$2"'
echo heic >photo.heic
if [[ $(magick -list format) != *" HEIC "* ]]; then go image jpg photo.heic; check "heic (stubbed)" '[[ $rc == 0 && -s photo.jpg ]]'; fi
check "avif transparency" '[[ $(ffprobe -v error -show_entries stream=codec_name -of csv=p=0 "i [x]%d.avif" | grep -c av1) == 2 ]]'
check "ico sizes" '[[ $(magick identify "i [x]%d.ico" | wc -l) == 5 ]]'
mkdir merge; cp ./i*d.png merge/a.png; cp p.avif merge/b.avif
go image pdf-one merge/a.png merge/b.avif
check "one pdf" '[[ $rc == 0 && $(pdfinfo merge/a.pdf | grep -c "^Pages: *2$") == 1 && $(ls merge | wc -l) == 3 ]]'
echo broken >merge/c.png
go image pdf-one merge/a.png merge/c.png
check "one pdf fails whole" '[[ $rc == 1 && $(ls merge | wc -l) == 4 ]]'
magick -size 20x20 xc:red one.pdf
go pdf png one.pdf
check "single page pdf" '[[ $rc == 0 && -f one.png ]]'
magick -size 9x9 xc:red -set comment secret m.jpg
ANSWER='JPG|High|Original|TRUE|' go image ask m.jpg
check "strip image" '[[ $rc == 0 ]] && grep -q secret m.jpg && ! grep -q secret "m (1).jpg"'
ffmpeg -v error -i "$v" -metadata title=secret -metadata:s:v creation_time=2020-01-02T03:04:05Z m.mp4
ANSWER='MP4 (H.264)|High|Original||||FALSE|TRUE|' go video ask m.mp4
check "strip video" '[[ $rc == 0 ]] && ! ffprobe -v error -show_format -show_streams "m (1).mp4" | grep -E "secret|2020-01"'
rm -rf "$HOME/.config"
check "image types" '[[ $(file -b --mime-type "i [x]%d.jpg") == image/jpeg && $(file -b --mime-type p.webp) == image/webp ]]'
for fmt in png jpg txt; do go pdf $fmt doc.pdf; check "pdf $fmt" '(( rc == 0 ))'; done
go pdf merge doc.pdf one.pdf
check "merge pdf" '[[ $rc == 0 && $(pdfinfo "doc (1).pdf" | grep -c "^Pages: *3$") == 1 ]]'
go pdf merge doc.pdf
check "merge needs several" '[[ $rc == 1 ]] && grep -q "Select several" "$HOME/error"'
go pdf split doc.pdf
check "split pdf" '[[ $rc == 0 && $(ls "doc (2)" | wc -l) == 2 ]]'
if command -v gs >/dev/null; then
  magick -size 1500x1500 plasma: -quality 100 heavy.pdf; go pdf compress heavy.pdf
  check "compress pdf" '[[ $rc == 0 && $(stat -c %s "heavy (1).pdf") -lt $(stat -c %s heavy.pdf) ]]'
  stub gs 'for a; do [[ $a == -sOutputFile=* ]] && cat one.pdf doc.pdf >"${a#*=}"; done'
  go pdf compress one.pdf; rm bin/gs
  check "compress keeps small pdf" '[[ $rc == 1 && ! -e "one (1).pdf" ]]'
fi
stub tesseract 'echo eng; echo ukr'
stub ocrmypdf 'echo "$@" >"$HOME/ocr"; cp "${@: -2:1}" "${@: -1}"'
LANGUAGE=uk go pdf ocr one.pdf
check "ocr (stubbed)" '[[ $rc == 0 && -s "one (1).pdf" ]] && grep -q -- "-l eng+ukr" "$HOME/ocr"'
rm "one (1).pdf"
stub ebook-convert 'echo book >"$2"'
echo b >b.fb2; go ebook epub b.fb2
check "ebook (stubbed)" '[[ $rc == 0 && -s b.epub ]]'
check "pdf pages" '[[ $(ls doc | wc -l) == 2 && $(ls "doc (1)" | wc -l) == 2 ]]'

ANSWER='MP4 (H.264)|High|Original|0:01|0:03||FALSE|'; export ANSWER
go video ask -dash.mkv
check "trim" '[[ $rc == 0 && $(length ./-dash.mp4) == 2 ]]'
ANSWER='GIF|Small file|480||||FALSE|' go video ask -dash.mkv
ANSWER='GIF|Small file|480||||FALSE|' go video ask -dash.mkv
check "remembers choice" 'grep -qx "MP4 (H.264)!MP4 (H.265)!MP4 (AV1)!WebM (VP9)!^GIF!.*" "$HOME/form" && grep -qx "Original!1080!720!^480" "$HOME/form"'
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

ui_stub 'exit 1'
go video h265 big.mkv
check "missing window libraries" '[[ $rc == 1 ]] && grep -q libadwaita "$HOME/error"'
ui_stub 'sleep 1'
ffmpeg -v error -f lavfi -i testsrc=d=120:s=1920x1080 -c:v mpeg4 long.mkv
go video h265 long.mkv
check "cancel" '[[ $rc == 1 && ! -e long.mp4 ]] && ! pgrep -f "ffmpeg.*$work/long.mkv" >/dev/null'
stub soffice 'while (( $# > 1 )); do [[ $1 == --outdir ]] && d=$2; [[ $1 == --convert-to ]] && f=${2%%:*}; shift; done; mkdir -p "$d"; echo pdf >"$d/x.$f"'
ui_stub 'cat >/dev/null'
echo hi >w.docx; go office pdf w.docx
check "office (stubbed)" '[[ $(<w.pdf) == pdf ]]'

for fmt in docx csv; do go office $fmt w.docx; done
check "office formats" '[[ -s "w (1).docx" && -s w.csv ]]'
rm bin/soffice
if ! command -v soffice >/dev/null; then
  go office pdf w.docx
  check "missing tool" '[[ $rc == 1 ]] && grep -q "Not installed: soffice" "$HOME/error"'
fi
check "originals intact" 'sha256sum --quiet -c "$HOME/sums"'
check "no leftovers" '[[ -z $(find . -name ".dolphin-convert*") ]]'
echo "Failed: $fails"
(( fails == 0 ))
