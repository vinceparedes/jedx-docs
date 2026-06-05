#!/usr/bin/env bash
# Hybrid-mode build script for jedx-docs.
#
# AUTHORED (build.sh NEVER touches these — edit freely):
#   - All markdown files under docs/ EXCEPT schemas.md and sample-data.md
#   - All images under docs/assets/images/  (pandoc-extracted snapshots)
#   - mkdocs.yml
#
# MECHANICAL (regenerated each run from ../DocumentationPackage):
#   - docs/assets/schemas/                — D_Schemas/*.jschema, *.json
#   - docs/assets/zips/sample-data.zip    — E_SampleData/ packed
#   - docs/schemas.md                     — schema listing with download buttons
#   - docs/sample-data.md                 — README + zip download button
#
# Run after dropping new schemas in D_Schemas/ or changing E_SampleData/.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${REPO_ROOT}/../DocumentationPackage"
DOCS="${REPO_ROOT}/docs"
ASSETS="${DOCS}/assets"

[[ -d "${SRC}" ]] || { echo "Source dir not found: ${SRC}" >&2; exit 1; }

# Reset only the mechanical paths. Leaves authored content untouched.
rm -rf "${ASSETS}/schemas" "${ASSETS}/zips"
rm -f "${DOCS}/schemas.md" "${DOCS}/sample-data.md"
mkdir -p "${ASSETS}/schemas" "${ASSETS}/zips"

# --- Schemas (D_Schemas) -----------------------------------------------------
SCHEMAS_SRC="${SRC}/D_Schemas"
if [[ -d "${SCHEMAS_SRC}" ]]; then
  echo "Building schemas section..."
  cp "${SCHEMAS_SRC}"/*.jschema "${SCHEMAS_SRC}"/*.json "${ASSETS}/schemas/" 2>/dev/null || true
  python3 - "${SCHEMAS_SRC}" "${DOCS}/schemas.md" <<'PY'
import json, pathlib, sys
src_dir = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])

def extract_title_desc(p):
    try:
        data = json.loads(p.read_text())
    except Exception:
        return None, None
    title = data.get('title')
    desc = data.get('description')
    if (not title or not desc) and isinstance(data.get('definitions'), dict):
        for v in data['definitions'].values():
            if isinstance(v, dict):
                title = title or v.get('title')
                desc = desc or v.get('description')
                if title and desc:
                    break
    return title, desc

files = sorted([p for p in src_dir.iterdir() if p.suffix in ('.jschema', '.json')])
lines = [
    '# Schemas', '',
    'JSON Schema definitions for the JEDx data model. Each file is downloadable.', '',
]
for p in files:
    title, desc = extract_title_desc(p)
    lines.append(f'## `{p.name}`'); lines.append('')
    if title:
        lines.append(f'**{title}**'); lines.append('')
    if desc:
        lines.append(desc.strip()); lines.append('')
    lines.append(f'[Download `{p.name}`](assets/schemas/{p.name}){{ .md-button }}')
    lines.append('')
out.write_text('\n'.join(lines))
PY
else
  echo "  (skipped, ${SCHEMAS_SRC} not found)"
fi

# --- Sample Data (E_SampleData) ---------------------------------------------
SAMPLE_SRC="${SRC}/E_SampleData"
if [[ -d "${SAMPLE_SRC}" ]]; then
  echo "Building sample-data section..."
  ZIP_OUT="${ASSETS}/zips/sample-data.zip"
  (cd "${SRC}" && zip -rq "${ZIP_OUT}" "E_SampleData" -x "*.DS_Store" -x "E_SampleData/README.md")
  python3 - "${SAMPLE_SRC}" "${DOCS}/sample-data.md" <<'PY'
import pathlib, sys
src_dir = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
readme = src_dir / 'README.md'
readme_body = ''
if readme.exists():
    text = readme.read_text().splitlines()
    if text and text[0].startswith('# '):
        text = text[1:]
    while text and not text[0].strip():
        text = text[1:]
    readme_body = '\n'.join(text).rstrip() + '\n'

subdirs = sorted([d for d in src_dir.iterdir() if d.is_dir()])
contents_lines = []
for d in subdirs:
    n = sum(1 for p in d.iterdir() if p.is_file() and not p.name.startswith('.'))
    contents_lines.append(f'- **{d.name}/** — {n} files')

parts = [
    '# Sample Data', '',
    '[Download all sample data (ZIP)](assets/zips/sample-data.zip){ .md-button .md-button--primary }',
    '',
    readme_body,
    '## Contents', '',
    *contents_lines, '',
]
out.write_text('\n'.join(parts))
PY
else
  echo "  (skipped, ${SAMPLE_SRC} not found)"
fi

echo "Done."
