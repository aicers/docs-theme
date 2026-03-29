#!/usr/bin/env bash
# Build a PDF from an MkDocs project that uses the docs-theme PDF template.
#
# Usage:
#   ./scripts/build-docs-pdf.sh <en|ko>
#
# The script reads mkdocs.yml from the current directory and produces a
# PDF using mkdocs-with-pdf.  Font paths in the SCSS are rewritten to
# absolute file:// URIs so WeasyPrint can resolve them.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <en|ko>" >&2
  exit 1
fi

locale="$1"
python_bin="python3"
mkdocs_bin="mkdocs"

if [[ -x ".venv/bin/python" ]]; then
  python_bin=".venv/bin/python"
fi

if [[ -x ".venv/bin/mkdocs" ]]; then
  mkdocs_bin=".venv/bin/mkdocs"
fi

case "$locale" in
  en|ko) ;;
  *)
    echo "Unsupported locale: $locale" >&2
    exit 1
    ;;
esac

trap 'rm -f mkdocs.tmp.yml; if [[ "${DOCS_PDF_DEBUG:-0}" != "1" ]]; then rm -rf .pdf-tmp; fi' EXIT

DOCS_LOCALE="$locale" "$python_bin" - <<'PY'
import copy
import os
import sys
from datetime import datetime
import shutil
import yaml

locale = os.environ.get("DOCS_LOCALE")
if not locale:
    print("DOCS_LOCALE is required", file=sys.stderr)
    sys.exit(1)

with open("mkdocs.yml", "r", encoding="utf-8") as f:
    data = yaml.safe_load(f)

data = copy.deepcopy(data)
root = os.getcwd()

# Resolve the theme PDF directory.  Prefer docs/.theme/pdf (fetched from
# docs-theme), fall back to docs/pdf for projects that bundle their own.
theme_pdf = os.path.join(root, "docs", ".theme", "pdf")
if not os.path.isdir(theme_pdf):
    theme_pdf = os.path.join(root, "docs", "pdf")
if not os.path.isdir(theme_pdf):
    print("No PDF template found in docs/.theme/pdf or docs/pdf", file=sys.stderr)
    sys.exit(1)

tmp_pdf_dir = os.path.join(root, ".pdf-tmp")
if os.path.exists(tmp_pdf_dir):
    shutil.rmtree(tmp_pdf_dir)
shutil.copytree(theme_pdf, tmp_pdf_dir)

# Copy shared fonts next to the SCSS so relative paths resolve.
shared_fonts = os.path.join(root, "docs", ".theme", "fonts")
if not os.path.isdir(shared_fonts):
    shared_fonts = os.path.join(theme_pdf, "fonts")
if os.path.isdir(shared_fonts):
    fonts_dest = os.path.join(tmp_pdf_dir, "fonts")
    if not os.path.exists(fonts_dest):
        os.makedirs(fonts_dest)
    for f in os.listdir(shared_fonts):
        src = os.path.join(shared_fonts, f)
        if os.path.isfile(src):
            shutil.copy2(src, os.path.join(fonts_dest, f))

styles_path = os.path.join(tmp_pdf_dir, "styles.scss")
fonts_base = f'file://{os.path.join(tmp_pdf_dir, "fonts")}/'

with open(styles_path, "r", encoding="utf-8") as f:
    styles = f.read()

for prefix in ('../fonts/', 'pdf/fonts/', '/pdf/fonts/', 'fonts/'):
    styles = styles.replace(f'url("{prefix}', f'url("{fonts_base}')

with open(styles_path, "w", encoding="utf-8") as f:
    f.write(styles)

data["strict"] = False
data["site_dir"] = f"site-pdf-{locale}"

theme = data.get("theme")
if isinstance(theme, dict):
    theme["font"] = False

for plugin in data.get("plugins", []):
    if isinstance(plugin, dict) and "i18n" in plugin:
        plugin["i18n"]["build_only_locale"] = locale

now = datetime.now()
site_name = data.get("site_name", "Document")

pdf_plugin = {
    "with-pdf": {
        "enabled_if_env": "DOCS_PDF_EXPORT",
        "output_path": os.path.join(root, "site", "pdf", f"{site_name.lower().replace(' ', '-')}.{locale}.pdf"),
        "custom_template_path": tmp_pdf_dir,
        "author": now.strftime('%B %-d, %Y') if locale == "en" else now.strftime('%Y년 %-m월 %-d일'),
        "copyright": data.get("extra", {}).get("pdf_copyright", ""),
    }
}

brand_svg = os.path.join(root, "docs", ".theme", "brand.svg")
if not os.path.isfile(brand_svg):
    brand_svg = os.path.join(root, "docs", "pdf", "brand.svg")
if os.path.isfile(brand_svg):
    pdf_plugin["with-pdf"]["cover_logo"] = brand_svg

data.setdefault("plugins", []).append(pdf_plugin)

with open("mkdocs.tmp.yml", "w", encoding="utf-8") as f:
    yaml.safe_dump(data, f, sort_keys=False)
PY

DOCS_PDF_EXPORT=1 "$mkdocs_bin" build -f mkdocs.tmp.yml
