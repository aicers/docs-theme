# docs-theme

Shared MkDocs Material theme, PDF templates, and styling for aicers
documentation.

## Repository Structure

```
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
```

## For Docs-Theme Contributors

### Prerequisites

```
pip install mkdocs-material mkdocs-static-i18n
```

### Adding or Modifying a Template

1. Edit files under `templates/<name>/` (styles, PDF assets, base
   config).
2. Update the corresponding sample under `samples/<name>/` if new
   elements are affected.

### Previewing Changes

To serve all sample sites at once:

```
./scripts/serve-samples.sh
```

Each template gets its own port, assigned in alphabetical order:

| Port | Template      |
|------|---------------|
| 8000 | api-reference |
| 8001 | manual        |

To serve a single template:

```
./scripts/serve-samples.sh manual
```

The sample documents exercise all visual elements (headings, lists,
tables, code blocks, admonitions, etc.) so you can verify your
changes in the browser.

### Publishing a New Release

1. Add an entry to `CHANGELOG.md` under `## 1.0.0`.
2. Tag and push:

   ```
   git tag 1.0.0
   git push origin 1.0.0
   ```

The `release.yml` workflow automatically creates a GitHub Release
from the tag and extracts release notes from `CHANGELOG.md`.
`fetch-theme.sh` uses `gh release download`, so the release must
exist for consumers to install a version.

## For Consuming Projects

### Initial Setup

1. Copy `scripts/fetch-theme.sh` into your project (e.g. at
   `scripts/fetch-theme.sh`).

2. Run it with the desired version and template:

   ```
   ./scripts/fetch-theme.sh --version 1.0.0 --template manual
   ```

   This downloads the release, extracts the template assets, and
   installs them into `docs/.theme/`.

3. Add `docs/.theme/` to `.gitignore` — it is fetched, not committed.

### Wiring mkdocs.yml

Reference the installed assets in your `mkdocs.yml`:

```yaml
extra_css:
  - .theme/styles/lists.css
  - .theme/styles/pdf.css
```

For the full set of recommended theme settings and markdown
extensions, see `templates/manual/mkdocs-base.yml`.

### Upgrading to a New Version

Update the version argument and re-run:

```
./scripts/fetch-theme.sh --version 1.1.0 --template manual
```

The `.theme/.version` file records the installed version.

### Building PDF Output

1. Copy `scripts/build-docs-pdf.sh` into your project.

2. Install the PDF dependencies:

   ```
   pip install mkdocs-with-pdf
   ```

3. Run the build for each locale:

   ```
   ./scripts/build-docs-pdf.sh en
   ./scripts/build-docs-pdf.sh ko
   ```

   PDFs are written to `site/pdf/`.

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
