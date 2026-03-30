# Changelog

This file documents recent notable changes to this project. The format of this
file is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

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
