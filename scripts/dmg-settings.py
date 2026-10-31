"""Finder layout written directly to .DS_Store; no UI automation required.

Settings reference: https://dmgbuild.readthedocs.io/en/latest/settings.html
"""
from pathlib import Path

application = Path(defines["app"]).resolve()
files = [(str(application), "Lidune.app")]
symlinks = {"Applications": "/Applications"}
format = "UDZO"
filesystem = "HFS+"
compression_level = 9
icon = str(application / "Contents/Resources/LidOnce.icns")
background = str(Path(defines["background"]).resolve())
window_rect = ((180, 180), (640, 400))
default_view = "icon-view"
icon_locations = {"Lidune.app": (160, 218), "Applications": (480, 218)}
icon_size = 88
text_size = 13
label_pos = "bottom"
arrange_by = None
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False
include_icon_view_settings = True
include_list_view_settings = False
