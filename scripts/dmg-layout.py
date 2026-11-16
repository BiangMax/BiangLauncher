"""Generate portable Finder layout metadata, without copying personal bookmarks."""
import sys
from pathlib import Path
from ds_store import DSStore

staging = Path(sys.argv[1])
with DSStore.open(str(staging / '.DS_Store'), 'w+') as store:
    store['.']['bwsp'] = {
        'WindowBounds': '{{200, 200}, {600, 400}}',
        'ShowToolbar': False,
        'ShowSidebar': False,
        'ShowStatusBar': False,
        'ShowPathbar': False,
        'ShowTabView': False,
        'ContainerShowSidebar': False,
        'SidebarWidth': 0,
    }
    store['.']['icvp'] = {
        'viewOptionsVersion': 1,
        'backgroundType': 0,
        'backgroundColorRed': 1.0,
        'backgroundColorGreen': 1.0,
        'backgroundColorBlue': 1.0,
        'iconSize': 100.0,
        'textSize': 16.0,
        'gridSpacing': 100.0,
        'gridOffsetX': 0.0,
        'gridOffsetY': 0.0,
        'arrangeBy': 'none',
        'labelOnBottom': True,
        'showItemInfo': False,
        'showIconPreview': True,
    }
    store['.']['vSrn'] = ('long', 1)
    store['BiangLauncher.app']['Iloc'] = (200, 150)
    store['Applications']['Iloc'] = (400, 150)
