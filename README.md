# jedx-docs

MkDocs site for JEDx CAR and Collector Service Software documentation.

Source files (`.docx`, `.txt`, `.pdf`, `.png`, `.yaml`) live in
`../DocumentationPackage/` and are converted into Markdown by `scripts/build.sh`.
Generated Markdown is committed to `docs/` and published to GitHub Pages by
the workflow in `.github/workflows/deploy.yml`.

## Local preview

```sh
source .venv/bin/activate
mkdocs serve
```

## Regenerate from source

```sh
./scripts/build.sh
git add docs/ && git commit -m "Refresh docs" && git push
```

The push triggers GitHub Pages deployment.

## First-time setup on a new machine

```sh
python3 -m venv .venv
.venv/bin/pip install mkdocs mkdocs-material
brew install pandoc
```
