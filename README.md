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
  brand.svg               ClumL wordmark, white lettering (site header)
  brand-print.svg         ClumL wordmark, black lettering (PDF cover)
  brand-symbol.svg        ClumL cube alone (favicon)
  styles/                 Base CSS
samples/                Per-template sample sites for previewing
  index.html              Landing page linking to all samples
  api-reference/
  manual/
scripts/                Build and install helpers
  fetch-theme.sh          Install a template into a consuming project
  install-samples.sh      Install the theme into each sample (local source)
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

Each sample inherits the theme through the same `INHERIT` path a
consumer uses, so the theme must be installed into the sample first. The
sample's `docs/theme/` tree is generated, not committed;
`serve-samples.sh` installs it from this checkout before serving, and
`install-samples.sh` does the same install step on its own for a plain
`mkdocs build`.

`serve-samples.sh` reinstalls with `--force` on every run, so your edits
to a template or shared file always show up. `install-samples.sh` on its
own skips reinstalling when the already-installed tree is intact — which
means a plain rerun keeps serving the *old* assets after you edit the
source. Pass `--force` (or `--clean`) to drop and reinstall:

```sh
./scripts/install-samples.sh --force
```

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

## Versioning

Releases are tagged `MAJOR.MINOR.PATCH` with no `v` prefix, matching the
tag pattern (`[0-9]+.[0-9]+.[0-9]+`) that `release.yml` triggers on.
Because a single commit here controls every consumer's build and a tag
becomes a version-bump pull request in each consumer, the number states
how a release can affect a consumer's build:

- **MAJOR** — removing a markdown extension or theme feature from
  `mkdocs-base.yml`, renaming or relocating an installed path, or any
  other change that can break a consumer's build. Consumers must review
  these against their own documents.
- **MINOR** — adding a markdown extension, theme feature, or asset.
- **PATCH** — CSS and PDF adjustments that cannot break a build.

Templates are **not** versioned separately: one repository version covers
all of them, and the vendored diff in a consumer's bump pull request
shows whether that consumer is actually affected.

While the version is below `1.0.0`, a breaking change bumps MINOR rather
than MAJOR, and everything else bumps PATCH. The project stays on `0.x`
until the contract above has been proven by consumers actually adopting
it.

A release is only meaningful when the installed surface actually changed.
The release workflow rejects a tag whose release surface — everything
`fetch-theme.sh` installs, plus `fetch-theme.sh` itself — is byte-identical
to the previous tag's, because such a tag has nothing for consumers to
fetch and would only produce an empty-diff bump pull request.

## For Consuming Projects

### Initial Setup

1. Copy `scripts/fetch-theme.sh` into your project (e.g. at
   `scripts/fetch-theme.sh`).

