"""Build-only Finder layout; never included in Stash.app."""
from pathlib import Path
import sys
from ds_store import DSStore
from mac_alias import Alias


def configure_layout(stage):
    with DSStore.open(str(stage / '.DS_Store'), 'w+') as store:
        store['.']['bwsp'] = {
            'ShowStatusBar': False, 'ShowToolbar': False, 'ShowTabView': False,
            'ShowPathbar': False, 'ShowSidebar': False,
            'ContainerShowSidebar': False, 'PreviewPaneVisibility': False,
            'SidebarWidth': 0,
            'WindowBounds': '{{220, 180}, {640, 400}}',
        }
        store['.']['icvp'] = {
            'viewOptionsVersion': 1, 'backgroundType': 2,
            'backgroundColorRed': 0.94, 'backgroundColorGreen': 0.94,
            'backgroundColorBlue': 0.94,
            'backgroundImageAlias': Alias.for_file(str(stage / '.background' / 'installer.png')).to_bytes(),
            'iconSize': 96.0, 'textSize': 14.0, 'gridSpacing': 100.0,
            'gridOffsetX': 0.0, 'gridOffsetY': 0.0, 'arrangeBy': 'none',
            'scrollPositionX': 0.0, 'scrollPositionY': 0.0,
            'labelOnBottom': True, 'showIconPreview': True, 'showItemInfo': False,
        }
        store['.']['vSrn'] = ('long', 1)
        store['.']['vstl'] = ('type', b'icnv')
        store['.']['icvl'] = ('type', b'icnv')
        store['Stash.app']['Iloc'] = (170, 190)
        store['Applications']['Iloc'] = (470, 190)


if __name__ == "__main__":
    configure_layout(Path(sys.argv[1]))
