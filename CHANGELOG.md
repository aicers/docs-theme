# Changelog

This file documents recent notable changes to this project. Within each
release, entries are grouped by the area a consumer's reviewer triages —
`manual`, `api-reference`, `shared`, and `scripts` — rather than by the
Keep a Changelog change-type headings, so a consumer reads only the
sections that affect its template. Version numbers follow the
`MAJOR.MINOR.PATCH` policy described in [the README](README.md#versioning).

## [0.2.0] - 2026-08-08

### manual

- `mkdocs-base.yml` now carries a self-served browser identity: an indigo
  palette with a light/dark toggle, `brand.svg` as the header logo and
  favicon, and `theme.font: false` so no Google Fonts are requested.
- The base `markdown_extensions` gained a Unicode-aware `toc.slugify`, so
  Korean headings keep their characters in anchor ids, and a `mermaid`
  custom fence under `pymdownx.superfences`, so a tagged block renders as
  a `.mermaid` diagram.
- Consuming projects now `INHERIT: docs/theme/mkdocs-base.yml` instead of
  copying settings out of it. Because MkDocs replaces lists and scalars
  wholesale on merge, `theme.features`, `markdown_extensions`,
  `extra_css`, and `exclude_docs` are defined fully in the base and must
  never be partially overridden by a consumer. The sample builds through
  this path against a theme installed from the local checkout; its
  `docs/theme/` tree is generated, not committed.
- `extra_css` now points at `theme/`.

### api-reference

- `mkdocs-base.yml` now carries a self-served browser identity: an indigo
  palette with a light/dark toggle, `brand.svg` as the header logo and
  favicon, and `theme.font: false` so no Google Fonts are requested.
- The base `markdown_extensions` gained a Unicode-aware `toc.slugify`, so
  Korean headings keep their characters in anchor ids, and a `mermaid`
  custom fence under `pymdownx.superfences`, so a tagged block renders as
  a `.mermaid` diagram.
- Consuming projects now `INHERIT: docs/theme/mkdocs-base.yml` instead of
  copying settings out of it. Because MkDocs replaces lists and scalars
  wholesale on merge, `theme.features`, `markdown_extensions`,
  `extra_css`, and `exclude_docs` are defined fully in the base and must
  never be partially overridden by a consumer. The sample builds through
  this path against a theme installed from the local checkout; its
  `docs/theme/` tree is generated, not committed.
- `extra_css` now points at `theme/` and includes `api.css`.

### shared

- `styles/base.css` declares `@font-face` for the six shipped woff2 files
  and sets `--md-text-font: "Pretendard"`, giving Korean body typography
  served entirely from the site. It also carries shared rules that scroll
  wide tables horizontally and center Mermaid diagrams.

### scripts

- Added `install-samples.sh`, which installs the theme into each sample
  from the local checkout so the samples build through the same `INHERIT`
  path a consumer uses. It takes a `--force` (`--clean`) flag that drops
  each sample's generated `docs/theme/` before reinstalling, so edits to a
  template or shared file are picked up instead of the cached tree
  `fetch-theme.sh` would otherwise keep. `serve-samples.sh` passes
  `--force` on every run so the preview always reflects edits.
- `fetch-theme.sh` now installs into `docs/theme/` instead of
  `docs/.theme/`. MkDocs excludes every dot-prefixed path from the build,
  so assets installed under the old path never reached the published site.
- `fetch-theme.sh` takes no arguments. The repository, template, and
  version are read from `docs/theme.toml`, which the consuming project
  commits. `--source <dir>` installs from a local checkout instead of a
  release and records `source = "local"` in `docs/theme/.meta`.
- The install set gained `mkdocs-base.yml`, `shared/styles/base.css`, and
  `build-docs-pdf.sh`, so consumers no longer keep their own copy of the
  PDF script. `docs/theme/.meta` records the installed `repo`, `version`,
  `template`, `digest`, and `source`; an unchanged tree is left alone and
  an edited one is reinstalled. `docs/theme/` is the only path the
  installer replaces: the tree is staged in a uniquely named directory
  created beside it, so nothing else the project keeps under `docs/` is
  removed.
- `build-docs-pdf.sh` takes an optional config path after the locale and
  reads all cover text and the output filename from the config's
  `extra.pdf` block. `extra.pdf_copyright` is replaced by
  `extra.pdf.copyright` and is now an error. The config it generates for
  MkDocs goes to a uniquely named scratch file, so a project that already
  has an `mkdocs.tmp.yml` no longer has it overwritten and deleted.
  `extra.pdf` is the only source of cover text: a leftover top-level
  `extra.cover_tagline` no longer renders when `extra.pdf.cover_tagline`
  is unset for the locale being built.
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

[0.2.0]: https://github.com/aicers/docs-theme/tree/0.2.0
[0.1.0]: https://github.com/aicers/docs-theme/tree/0.1.0
