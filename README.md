# UMEC Documentation

This repository contains the official documentation for the UMEC platform.

## Overview

UMEC is a proprietary platform designed for scalable device management, integrations, and API-driven workflows.

This repository provides:

* API documentation
* Integration guides
* Usage examples
* Architectural overviews

## Repository Scope

This repository contains **documentation only**.

It does **not** contain source code of the UMEC platform.

## Site

The static site is built with **MkDocs** and the **Material for MkDocs** theme, and published on **GitHub Pages**.

## Requirements

- Python 3.x
- `pip` (usually available; if the `pip` command is missing from PATH, use `python -m pip` — see below)

## Local development

```powershell
python -m pip install -r src/utilities-quickstarts/requirements.txt
python -m mkdocs serve -f src/utilities-quickstarts/mkdocs.yml
```

Open the URL printed in the terminal (often `http://127.0.0.1:8000`).

Build without running a server:

```powershell
python -m mkdocs build --strict -f src/utilities-quickstarts/mkdocs.yml
```

Output goes to the `site/` directory (it is gitignored).

## Publishing to GitHub Pages

1. In `src/utilities-quickstarts/mkdocs.yml`, set real values for `site_url` and `repo_url`.
2. In the repository: **Settings → Pages → Build and deployment** — set the source to **GitHub Actions**.
3. After a push to `develop` with changes in `src/utilities-quickstarts/**`, the workflow `.github/workflows/deploy-pages.yml` builds and publishes the site.

## Repository layout

| Path | Purpose |
|------|---------|
| `.github/workflows/deploy-pages.yml` | CI: build and deploy to Pages |
| `src/utilities-quickstarts/mkdocs.yml` | MkDocs configuration and table of contents (`nav`) |
| `src/utilities-quickstarts/requirements.txt` | Python dependencies |
| `src/utilities-quickstarts/docs/` | Markdown sources |
| `src/utilities-quickstarts/docs/quickstarts/` | Scenario pages (Markdown) |
| `src/utilities-quickstarts/docs/assets/` | Images and other static assets |

## Adding a page

1. Add a file under `src/utilities-quickstarts/docs/…` (for example `src/utilities-quickstarts/docs/quickstarts/new-scenario.md`).
2. Add an entry under `nav` in `src/utilities-quickstarts/mkdocs.yml`.
3. Verify with `python -m mkdocs build --strict -f src/utilities-quickstarts/mkdocs.yml`.

## Links

- [MkDocs](https://www.mkdocs.org/)
- [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/)


## License

The documentation in this repository is licensed under
Creative Commons Attribution-NoDerivatives 4.0 International (CC BY-ND 4.0).

You are free to:

* Share — copy and redistribute the material in any medium or format, including commercial use

Under the following terms:

* Attribution — appropriate credit must be given
* NoDerivatives — modified versions may not be distributed

Full license text: https://creativecommons.org/licenses/by-nd/4.0/

### Important

The software, APIs, and systems described in this repository are proprietary
and are **not covered** by this license.

All rights to the software are reserved.

## Contributing

This repository is maintained internally.

External contributions are not accepted unless explicitly approved.

## Contact

For partnership or integration inquiries, please contact the UMEC team.
