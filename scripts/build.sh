#!/usr/bin/env bash
# Regenerate docs/ from sources in ../DocumentationPackage.
# Idempotent: wipes docs/ contents (but not docs/.gitkeep) and rebuilds.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${REPO_ROOT}/../DocumentationPackage"
DOCS="${REPO_ROOT}/docs"
ASSETS="${DOCS}/assets"

if ! command -v pandoc >/dev/null 2>&1; then
  echo "pandoc not found. Install with: brew install pandoc" >&2
  exit 1
fi

if [[ ! -d "${SRC}" ]]; then
  echo "Source dir not found: ${SRC}" >&2
  exit 1
fi

echo "Source: ${SRC}"
echo "Output: ${DOCS}"

# Clean output (preserves docs/ itself)
rm -rf "${DOCS}"
mkdir -p "${DOCS}" "${ASSETS}/images" "${ASSETS}/pdfs" "${DOCS}/sam-templates" "${DOCS}/ai-generated"

# ------------------------------------------------------------
# Helper: convert a .docx to .md, extracting embedded media into assets/images
# ------------------------------------------------------------
convert_docx() {
  local src="$1" out="$2" media_subdir="$3"
  local media_dir="${ASSETS}/images/${media_subdir}"
  mkdir -p "${media_dir}"
  pandoc \
    --from=docx \
    --to=gfm \
    --wrap=none \
    --extract-media="${media_dir}" \
    --output="${out}" \
    "${src}"
  # Pandoc writes media as ABSOLUTE paths; rewrite to site-relative.
  # Compute the relative path from the markdown file's location to assets/images.
  local md_dir; md_dir="$(dirname "${out}")"
  local rel; rel="$(python3 -c "import os; print(os.path.relpath('${ASSETS}/images', '${md_dir}'))")"
  # Rewrite "<media_dir>/" -> "<rel>/<media_subdir>/"
  python3 - "$out" "$media_dir" "$rel/$media_subdir" <<'PY'
import sys, pathlib, re
md_path, abs_media, rel_media = sys.argv[1], sys.argv[2], sys.argv[3]
text = pathlib.Path(md_path).read_text()
text = text.replace(abs_media, rel_media)
pathlib.Path(md_path).write_text(text)
PY
}

# ------------------------------------------------------------
# Top-level docs (.docx -> .md)
# ------------------------------------------------------------
echo "Converting top-level .docx files..."
convert_docx "${SRC}/READMEfirst.docx"                                                          "${DOCS}/index.md"          "readme"
convert_docx "${SRC}/A_JEDx Requirements - CAR and Collector Service Software.docx"             "${DOCS}/requirements.md"   "requirements"
convert_docx "${SRC}/B_JEDx AWS Architecture - CAR and Collector Service Software.docx"         "${DOCS}/architecture.md"   "architecture"

# Drop any prelude (subtitle/date lines) before the first H1, and prepend a
# default title only if the file contains no H1 anywhere in its first 30 lines.
normalize_title() {
  python3 - "$1" "$2" <<'PY'
import sys, pathlib
p, default = pathlib.Path(sys.argv[1]), sys.argv[2]
lines = p.read_text().splitlines()
first_h1 = next((i for i, ln in enumerate(lines[:30]) if ln.startswith('# ')), None)
if first_h1 is None:
    out = [f'# {default}', ''] + lines
else:
    out = lines[first_h1:]
p.write_text('\n'.join(out) + '\n')
PY
}
normalize_title "${DOCS}/index.md"        "JEDx Documentation"
normalize_title "${DOCS}/requirements.md" "JEDx Requirements"
normalize_title "${DOCS}/architecture.md" "JEDx AWS Architecture"

# Some source docs used H1 for section headings. Keep the first H1 as the page
# title, demote any subsequent H1s to H2 (and shift their descendants down).
demote_extra_h1s() {
  python3 - "$1" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1])
lines = p.read_text().splitlines()
seen_first = False
out = []
in_fence = False
for ln in lines:
    if ln.lstrip().startswith('```'):
        in_fence = not in_fence
        out.append(ln); continue
    if not in_fence:
        m = re.match(r'^(#{1,5}) (.*)$', ln)
        if m:
            level, rest = m.group(1), m.group(2)
            if level == '#':
                if seen_first:
                    out.append('## ' + rest); continue
                seen_first = True
    out.append(ln)
