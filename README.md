# docs-theme

Shared MkDocs Material theme, PDF templates, and styling for aicers
documentation.

## Repository Structure

```text
.github/
  workflows/
    docs.yml            GitHub Pages deployment
templates/              Template assets grouped by document type
  manual/               User manual template
    mkdocs-base.yml       Reference MkDocs config
    styles/               Browser CSS (lists, PDF print guardrails)
    pdf/                  PDF cover page and SCSS
  api-reference/        API reference template
    styles/               Includes api.css for method badges
    pdf/                  PDF cover page and SCSS
  design-doc/           (planned)
  release-notes/        (planned)
shared/                 Assets shared across all templates
  fonts/                  Roboto and Pretendard web fonts
  brand.svg               Brand logo
  styles/                 Base CSS
samples/                Per-template sample sites for previewing
  index.html              Landing page linking to all samples
  api-reference/
  manual/
scripts/                Build and install helpers
  fetch-theme.sh          Install a template into a consuming project
  build-docs-pdf.sh       Generate PDF from an MkDocs project
  serve-samples.sh        Serve all sample sites at once
tests/                  Fixture-driven checks for the shipped scripts
  installer-test.sh       fetch-theme.sh, end to end
  pdf-test.sh             build-docs-pdf.sh, end to end
```

## For Docs-Theme Contributors

### Prerequisites

```sh
pip install mkdocs-material mkdocs-static-i18n
```

### Adding or Modifying a Template

1. Edit files under `templates/<name>/` (styles, PDF assets, base
   config).
2. Update the corresponding sample under `samples/<name>/` if new
   elements are affected.

### Previewing Changes

To serve all sample sites at once:

```sh
./scripts/serve-samples.sh
```

Each template gets its own port, assigned in alphabetical order:

| Port | Template      |
|------|---------------|
| 8000 | api-reference |
| 8001 | manual        |

To serve a single template:

```sh
./scripts/serve-samples.sh manual
```

The sample documents exercise all visual elements (headings, lists,
tables, code blocks, admonitions, etc.) so you can verify your
changes in the browser.

### Testing the Shipped Scripts

`tests/` builds throwaway fixture projects in a temporary directory and
runs the consumer-facing scripts against them:

```sh
./tests/installer-test.sh
./tests/pdf-test.sh
```

`installer-test.sh` needs `mkdocs` and reaches no network; the release
path is driven by a stub `gh`. `pdf-test.sh` additionally needs
`mkdocs-with-pdf` and `pdftotext` (poppler-utils), which it uses to read
the rendered covers back. Both run in CI.

### Publishing a New Release

1. Add an entry to `CHANGELOG.md` under `## <version>`.
2. Tag and push, using that same version:

   ```sh
   git tag <version>
   git push origin <version>
   ```

The `release.yml` workflow automatically creates a GitHub Release
from the tag and extracts release notes from `CHANGELOG.md`.
`fetch-theme.sh` uses `gh release download`, so the release must
exist for consumers to install a version.

## For Consuming Projects

### Initial Setup

1. Copy `scripts/fetch-theme.sh` into your project (e.g. at
   `scripts/fetch-theme.sh`).

2. Describe the theme you want in `docs/theme.toml`:

   ```toml
   [theme]
   repo = "aicers/docs-theme"
   template = "manual"
   version = "0.1.0"
   ```

3. Run the installer with no arguments:

   ```sh
   ./scripts/fetch-theme.sh
   ```

It downloads the release named in `docs/theme.toml` and installs:

| Source in the release archive          | Installed as                   |
|----------------------------------------|--------------------------------|
| `templates/<template>/styles/`         | `docs/theme/styles/`           |
| `templates/<template>/pdf/`            | `docs/theme/pdf/`              |
| `templates/<template>/mkdocs-base.yml` | `docs/theme/mkdocs-base.yml`   |
| `shared/styles/base.css`               | `docs/theme/styles/base.css`   |
| `shared/fonts/`                        | `docs/theme/fonts/`            |
| `shared/brand.svg`                     | `docs/theme/brand.svg`         |
| `scripts/build-docs-pdf.sh`            | `docs/theme/build-docs-pdf.sh` |

