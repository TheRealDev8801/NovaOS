#!/usr/bin/env python3
"""Bundle the NovaOS website into a single self-contained dist/index.html.

The aibotv2 hosting panel serves one HTML blob per subdomain, so this inlines
styles.css and the favicon into index.html for one-file deployment.
"""
import base64
import pathlib

root = pathlib.Path(__file__).parent
html = (root / "index.html").read_text(encoding="utf-8")
css = (root / "styles.css").read_text(encoding="utf-8")
svg = (root / "favicon.svg").read_text(encoding="utf-8")

svg_data = "data:image/svg+xml;base64," + base64.b64encode(svg.encode("utf-8")).decode("ascii")
html = html.replace('href="favicon.svg"', f'href="{svg_data}"')
html = html.replace('src="favicon.svg"', f'src="{svg_data}"')
html = html.replace(
    '<link rel="stylesheet" href="styles.css">',
    f"<style>\n{css}\n</style>",
)

out_dir = root / "dist"
out_dir.mkdir(exist_ok=True)
out_file = out_dir / "index.html"
out_file.write_text(html, encoding="utf-8")
print(f"Wrote {out_file} ({len(html)} bytes)")
