#!/usr/bin/env python3
"""Assert that a sample's theme assets actually reached the built site.

``mkdocs build --strict`` fails on broken links and nav problems, but a
stylesheet or font that returns HTTP 404 in the published site still
passes it green. This check reads the *resolved* configuration a sample
built from and asserts, against the ``site/`` directory ``mkdocs build``
already wrote, that:

* every ``extra_css`` entry exists as a file in the output,
* the ``theme.logo`` file exists in the output,
* the six shipped woff2 faces (Pretendard/Roboto Regular/Medium/Bold),
  referenced only from ``shared/styles/base.css`` via ``url(...)``, exist
  in the output, and
* the paths deliberately kept out of a consumer site are absent:
  ``theme/pdf/``, ``theme/mkdocs-base.yml``, ``theme/build-docs-pdf.sh``,
  and ``theme.toml``.

``extra_css`` and ``theme.logo`` are read from the built configuration
rather than hard-coded, so the check tracks ``mkdocs-base.yml`` as it
evolves. The fonts directory is derived from the location of
``base.css`` within ``extra_css`` for the same reason. Usage::

    verify-theme-delivery.py --config samples/manual/mkdocs.yml \
        --site site-ci/manual
"""
import argparse
import os
import sys

from mkdocs.config import load_config

# The six woff2 faces shared/styles/base.css declares with @font-face.
# They are referenced only from CSS url(...), never from a config key, so
# they are named explicitly rather than resolved from the built config.
FONT_FACES = (
    "Pretendard-Regular.woff2",
    "Pretendard-Medium.woff2",
    "Pretendard-Bold.woff2",
    "Roboto-Regular.woff2",
    "Roboto-Medium.woff2",
    "Roboto-Bold.woff2",
)

# Paths that mkdocs-base.yml's exclude_docs keeps out of a consumer site.
# Relative to the site root; a trailing slash marks a directory.
EXCLUDED_PATHS = (
    "theme/pdf/",
    "theme/mkdocs-base.yml",
    "theme/build-docs-pdf.sh",
    "theme.toml",
)


def main():
    parser = argparse.ArgumentParser(prog="verify-theme-delivery.py")
    parser.add_argument(
        "--config", required=True,
        help="the sample's mkdocs.yml (INHERITs the installed base)")
    parser.add_argument(
        "--site", required=True,
        help="the site/ directory mkdocs build wrote for this sample")
    args = parser.parse_args()

    site = args.site
    if not os.path.isdir(site):
        print(f"verify-theme-delivery: site directory not found: {site}",
              file=sys.stderr)
        sys.exit(1)

    config = load_config(args.config)
    extra_css = list(config["extra_css"])
    logo = config["theme"]["logo"]

    failures = []

    # extra_css: every resolved entry must exist as a file in the output.
    for rel in extra_css:
        target = os.path.join(site, rel)
        if os.path.isfile(target):
            print(f"  ok    extra_css {rel}")
        else:
            failures.append(f"extra_css entry '{rel}' is missing from the "
                            f"built site ({target})")

    # theme.logo must exist in the output.
    if logo:
        target = os.path.join(site, logo)
        if os.path.isfile(target):
            print(f"  ok    theme.logo {logo}")
        else:
            failures.append(f"theme.logo '{logo}' is missing from the built "
                            f"site ({target})")
    else:
        failures.append("theme.logo is not set in the resolved configuration")

    # Fonts: derive the fonts directory from base.css's location within
    # extra_css so the check tracks the installed layout rather than
    # hard-coding it. base.css installs to <...>/styles/base.css with the
    # woff2 files alongside at <...>/fonts/.
    base_css = next(
        (rel for rel in extra_css if os.path.basename(rel) == "base.css"),
        None)
    if base_css is None:
        failures.append("base.css was not found in extra_css, so the font "
                        "faces it declares cannot be located")
    else:
        fonts_rel = os.path.join(os.path.dirname(os.path.dirname(base_css)),
                                 "fonts")
        for face in FONT_FACES:
            target = os.path.join(site, fonts_rel, face)
            if os.path.isfile(target):
                print(f"  ok    font {os.path.join(fonts_rel, face)}")
            else:
                failures.append(f"font face '{face}' is missing from the "
                                f"built site ({target})")

    # Excluded paths must NOT reach a consumer site.
    for rel in EXCLUDED_PATHS:
        target = os.path.join(site, rel.rstrip("/"))
        if os.path.exists(target):
            failures.append(f"excluded path '{rel}' reached the built site "
                            f"({target}); it must be kept out")
        else:
            print(f"  ok    excluded {rel} absent")

    if failures:
        print(f"\nverify-theme-delivery: FAILED for {args.config}",
              file=sys.stderr)
        for message in failures:
            print(f"  - {message}", file=sys.stderr)
        sys.exit(1)

    print(f"verify-theme-delivery: OK for {args.config}")


if __name__ == "__main__":
    main()
