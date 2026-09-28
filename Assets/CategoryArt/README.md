# Stash category artwork

Eleven original SVG illustrations: All, Pinned, Text, Links, Images, Screenshots, Files, Videos, Emails, Colors, and Search. Lavender, charcoal, fine outlines, and small color accents tie them to the palette.

`preview.png` shows the full family. The SVG masters are editable vector files. Matching PDFs in `Sources/Stash/Resources/CategoryArt` are bundled for native macOS rendering; they stay vector at every display scale. Empty states use the full illustration. Generic rows use compact artwork; real thumbnails and service icons take priority.

To regenerate both formats, run `python3 scripts/make-category-art.py` with ReportLab installed. ReportLab is an artwork-generation dependency only. Normal app builds use the committed vectors and need no additional tools.
