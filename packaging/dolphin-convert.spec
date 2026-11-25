Name:           dolphin-convert
Version:        1.0.0
Release:        1%{?dist}
Summary:        Convert files from the Dolphin context menu
License:        MIT
URL:            https://github.com/ekmryze21/dolphin-convert
Source0:        %{url}/archive/v%{version}/%{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       dolphin kdialog libnotify ImageMagick poppler-utils
Requires:       /usr/bin/ffmpeg /usr/bin/ffprobe
Requires:       python3-gobject libadwaita
Recommends:     ghostscript
Suggests:       libreoffice ocrmypdf calibre libheif-tools

%description
Adds a "Convert to" submenu to the Dolphin context menu for video, audio,
images, PDF, office documents and e-books.

%prep
%autosetup

%build

%install
./install.sh --package %{buildroot}

%files
%license LICENSE
%doc README.md CHANGELOG.md
%{_bindir}/dolphin-convert
%{_datadir}/dolphin-convert/
%{_datadir}/applications/dolphin-convert.desktop
%{_datadir}/icons/hicolor/*/apps/dolphin-convert*.svg
%{_datadir}/kio/servicemenus/dolphin-convert-*.desktop
