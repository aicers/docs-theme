# Changelog

This file documents recent notable changes to this project. The format of this
file is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Changed

- `fetch-theme.sh` now installs into `docs/theme/` instead of
  `docs/.theme/`. MkDocs excludes every dot-prefixed path from the
  build, so assets installed under the old path never reached the
  published site.
- `fetch-theme.sh` takes no arguments. The repository, template, and
  version are read from `docs/theme.toml`, which the consuming project
  commits. `--source <dir>` installs from a local checkout instead of a
  release and records `source = "local"` in `docs/theme/.meta`.
- The install set gained `mkdocs-base.yml`, `shared/styles/base.css`,
  and `build-docs-pdf.sh`, so consumers no longer keep their own copy
  of the PDF script. `docs/theme/.meta` records the installed `repo`,
  `version`, `template`, `digest`, and `source`; an unchanged tree is
  left alone and an edited one is reinstalled.
- `build-docs-pdf.sh` takes an optional config path after the locale
  and reads all cover text and the output filename from the config's
  `extra.pdf` block. `extra.pdf_copyright` is replaced by
  `extra.pdf.copyright` and is now an error.
- `extra_css` in both `mkdocs-base.yml` files points at `theme/`.

### Removed

- Removed the root `VERSION` file. The git tag is the version.

## [0.1.0] - 2026-03-30

### Added

- Added `manual` template with CSS (lists, PDF print guardrails), PDF cover
  page (Jinja2), SCSS styles, and MkDocs base config. Ported from bootroot
  PRs #44, #133, #197, #274.
- Added `api-reference` template with HTTP method badges, endpoint path
  styling, and status code color highlights via `api.css`.
- Added shared assets: Roboto and Pretendard web fonts, brand logo SVG,
  and base CSS.
- Added sample sites for `manual` and `api-reference` with EN/KO content
  exercising all MkDocs Material visual elements.
- Added `scripts/fetch-theme.sh` for consuming projects to install a
  versioned template into `docs/.theme/`.
- Added `scripts/build-docs-pdf.sh` for PDF generation using
  mkdocs-with-pdf.
- Added `scripts/serve-samples.sh` to serve all sample sites
  simultaneously on consecutive ports.
- Added GitHub Pages deployment workflow with HTML samples and PDF
  downloads.
- Added CI workflow with HTML strict build, PDF build, and shellcheck.
- Added release workflow to create GitHub Releases from tags using
  CHANGELOG.md.

[0.1.0]: https://github.com/aicers/docs-theme/tree/0.1.0
