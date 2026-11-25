<img src="icons/dolphin-convert.svg" width="96" alt="">

# dolphin-convert

Adds a **Convert to…** submenu to the Dolphin context menu for video, audio, images, PDF, office documents and e-books. Results are saved next to the originals, which are never modified or overwritten.

No uploads, no ads, no file limits: files are converted on your own computer.

![Context menu and options window for a video](screenshot.png)

## Install

Fedora:

```bash
sudo dnf copr enable kiossadost/dolphin-convert
sudo dnf install dolphin-convert
```

The package does not replace the reduced ffmpeg. For H.264, H.265 and HEIC, enable [RPM Fusion](https://rpmfusion.org/Configuration) and run:

```bash
sudo dnf install --allowerasing ffmpeg libheif-tools libheif-freeworld
```

Other distributions and Atomic desktops:

```bash
git clone https://github.com/ekmryze21/dolphin-convert.git && ./dolphin-convert/install.sh
```

The installer lists missing packages and, on the Fedora, Arch, Debian and openSUSE families, offers to install them. Menus of missing optional tools stay hidden: install the tool and run `./install.sh` again from the `dolphin-convert` folder.

Restart Dolphin for the menu to show up.

## Formats

| Files | Convert to | Also |
| --- | --- | --- |
| Video | MP4 (H.264, H.265, AV1), WebM (VP9), GIF, MP3, MP4 and MKV without re-encoding | rotate, remove sound, extract the first subtitle track |
| Audio | MP3, M4A, Opus, OGG, FLAC, WAV | |
| Images | JPG, PNG, WebP, AVIF, JXL, TIFF, GIF, BMP, ICO, PDF | one PDF from all images; HEIC and camera RAW as a source |
| PDF | PNG and JPG (a folder if there are several pages), TXT | merge, split, compress, recognize text |
| Documents | PDF, DOCX, ODT | |
| Spreadsheets | PDF, XLSX, ODS, CSV (first sheet) | |
| Presentations | PDF, PPTX, ODP | |
| E-books | EPUB, MOBI, AZW3, PDF, TXT | |

Common conversions are one click away. **More options…** for video, audio and images adds, where it applies:

- quality and maximum height
- trimming
- a target file size
- metadata removal
- GPU encoding

Format, quality, height, metadata and GPU choices are remembered.

Available in English, Ukrainian, German, Spanish, French, Polish, Dutch and Catalan, following the system language.

## Requirements

KDE Plasma 6 with Dolphin. The package or the installer takes care of most of the rest.

<details>
<summary>Full list</summary>

- `ffmpeg` with libx264, libx265, libsvtav1, libaom, libvpx-vp9, libopus, libvorbis and libmp3lame
- Python 3 with PyGObject and libadwaita 1.6 or newer (`python3-gobject`, `libadwaita`) for the windows
- `kdialog`, `notify-send`
- ImageMagick 7 (`magick`) for images, Poppler (`pdftoppm`, `pdftotext`, `pdfunite`) for PDF

Optional:

- LibreOffice (`soffice`) for office documents; the Flatpak version is not supported
- Ghostscript (`gs`) for PDF compression
- `ocrmypdf` and Tesseract language data for text recognition
- Calibre (`ebook-convert`) for e-books; the Flatpak version is not supported
- `libheif-tools` for HEIC, if ImageMagick was built without it. HEIC also needs an HEVC decoder (`libheif-freeworld` from RPM Fusion on Fedora). The installer offers these

Stock Fedora ships a reduced ffmpeg. The installer offers to enable [RPM Fusion](https://rpmfusion.org/Configuration) and install the full `ffmpeg` package from there; on Atomic desktops do it yourself.

</details>

## Notes

- Trimming without re-encoding cuts at the nearest keyframe.
- GPU encoding (NVENC or VAAPI) applies to H.264 and H.265 and falls back to the CPU. A target size always uses the CPU.
- Animated images are converted as their first frame.
- Converting from AVIF drops transparency; converting to AVIF keeps it.

## Uninstall

Package:

```bash
sudo dnf remove dolphin-convert
```

Installed with `install.sh`, from the `dolphin-convert` folder:

```bash
./install.sh --uninstall
```

## Development

`./test.sh` runs real conversions in a temporary folder with stubbed dialogs. To add a language, copy a file in `lang/` and add its names to `menus/`.

RPM and Arch package files are in `packaging/`.

## Thanks

Dutch translation: morxd. Spanish and Catalan: treshhyk.

## License

[MIT](LICENSE)
