#!/usr/bin/python3
"""Windows of dolphin-convert. Cancel exits with 0 and prints nothing.

ui.py form TITLE SUBTITLE BUTTON [LABEL TYPE VALUE]...   prints the values joined with |
ui.py progress TITLE SUBTITLE BUTTON                     reads "PERCENT" and "# TEXT" lines until EOF

TYPE is CB (VALUE is items joined with !, ^ marks the selected one), CHK (TRUE or FALSE) or TEXT.
"""
import os
import sys
import threading

import gi

gi.require_version("Adw", "1")
from gi.repository import Adw, Gdk, GLib, Gtk, Pango

CSS = """
window { --accent-bg-color: #087377; --accent-fg-color: #fff; }
progressbar trough, progressbar progress { min-height: 8px; border-radius: 4px; }
"""

mode, title, subtitle, action, *fields = sys.argv[1:]
GLib.set_prgname("dolphin-convert")  # Wayland finds the window icon by this name
if not Gtk.init_check():
    sys.exit("Cannot open the display")
Adw.init()
css = Gtk.CssProvider()
css.load_from_string(CSS)
Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

loop = GLib.MainLoop()
window = Adw.Window(title=title, default_width=420, resizable=False, icon_name="dolphin-convert")
window.connect("close-request", lambda *_: loop.quit())
escape = Gtk.ShortcutController()
escape.add_shortcut(Gtk.Shortcut.new(Gtk.ShortcutTrigger.parse_string("Escape"), Gtk.NamedAction.new("window.close")))
window.add_controller(escape)


def label(text, *classes):
    return Gtk.Label(label=text, css_classes=classes, ellipsize=Pango.EllipsizeMode.MIDDLE, max_width_chars=1, hexpand=True)


body = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18, margin_start=24, margin_end=24, margin_bottom=24)
head = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
head.append(Gtk.Image(icon_name="dolphin-convert", pixel_size=72, margin_bottom=6))
head.append(label(title, "title-2"))
status = label(subtitle, "dim-label")
head.append(status)
body.append(head)
button = Gtk.Button(label=action, halign=Gtk.Align.CENTER, css_classes=["pill"])


def combo_row(name, value):
    items = value.split("!")
    selected = next((i for i, item in enumerate(items) if item.startswith("^")), 0)
    items[selected] = items[selected].removeprefix("^")
    row = Adw.ComboRow(title=name, model=Gtk.StringList.new(items), selected=selected)
    return row, lambda: items[row.get_selected()]


def switch_row(name, value):
    row = Adw.SwitchRow(title=name, active=value == "TRUE")
    return row, lambda: "TRUE" if row.get_active() else "FALSE"


def entry_row(name, value):
    row = Adw.EntryRow(title=name, text=value, activates_default=True)
    return row, lambda: row.get_text().strip()


def form():
    make = {"CB": combo_row, "CHK": switch_row, "TEXT": entry_row}
    values, group, last = [], None, None
    for name, kind, value in zip(*[iter(fields)] * 3):
        if kind != last:  # every kind of control gets its own card
            group, last = Adw.PreferencesGroup(), kind
            body.append(group)
        row, read = make[kind](name, value)
        row.set_use_markup(False)
        group.add(row)
        values.append(read)

    def accept(_):
        print("".join(read() + "|" for read in values), flush=True)
        loop.quit()

    button.add_css_class("suggested-action")
    button.connect("clicked", accept)
    window.set_default_widget(button)


def progress():
    bar = Gtk.ProgressBar()
    body.append(bar)
    button.connect("clicked", lambda _: loop.quit())

    def show(line):
        if line.startswith("# "):
            status.set_label(line[2:])
        elif line.isdigit():
            bar.set_fraction(min(int(line), 100) / 100)

    def read():
        for line in open(0, errors="replace"):
            GLib.idle_add(show, line.rstrip("\n"))
        GLib.idle_add(loop.quit)

    threading.Thread(target=read, daemon=True).start()


{"form": form, "progress": progress}[mode]()
body.append(button)
view = Adw.ToolbarView(content=Gtk.ScrolledWindow(
    child=body, hscrollbar_policy=Gtk.PolicyType.NEVER, propagate_natural_height=True, max_content_height=800))
# KDE puts the window icon in the title bar, next to the big logo
layout = Gtk.Settings.get_default().props.gtk_decoration_layout or ":close"
layout = ":".join(",".join(b for b in side.split(",") if b != "icon") for side in layout.split(":"))
view.add_top_bar(Adw.HeaderBar(show_title=False, decoration_layout=layout))
window.set_content(view)
window.present()
loop.run()
os._exit(0)  # the reading thread may still hold stdin
