#!/usr/bin/env bash
# Hybrid-mode build script for jedx-docs.
#
# AUTHORED (build.sh NEVER touches these — edit freely):
#   - All markdown files under docs/ EXCEPT data-model.md
#   - All images under docs/assets/images/  (pandoc-extracted snapshots)
#   - mkdocs.yml
#
# MECHANICAL (regenerated each run from ../DocumentationPackage):
#   - docs/assets/data-model/             — D_Schemas/*.jschema, *.json
#   - docs/assets/zips/sample-data.zip    — E_SampleData/ packed
#   - docs/data-model.md                  — combined schemas listing + Sample Data subsection
#
# Run after dropping new schemas in D_Schemas/ or changing E_SampleData/.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${REPO_ROOT}/../DocumentationPackage"
DOCS="${REPO_ROOT}/docs"
ASSETS="${DOCS}/assets"

[[ -d "${SRC}" ]] || { echo "Source dir not found: ${SRC}" >&2; exit 1; }

# Reset only the mechanical paths. Leaves authored content untouched.
rm -rf "${ASSETS}/data-model" "${ASSETS}/zips"
rm -f "${DOCS}/data-model.md"
mkdir -p "${ASSETS}/data-model" "${ASSETS}/zips"

# --- Data Model (D_Schemas + E_SampleData combined) --------------------------
# Single page: schemas listing followed by a "Sample Data" subsection that
# includes the README and a zip download button.
SCHEMAS_SRC="${SRC}/D_Schemas"
SAMPLE_SRC="${SRC}/E_SampleData"

echo "Building data-model section..."

# Copy schemas to assets.
if [[ -d "${SCHEMAS_SRC}" ]]; then
  cp "${SCHEMAS_SRC}"/*.jschema "${SCHEMAS_SRC}"/*.json "${ASSETS}/data-model/" 2>/dev/null || true
fi

# Build sample-data.zip if source exists.
if [[ -d "${SAMPLE_SRC}" ]]; then
  (cd "${SRC}" && zip -rq "${ASSETS}/zips/sample-data.zip" "E_SampleData" -x "*.DS_Store" -x "E_SampleData/README.md")
fi

# Emit the combined markdown page.
python3 - "${SCHEMAS_SRC}" "${SAMPLE_SRC}" "${DOCS}/data-model.md" <<'PY'
import json, pathlib, sys
schemas_dir = pathlib.Path(sys.argv[1])
sample_dir  = pathlib.Path(sys.argv[2])
out         = pathlib.Path(sys.argv[3])

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

lines = [
    '# Data Model', '',
    'JSON Schema definitions for the JEDx data model. Each file is downloadable.', '',
]

# --- Schemas -----------------------------------------------------------------
if schemas_dir.exists():
    files = sorted([p for p in schemas_dir.iterdir() if p.suffix in ('.jschema', '.json')])
    for p in files:
        title, desc = extract_title_desc(p)
        lines.append(f'## `{p.name}`'); lines.append('')
        if title:
            lines.append(f'**{title}**'); lines.append('')
        if desc:
            lines.append(desc.strip()); lines.append('')
        lines.append(f'[Download `{p.name}`](assets/data-model/{p.name}){{ .md-button }}')
        lines.append('')

# --- Sample Data (appended subsection) ---------------------------------------
if sample_dir.exists():
    lines += ['## Sample Data', '',
              '[Download all sample data (ZIP)](assets/zips/sample-data.zip){ .md-button .md-button--primary }',
              '']
    readme = sample_dir / 'README.md'
    if readme.exists():
        body = readme.read_text().splitlines()
        if body and body[0].startswith('# '):
            body = body[1:]
        while body and not body[0].strip():
            body = body[1:]
        if body:
            lines += body + ['']
    subdirs = sorted([d for d in sample_dir.iterdir() if d.is_dir()])
    if subdirs:
        lines += ['### Contents', '']
        for d in subdirs:
            n = sum(1 for p in d.iterdir() if p.is_file() and not p.name.startswith('.'))
            lines.append(f'- **{d.name}/** — {n} files')
        lines.append('')

out.write_text('\n'.join(lines))
PY

echo "Done."
