# Changelog

This file documents recent notable changes to this project. Within each
release, entries are grouped by the area a consumer's reviewer triages —
`manual`, `api-reference`, `shared`, and `scripts` — rather than by the
Keep a Changelog change-type headings, so a consumer reads only the
sections that affect its template. Version numbers follow the
`MAJOR.MINOR.PATCH` policy described in [the README](README.md#versioning).

## Unreleased

### shared

- The brand assets are the **ClumL company mark**, replacing a
  `brand.svg` that was the Clumit Security product logo — one consumer's
  product, shipped to every consumer. A project documenting a different
  product would have published another product's branding.
- `brand.svg` now carries **white** lettering, for the site header, which
  sits on the primary-coloured bar. Anything rendering it on a light
  background needs `brand-print.svg` instead.
- Added `brand-print.svg`, the black-lettering variant the PDF cover
  uses, and `brand-symbol.svg`, the cube alone. A wordmark scaled to a
  16-pixel tab icon is unreadable; the cube is not.

### manual

- `theme.favicon` points at `theme/brand-symbol.svg` rather than the
  wordmark.

### api-reference

- `theme.favicon` points at `theme/brand-symbol.svg` rather than the
  wordmark.

### scripts

- `fetch-theme.sh` installs all three brand assets.
- `build-docs-pdf.sh` takes the cover logo from `brand-print.svg`, and
  accepts `extra.pdf.cover_logo` — a path relative to `docs_dir` — so a
  project documenting a product with its own mark can put it on the
  cover. A path that does not resolve is an error rather than a silent
  fall back to the company mark.

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
- `pdf/styles.scss` no longer forces a page break before every subsection
  and no longer pads one out to a full page. A nav section whose children
  are separate pages becomes a single article of stacked `section`
  elements, and the forced break dropped everything after each one's first
  paragraph from the PDF, so a chapter's tables, lists, and admonitions
  went missing without a warning. Top-level chapters still start on a new
  page.
- A long table, list, code block, or block quote now splits across pages
  instead of moving whole and leaving the page it came from half empty.
  Admonitions and content tabs still move whole, because splitting a
  bordered box leaves it open at the page edge. A split never strands a
  lone list item or table row on either side of the break, and a heading
  or a bold-only label stays with the block it introduces.
- `styles/pdf.css` now agrees with `pdf/styles.scss` on how a block
  fragments. The two disagreed, so browser print and PDF export broke a
  page at different points.
- A PDF table now carries its own grid, header shading, and cell
  padding. Material draws the grid with a custom property that only a
  browser's colour scheme defines, so in the PDF it resolved to nothing
  and a table arrived as unruled columns of text with no way to tell which
  cell belonged to which row. A single-column table keeps its content
  width instead of being stretched across the page.
- A long inline-code value in a cell -- a dotted setting name with no
  break opportunity of its own -- now wraps instead of setting its
  column's minimum width and squeezing every other column into a ribbon.
  Ordinary text in a cell still only breaks between words.
- A table row now moves whole rather than splitting with its cells
  misaligned either side of the break. The table around it still splits,
  one row at a time, and a row too tall for a page of its own splits
  anyway rather than losing its content.

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
- `pdf/styles.scss` no longer forces a page break before every subsection
  and no longer pads one out to a full page. A nav section whose children
  are separate pages becomes a single article of stacked `section`
  elements, and the forced break dropped everything after each one's first
  paragraph from the PDF, so a chapter's tables, lists, and admonitions
  went missing without a warning. Top-level chapters still start on a new
  page.
- A long table, list, code block, or block quote now splits across pages
  instead of moving whole and leaving the page it came from half empty.
  Admonitions and content tabs still move whole, because splitting a
  bordered box leaves it open at the page edge. A split never strands a
  lone list item or table row on either side of the break, and a heading
  or a bold-only label stays with the block it introduces.
- `styles/pdf.css` now agrees with `pdf/styles.scss` on how a block
  fragments. The two disagreed, so browser print and PDF export broke a
  page at different points.
- A PDF table now carries its own grid, header shading, and cell
  padding. Material draws the grid with a custom property that only a
  browser's colour scheme defines, so in the PDF it resolved to nothing
  and a table arrived as unruled columns of text with no way to tell which
  cell belonged to which row. A single-column table keeps its content
  width instead of being stretched across the page.
- A long inline-code value in a cell -- a dotted setting name with no
  break opportunity of its own -- now wraps instead of setting its
  column's minimum width and squeezing every other column into a ribbon.
  Ordinary text in a cell still only breaks between words.
- A table row now moves whole rather than splitting with its cells
  misaligned either side of the break. The table around it still splits,
  one row at a time, and a row too tall for a page of its own splits
  anyway rather than losing its content.

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
- `pdf-test.sh` builds a nav-grouped fixture and reads the rendered pages
  back with `pdftotext`, so the chapter content, the chapter page break,
  the label kept with its list, and the two-row minimum on a split table
  are each asserted. A PDF build that exits 0 was not evidence the chapter
  was in the PDF, which is how the dropped content went unnoticed.
- `pdf-test.sh` also reads a table fixture back with its line breaks
  left in, so where a cell wrapped is asserted rather than assumed. Every
  other reader there strips whitespace, which glues a word the renderer
  split back together and hides a cell whose column collapsed to a single
  character.

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
