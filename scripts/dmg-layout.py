"""Build-only Finder layout; never included in Stash.app."""
from pathlib import Path
import sys
from ds_store import DSStore


def configure_layout(stage):
    with DSStore.open(str(stage / '.DS_Store'), 'w+') as store:
        store['.']['bwsp'] = {
            'ShowStatusBar': False, 'ShowToolbar': False, 'ShowTabView': False,
            'ShowPathbar': False, 'ShowSidebar': False,
            'WindowBounds': '{{220, 180}, {640, 400}}',
        }
        store['.']['icvp'] = {
            'viewOptionsVersion': 1, 'backgroundType': 0,
            'iconSize': 96.0, 'textSize': 14.0, 'gridSpacing': 100.0,
            'gridOffsetX': 0.0, 'gridOffsetY': 0.0, 'arrangeBy': 'none',
            'labelOnBottom': True, 'showIconPreview': True, 'showItemInfo': False,
        }
        store['.']['vSrn'] = ('long', 1)
        store['.']['vstl'] = ('type', b'icnv')
        store['Stash.app']['Iloc'] = (170, 115)
        store['Applications']['Iloc'] = (470, 115)
        store['Start here.txt']['Iloc'] = (320, 285)


if __name__ == "__main__":
    configure_layout(Path(sys.argv[1]))