p.write_text('\n'.join(out) + '\n')
PY
}

demote_extra_h1s "${DOCS}/index.md"
demote_extra_h1s "${DOCS}/requirements.md"
demote_extra_h1s "${DOCS}/architecture.md"

# Strip Word's embedded TOC (pandoc preserves it as nested page-number links).
# Match lines like "[Title 2](#anchor)" or "> [Title 2](#anchor)" inside the
# pre-content block (between the first H1 and the next heading).
strip_word_toc() {
  python3 - "$1" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1])
lines = p.read_text().splitlines()
# Detects a line that's just a markdown anchor link — covers both flat
# "[Title 2](#anchor)" and pandoc's nested "[Title [2](#a)](#b)".
toc_link_re = re.compile(r'^\s*>?\s*\[.+\]\(#[^)]+\)\s*$')
i = 0
while i < len(lines) and not lines[i].startswith('# '):
    i += 1
i += 1
j = i
while j < len(lines) and not lines[j].lstrip().startswith('#'):
    j += 1
block = lines[i:j]
toc_count = sum(1 for ln in block if toc_link_re.match(ln))
# If the prefix block is dominated by TOC link lines, drop the whole block.
if toc_count >= 3:
    new_lines = lines[:i] + [''] + lines[j:]
else:
    new_lines = lines
p.write_text('\n'.join(new_lines) + '\n')
PY
}

strip_word_toc "${DOCS}/index.md"
strip_word_toc "${DOCS}/requirements.md"
strip_word_toc "${DOCS}/architecture.md"

# ------------------------------------------------------------
# SAM Templates section: PDFs + annotated YAMLs
# ------------------------------------------------------------
echo "Building SAM templates section..."
SAM_SRC="${SRC}/C_sam_templates"
SAM_OUT="${DOCS}/sam-templates"

# Copy PDFs to assets and create a markdown wrapper for each
copy_pdf_with_wrapper() {
  local src_pdf="$1" md_out="$2" title="$3"
  local pdf_name; pdf_name="$(basename "${src_pdf}")"
  cp "${src_pdf}" "${ASSETS}/pdfs/${pdf_name}"
  local rel; rel="$(python3 -c "import os; print(os.path.relpath('${ASSETS}/pdfs/${pdf_name}', '$(dirname "${md_out}")'))")"
  # Try to extract text body via pandoc (may fail for image-only PDFs)
  local body=""
  if body="$(pandoc --from=pdf --to=gfm --wrap=none "${src_pdf}" 2>/dev/null)" && [[ -n "${body}" ]]; then
    cat > "${md_out}" <<EOF
# ${title}

[:material-file-pdf-box: Download original PDF](${rel}){ .md-button }

---

${body}
EOF
  else
    cat > "${md_out}" <<EOF
# ${title}

The original document is a PDF. Download it below.

[:material-file-pdf-box: Download PDF](${rel}){ .md-button .md-button--primary }
EOF
  fi
}

copy_pdf_with_wrapper "${SAM_SRC}/car_template_quickstart.pdf"        "${SAM_OUT}/car-quickstart.md"        "CAR Template Quickstart"
copy_pdf_with_wrapper "${SAM_SRC}/car_template_walkthrough.pdf"       "${SAM_OUT}/car-walkthrough.md"       "CAR Template Walkthrough"
copy_pdf_with_wrapper "${SAM_SRC}/collector_template_quickstart.pdf"  "${SAM_OUT}/collector-quickstart.md"  "Collector Template Quickstart"
copy_pdf_with_wrapper "${SAM_SRC}/collector_template_walkthrough.pdf" "${SAM_OUT}/collector-walkthrough.md" "Collector Template Walkthrough"
copy_pdf_with_wrapper "${SRC}/other_docs_ai_gen/sam_templates_next_steps_checklist.pdf" "${SAM_OUT}/next-steps-checklist.md" "Next Steps Checklist"

# Wrap annotated YAMLs in fenced code blocks
yaml_to_md() {
  local src_yaml="$1" md_out="$2" title="$3"
  {
    printf '# %s\n\n' "${title}"
    printf 'Source: `%s`\n\n' "$(basename "${src_yaml}")"
    printf '```yaml\n'
    cat "${src_yaml}"
    printf '\n```\n'
  } > "${md_out}"
}

