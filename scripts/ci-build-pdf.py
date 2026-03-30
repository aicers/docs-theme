#!/usr/bin/env python3
"""Build a PDF for a sample site in CI.

Usage:
    python3 scripts/ci-build-pdf.py \
        --sample samples/manual/ \
        --template manual \
        --locale en \
        --output site/pdf/manual.en.pdf
"""
import argparse
import copy
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone

import yaml


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sample", required=True, help="Path to sample dir")
    parser.add_argument("--template", required=True, help="Template name")
    parser.add_argument("--locale", required=True, choices=["en", "ko"])
    parser.add_argument("--output", required=True, help="Output PDF path")
    args = parser.parse_args()

    sample_dir = os.path.abspath(args.sample)
    repo_root = os.path.abspath(".")
    template_pdf = os.path.join(repo_root, "templates", args.template, "pdf")
    shared_fonts = os.path.join(repo_root, "shared", "fonts")
    brand_svg = os.path.join(repo_root, "shared", "brand.svg")

    mkdocs_yml = os.path.join(sample_dir, "mkdocs.yml")
    with open(mkdocs_yml, encoding="utf-8") as f:
        data = yaml.safe_load(f)
    data = copy.deepcopy(data)

    # Prepare temporary PDF directory with fonts
    tmp_pdf_dir = os.path.join(sample_dir, ".pdf-tmp")
    if os.path.exists(tmp_pdf_dir):
        shutil.rmtree(tmp_pdf_dir)
    shutil.copytree(template_pdf, tmp_pdf_dir)

    fonts_dest = os.path.join(tmp_pdf_dir, "fonts")
    if not os.path.exists(fonts_dest):
        os.makedirs(fonts_dest)
    if os.path.isdir(shared_fonts):
        for name in os.listdir(shared_fonts):
            src = os.path.join(shared_fonts, name)
            if os.path.isfile(src):
                shutil.copy2(src, os.path.join(fonts_dest, name))

    # Rewrite font paths in SCSS
    styles_path = os.path.join(tmp_pdf_dir, "styles.scss")
    fonts_base = f"file://{fonts_dest}/"
    with open(styles_path, encoding="utf-8") as f:
        styles = f.read()
    for prefix in ("../fonts/", "pdf/fonts/", "/pdf/fonts/", "fonts/"):
        styles = styles.replace(f'url("{prefix}', f'url("{fonts_base}')
    with open(styles_path, "w", encoding="utf-8") as f:
        f.write(styles)

    # Configure mkdocs
    data["strict"] = False
    data["site_dir"] = os.path.join(sample_dir, f"site-pdf-{args.locale}")

    theme = data.get("theme")
    if isinstance(theme, dict):
        theme["font"] = False

    for plugin in data.get("plugins", []):
        if isinstance(plugin, dict) and "i18n" in plugin:
            plugin["i18n"]["build_only_locale"] = args.locale

    now = datetime.now(tz=timezone.utc)
    output_path = os.path.abspath(args.output)
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    pdf_plugin = {
        "with-pdf": {
            "enabled_if_env": "DOCS_PDF_EXPORT",
            "output_path": output_path,
            "custom_template_path": tmp_pdf_dir,
            "author": (
                now.strftime("%B %-d, %Y")
                if args.locale == "en"
                else now.strftime("%Y년 %-m월 %-d일")
            ),
            "copyright": "",
        }
    }

    if os.path.isfile(brand_svg):
        pdf_plugin["with-pdf"]["cover_logo"] = brand_svg

    data.setdefault("plugins", []).append(pdf_plugin)

    tmp_yml = os.path.join(sample_dir, "mkdocs.tmp.yml")
    with open(tmp_yml, "w", encoding="utf-8") as f:
        yaml.safe_dump(data, f, sort_keys=False)

    try:
        env = os.environ.copy()
        env["DOCS_PDF_EXPORT"] = "1"
        subprocess.run(
            ["mkdocs", "build", "-f", tmp_yml],
            check=True,
            env=env,
        )
    finally:
        os.remove(tmp_yml)
        shutil.rmtree(tmp_pdf_dir, ignore_errors=True)
        site_pdf_dir = data["site_dir"]
        if os.path.isdir(site_pdf_dir):
            shutil.rmtree(site_pdf_dir, ignore_errors=True)


if __name__ == "__main__":
    main()