The install directory must not be dot-prefixed: MkDocs drops every
dot-prefixed path from the build, so assets installed under one would
never reach `site/`, however faithfully `extra_css` pointed at them.

### Wiring mkdocs.yml

Reference the installed assets in your `mkdocs.yml`:

```yaml
extra_css:
  - theme/styles/base.css
  - theme/styles/lists.css
  - theme/styles/pdf.css
```

For the full set of recommended theme settings and markdown
extensions, see the installed `docs/theme/mkdocs-base.yml`.

### Upgrading to a New Version

Edit `version` in `docs/theme.toml` and re-run the installer:

```sh
./scripts/fetch-theme.sh
```

`docs/theme/.meta` records the installed `repo`, `version`, `template`,
`digest`, and `source`. A run whose `.meta` agrees with
`docs/theme.toml` and whose digest still matches the installed files
exits without downloading anything; any edit, addition, or deletion
under `docs/theme/` — including a cleared executable bit — triggers a
reinstall.

### Installing From a Local Checkout

To try theme changes before they are released, install from a checkout
instead of a release:

```sh
./scripts/fetch-theme.sh --source ../docs-theme
```

This reads `template` from `docs/theme.toml` as usual, makes no network
request, and records `source = "local"` in `docs/theme/.meta`. A
released install records `source = "release"`; treat a `local` install
as unpublishable.

The skip check compares the digest of `docs/theme/`, not of the
checkout, so a re-run after editing the checkout reports a skip. Remove
`docs/theme/` to pick the new assets up.

### Building PDF Output

`build-docs-pdf.sh` arrives with the theme, so there is nothing to copy
by hand.

1. Install the PDF dependencies:

   ```sh
   pip install mkdocs-with-pdf
   ```

2. Run the build for each locale:

   ```sh
   ./docs/theme/build-docs-pdf.sh en
   ./docs/theme/build-docs-pdf.sh ko
   ```

   PDFs are written to `site/pdf/`.

The second argument selects the config to build from, which a project
with more than one needs:

```sh
./docs/theme/build-docs-pdf.sh en mkdocs.general.yml
```

It defaults to `mkdocs.yml`. Any other argument shape is a usage error.

#### Cover and Output Configuration

All cover text and the output filename come from an `extra.pdf` block
in the config being built:

```yaml
site_name: Bootroot Manual

extra:
  pdf:
    cover_title:
      en: Bootroot Manual
      ko: Bootroot 설명서
    cover_subtitle:
      en: User Manual
      ko: 사용자 설명서
    cover_tagline:
      en: Deploy and operate Bootroot
      ko: Bootroot 배포 및 운영
    toc_title:
      en: Table of contents
      ko: 목차
    copyright: Copyright 2026 ClumL Inc.
    output_basename: bootroot
```

Every text value is either a plain string used unchanged for every
locale, or a mapping of locale to string. Above, the four cover strings
vary by locale while `copyright` is one string that both covers render
identically.

| Key               | Locale-mapped | Unset falls back to                      |
|-------------------|---------------|------------------------------------------|
| `cover_title`     | yes           | `site_name`                              |
| `cover_subtitle`  | yes           | no subtitle is rendered                  |
| `cover_tagline`   | yes           | no tagline is rendered                   |
| `toc_title`       | yes           | `Table of contents`                      |
| `copyright`       | yes           | the top-level `copyright`, then empty    |
| `author`          | yes           | the build date, formatted for the locale |
| `output_basename` | no            | `site_name`, lowercased and hyphenated   |

`output_basename` is always a plain string; the locale is appended to
the filename, giving `site/pdf/<output_basename>.<locale>.pdf`.

`extra.pdf_copyright` is no longer read. Move it to
`extra.pdf.copyright`; a config still using the old key fails the build
rather than silently dropping the copyright line.

Set `DOCS_PDF_DEBUG=1` to keep the generated `mkdocs.tmp.yml` and
`.pdf-tmp/` for inspection.

## GitHub Pages

On merge to `main`, the CI workflow builds all sample sites and
deploys them to GitHub Pages. The landing page links to each
template sample.

## License

Copyright 2026 ClumL Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this software except in compliance with the License.
You may obtain a copy of the License in the `LICENSE` file.

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the `LICENSE` file for the specific language governing permissions
and limitations under the License.