yaml_to_md "${SAM_SRC}/template-car_annotated.yaml"       "${SAM_OUT}/template-car-annotated.md"       "Annotated CAR Template"
yaml_to_md "${SAM_SRC}/template-collector_annotated.yaml" "${SAM_OUT}/template-collector-annotated.md" "Annotated Collector Template"

# SAM section index page
cat > "${SAM_OUT}/index.md" <<'EOF'
# SAM Templates

This section contains AWS SAM template documentation for both the CAR and
Collector services, plus the original annotated template YAML files.

## Quickstarts

- [CAR Quickstart](car-quickstart.md)
- [Collector Quickstart](collector-quickstart.md)

## Walkthroughs

- [CAR Walkthrough](car-walkthrough.md)
- [Collector Walkthrough](collector-walkthrough.md)

## Reference

- [Next Steps Checklist](next-steps-checklist.md)
- [Annotated CAR Template (YAML)](template-car-annotated.md)
- [Annotated Collector Template (YAML)](template-collector-annotated.md)
EOF

# ------------------------------------------------------------
# AI-generated docs packages
# ------------------------------------------------------------
echo "Building AI-generated section..."
AI_OUT="${DOCS}/ai-generated"

build_ai_package() {
  local pkg_dir="$1" md_out="$2" title="$3"
  local md_dir; md_dir="$(dirname "${md_out}")"
  {
    printf '# %s\n\n' "${title}"
    # Include the package's README (.md preferred, falls back to .txt)
    local readme=""
    for cand in "${pkg_dir}"/README*.md "${pkg_dir}"/README*.txt; do
      [[ -f "${cand}" ]] && { readme="${cand}"; break; }
    done
    if [[ -n "${readme}" ]]; then
      printf '## README\n\n'
      cat "${readme}"
      printf '\n\n'
    fi
    # Embed any architecture diagram images (PNG)
    local img_subdir="ai-generated/$(basename "${pkg_dir}")"
    local img_dir="${ASSETS}/images/${img_subdir}"
    mkdir -p "${img_dir}"
    for png in "${pkg_dir}"/*.png; do
      [[ -f "${png}" ]] || continue
      local name; name="$(basename "${png}")"
      cp "${png}" "${img_dir}/${name}"
      local rel; rel="$(python3 -c "import os; print(os.path.relpath('${img_dir}/${name}', '${md_dir}'))")"
      printf '## Architecture Diagram\n\n![%s](%s)\n\n' "${name}" "${rel}"
    done
    # Embed any PDF diagrams as download links
    for pdf in "${pkg_dir}"/*.pdf; do
      [[ -f "${pdf}" ]] || continue
      local name; name="$(basename "${pdf}")"
      cp "${pdf}" "${ASSETS}/pdfs/${name}"
      local rel; rel="$(python3 -c "import os; print(os.path.relpath('${ASSETS}/pdfs/${name}', '${md_dir}'))")"
      printf '## %s\n\n[:material-file-pdf-box: Download PDF](%s){ .md-button }\n\n' "${name}" "${rel}"
    done
    # Embed YAMLs as fenced code blocks
    for yaml in "${pkg_dir}"/*.yaml; do
      [[ -f "${yaml}" ]] || continue
      local name; name="$(basename "${yaml}")"
      printf '## `%s`\n\n```yaml\n' "${name}"
      cat "${yaml}"
      printf '\n```\n\n'
    done
  } > "${md_out}"
}

build_ai_package "${SRC}/other_docs_ai_gen/car_docs_package"       "${AI_OUT}/car.md"       "CAR Service AI-Generated Package"
build_ai_package "${SRC}/other_docs_ai_gen/collector_docs_package" "${AI_OUT}/collector.md" "Collector Service AI-Generated Package"

# AI-generated section index
cat > "${AI_OUT}/index.md" <<'EOF'
# AI-Generated Packages

Auto-generated documentation packages bundled with the SAM templates,
covering the CAR and Collector services.

- [CAR Package](car.md)
- [Collector Package](collector.md)
EOF

# ------------------------------------------------------------
echo "Done. docs/ contents:"
find "${DOCS}" -type f | sort | sed "s|${DOCS}/|  |"