2. Describe the theme you want in `docs/theme.toml`:

   ```toml
   [theme]
   repo = "aicers/docs-theme"
   template = "manual"
   version = "<version>"
   ```

   Use the tag of the release you want to pin to; the
   [releases page](https://github.com/aicers/docs-theme/releases) lists
   them.

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
| `shared/brand-print.svg`               | `docs/theme/brand-print.svg`   |
| `shared/brand-symbol.svg`              | `docs/theme/brand-symbol.svg`  |
| `scripts/build-docs-pdf.sh`            | `docs/theme/build-docs-pdf.sh` |

The install directory must not be dot-prefixed: MkDocs drops every
dot-prefixed path from the build, so assets installed under one would
never reach `site/`, however faithfully `extra_css` pointed at them.

`docs/theme/` is the only path the installer replaces. The tree is
staged first in a uniquely named directory created beside it, which is
removed when the run ends, so an interrupted install leaves neither a
half-written `docs/theme/` nor anything else you keep under `docs/`.

**Commit the installed `docs/theme/` tree.** It is vendored, not
git-ignored: committing it makes the theme part of your repository, so
the site builds reproducibly for anyone who checks the project out and a
version bump lands as a reviewable diff.

The installer writes `docs/theme/.meta`, which records a `digest` of the
installed files. Verify the committed tree against that digest by
re-running the installer: a run whose `.meta` agrees with
`docs/theme.toml` and whose digest still matches the files on disk exits
without changing anything, while any edit, addition, or deletion under
`docs/theme/` is detected and reinstalled. Running `./scripts/fetch-theme.sh`
in CI is a convenient way to catch a vendored tree that has drifted from
its `.meta`.

### Wiring mkdocs.yml

Inherit the installed base config rather than copying settings out of
it. Your `mkdocs.yml` sets only the site-specific keys and inherits
everything shared — theme, palette, fonts, logo, markdown extensions,
`extra_css`, and the published-file exclusions:

```yaml
INHERIT: docs/theme/mkdocs-base.yml
site_name: Example Manual
repo_url: https://github.com/aicers/example

plugins:
  - search
  - i18n:
      docs_structure: folder
      languages: [...]
```

MkDocs resolves `INHERIT` relative to the config file's directory and
deep-merges the base into your config with `mergedeep.merge(parent,
child)`. A useful side effect: if you forget to install the theme, the
build fails immediately with `Inherited config file does not exist`
instead of producing a silently unstyled site.

**Dictionaries merge recursively, but lists and scalars are replaced
wholesale.** A consumer that sets `theme.features`,
`markdown_extensions`, `extra_css`, or the `exclude_docs` scalar
partially silently discards everything the base defined for that key —
setting `theme.features: [navigation.top]` drops every other feature the
base provides. So define those four keys **fully in the base only**, and
never partially override them from a consuming `mkdocs.yml`. Keep the
site-specific keys — `site_name`, `repo_url`, `nav` — in your own
config. `plugins` is a list too: the base ships a `search` + `i18n`
default, and a consumer that needs its own `i18n` languages redefines
the whole `plugins` list (which replaces the default wholesale), as the
sample sites do.

### Branding

The theme ships the **ClumL company mark** in three variants, because one
file cannot serve all three places. `brand.svg` has white lettering for
the site header, which sits on the primary-coloured bar. `brand-print.svg`
has black lettering for the PDF cover, which sits on white paper.
`brand-symbol.svg` is the cube alone: a wordmark scaled to a 16-pixel tab
icon is unreadable, and the cube is not. The base wires all three, so a
project documenting something ClumL publishes needs no branding config at
all.

A project documenting a product with its own mark overrides them. Commit
the product's assets under `docs/` — **not** under `docs/theme/`, which
is covered by the `.meta` digest and reverted on the next installer run:

```yaml
theme:
  logo: assets/product-logo.svg
  favicon: assets/product-symbol.svg

extra:
  pdf:
    cover_logo: assets/product-logo-print.svg
```

`theme` is a mapping, so those two keys merge into the base rather than
replacing it — the palette, fonts, and features it defines all survive.
`extra.pdf.cover_logo` is a path relative to `docs_dir`; a path that does
not resolve is an error rather than a silent fall back to the company
mark, which would otherwise ship a cover branded with the wrong name.

The base already wires `extra_css` to the installed stylesheets (base,
lists, and PDF guardrails, plus `api.css` for the api-reference
template), so you do not list them yourself. To review the full set of
inherited settings, read the installed `docs/theme/mkdocs-base.yml`.

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

#### Build Provenance

Every cover carries a line naming the theme that rendered it —
`docs-theme 1.2.3` for a downloaded install. A PDF is handed to a reader
and leaves the repository that produced it, so without this there is
nothing in the artifact to reproduce a rendering complaint against, and
once several projects bump the theme on their own schedules the answer
stops being inferable.

The value comes from `docs/theme/.meta`, the record of what is installed,
rather than from the request in `docs/theme.toml` — a hand-edited or
drifted tree would otherwise misreport itself. A `--source` install has a
version that never resolved a release, so it prints `docs-theme (local
build)` instead of a number. It is not configurable, and a missing
`.meta` is an error rather than a quietly omitted line.

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

`extra.pdf` is the only source of cover text. `cover_tagline` in
particular reaches the cover through the top-level `extra` mapping, so a
`extra.cover_tagline` left over from an earlier setup is not read: it is
replaced when `extra.pdf.cover_tagline` resolves for the locale being
built, and removed when it does not.

`extra.pdf_copyright` is no longer read. Move it to
`extra.pdf.copyright`; a config still using the old key fails the build
rather than silently dropping the copyright line.

The script writes the config it hands to MkDocs to a scratch file next
to your own config and removes it afterwards. The name is unique per
run, so it never lands on a file you already have there. Set
`DOCS_PDF_DEBUG=1` to keep that config and `.pdf-tmp/` for inspection;
the path of the generated config is then reported on stderr.

## GitHub Pages

On merge to `main`, the Docs workflow builds all sample sites and
deploys them to GitHub Pages. The landing page links to each template
sample and is stamped with the commit it was built from, since the
deployed site shows unreleased state that no consumer can yet install.

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
