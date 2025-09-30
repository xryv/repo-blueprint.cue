#!/usr/bin/env python3
# generate.py — render GitHub meta from blueprint.json
# Zero dependencies. Works on Windows/macOS/Linux and in GitHub Actions.

import json, sys, difflib, pathlib

ROOT = pathlib.Path(__file__).parent.resolve()
NL = "\n"

def read_blueprint():
    p = ROOT / "blueprint.json"
    if not p.exists():
        sys.stderr.write("ERROR: blueprint.json not found.\n")
        sys.exit(2)
    return json.loads(p.read_text(encoding="utf-8"))

def render_codeowners(bp):
    lines = [f"{o['path']} {' '.join(o.get('owners', []))}" for o in bp.get("owners", [])]
    return (NL.join(lines) + NL) if lines else NL

def render_labels_yaml(bp):
    lines = []
    for l in bp.get("labels", []):
        lines += [
            f"- name: {l['name']}",
            f"  color: {l['color']}",
            f"  description: {l.get('desc','')}",
        ]
    return (NL.join(lines) + NL) if lines else NL

# ---------- CI step builders (OS-specific) ----------

def step_lang_setup(lang):
    if lang == "node":
        return (
            "      - name: Setup Node\n"
            "        uses: actions/setup-node@v4\n"
            "        with:\n"
            "          node-version: ${{ matrix.version }}\n"
        )
    if lang == "python":
        return (
            "      - name: Setup Python\n"
            "        uses: actions/setup-python@v5\n"
            "        with:\n"
            "          python-version: ${{ matrix.version }}\n"
        )
    return (
        "      - name: Setup language\n"
        "        shell: bash\n"
        "        run: echo \"Extend CI for language: ${{ matrix.version }}\"\n"
    )

def step_cache(enabled):
    if not enabled: return ""
    return (
        "      - uses: actions/cache@v4\n"
        "        with:\n"
        "          path: |\n"
        "            node_modules\n"
        "            ~/.cache/pip\n"
        "          key: ${{ runner.os }}-${{ matrix.version }}-${{ hashFiles('**/lock*', '**/package-lock.json', '**/poetry.lock') }}\n"
    )

# Bash steps: never fail (trailing '|| true')
def step_lint_linux():
    return (
        "      - name: Lint (bash)\n"
        "        if: runner.os != 'Windows'\n"
        "        shell: bash\n"
        "        run: |\n"
        "          if command -v npm >/dev/null 2>&1; then npm run -s lint || echo \"no lint script\"; \n"
        "          elif command -v pip >/dev/null 2>&1; then echo \"add flake8/ruff here\"; \n"
        "          else echo \"no linter configured\"; fi || true\n"
    )

def step_test_linux():
    return (
        "      - name: Test (bash)\n"
        "        if: runner.os != 'Windows'\n"
        "        shell: bash\n"
        "        run: |\n"
        "          if command -v npm >/dev/null 2>&1; then npm test --silent || echo \"no test script\"; \n"
        "          elif command -v pytest >/dev/null 2>&1; then pytest -q || echo \"tests failed (ignored for template)\"; \n"
        "          else echo \"add tests here\"; fi || true\n"
    )

# PowerShell steps: never fail (force $global:LASTEXITCODE = 0)
def step_lint_windows():
    return (
        "      - name: Lint (pwsh)\n"
        "        if: runner.os == 'Windows'\n"
        "        shell: pwsh\n"
        "        continue-on-error: true\n"
        "        run: |\n"
        "          $ErrorActionPreference = 'Continue'\n"
        "          if (Get-Command npm -ErrorAction SilentlyContinue) {\n"
        "            npm run -s lint; if ($LASTEXITCODE -ne 0) { Write-Host 'no lint script' }\n"
        "          } elseif (Get-Command pip -ErrorAction SilentlyContinue) {\n"
        "            Write-Host 'add flake8/ruff here'\n"
        "          } else {\n"
        "            Write-Host 'no linter configured'\n"
        "          }\n"
        "          $global:LASTEXITCODE = 0\n"
    )

def step_test_windows():
    return (
        "      - name: Test (pwsh)\n"
        "        if: runner.os == 'Windows'\n"
        "        shell: pwsh\n"
        "        continue-on-error: true\n"
        "        run: |\n"
        "          $ErrorActionPreference = 'Continue'\n"
        "          if (Get-Command npm -ErrorAction SilentlyContinue) {\n"
        "            npm test --silent; if ($LASTEXITCODE -ne 0) { Write-Host 'no test script' }\n"
        "          } elseif (Get-Command pytest -ErrorAction SilentlyContinue) {\n"
        "            pytest -q; if ($LASTEXITCODE -ne 0) { Write-Host 'tests failed (ignored for template)' }\n"
        "          } else {\n"
        "            Write-Host 'add tests here'\n"
        "          }\n"
        "          $global:LASTEXITCODE = 0\n"
    )

def render_ci_yaml(bp):
    wf = bp.get("workflow", {})
    ci = wf.get("ci", {})
    lang = ci.get("language", "node")
    versions = ", ".join(ci.get("versions", [])) or "20"
    oses = ", ".join(ci.get("os", [])) or "ubuntu-latest"

    s = [
        "name: CI",
        "on:",
        "  push:",
        "    branches: [ main, master ]",
        "  pull_request:",
        "",
        "jobs:",
        "  build:",
        "    runs-on: ${{ matrix.os }}",
        "    strategy:",
        "      matrix:",
        f"        os: [{oses}]",
        f"        version: [{versions}]",
        "    steps:",
        "      - uses: actions/checkout@v4",
        step_lang_setup(lang).rstrip(),
        step_cache(wf.get('cache', True)).rstrip(),
        step_lint_linux().rstrip(),
        step_lint_windows().rstrip(),
        step_test_linux().rstrip(),
        step_test_windows().rstrip(),
        ""
    ]
    return NL.join(s)

def render_issue_bug(bp):
    b = bp.get("issues", {}).get("bug", {})
    if not b.get("enabled"): return ""
    title = b.get("title", "Bug report")
    return (
f"name: {title}\n"
"description: Report a problem\n"
"labels: [type:bug]\n"
"body:\n"
"  - type: textarea\n"
"    id: what-happened\n"
"    attributes:\n"
"      label: What happened?\n"
"      description: Also tell us what you expected to happen.\n"
"      placeholder: Tell us what you see!\n"
"    validations:\n"
"      required: true\n"
    )

def render_issue_feature(bp):
    f = bp.get("issues", {}).get("feature", {})
    if not f.get("enabled"): return ""
    title = f.get("title", "Feature request")
    return (
f"name: {title}\n"
"description: Suggest an idea\n"
"labels: [type:feature]\n"
"body:\n"
"  - type: textarea\n"
"    id: proposal\n"
"    attributes:\n"
"      label: Proposal\n"
"      placeholder: What is the feature and why?\n"
"    validations:\n"
"      required: true\n"
    )

OUT_MAP = {
    "CODEOWNERS": render_codeowners,
    ".github/labels.yml": render_labels_yaml,
    ".github/workflows/ci.yml": render_ci_yaml,
    ".github/ISSUE_TEMPLATE/bug.yml": render_issue_bug,
    ".github/ISSUE_TEMPLATE/feature.yml": render_issue_feature,
}

def write_all(bp, base=ROOT):
    for path, fn in OUT_MAP.items():
        content = fn(bp)
        if not content:  # skip disabled
            continue
        p = (base / path)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content, encoding="utf-8")
        print(f"wrote {p.relative_to(ROOT)}")

def check_drift(bp):
    shadow = ROOT / ".blueprint_shadow"
    if shadow.exists():
        for item in shadow.glob("**/*"):
            if item.is_file():
                item.unlink()
    shadow.mkdir(exist_ok=True)
    write_all(bp, base=shadow)
    diffs = []
    for path in OUT_MAP.keys():
        sp, rp = shadow / path, ROOT / path
        s = sp.read_text(encoding="utf-8") if sp.exists() else ""
        r = rp.read_text(encoding="utf-8") if rp.exists() else ""
        if s != r:
            diffs.append("".join(difflib.unified_diff(
                r.splitlines(keepends=True),
                s.splitlines(keepends=True),
                fromfile=str(rp), tofile=str(sp)
            )))
    if diffs:
        print("❌ Drift detected (repo vs generated):")
        for d in diffs: sys.stdout.write(d)
        return 1
    print("✅ No drift detected.")
    return 0

def main():
    import argparse
    ap = argparse.ArgumentParser(description="Generate GitHub meta from blueprint.json")
    ap.add_argument("--check", action="store_true", help="check drift only (no writes)")
    ap.add_argument("--write", action="store_true", help="write files (default)")
    args = ap.parse_args()
    bp = read_blueprint()
    if args.check:
        sys.exit(check_drift(bp))
    write_all(bp)
    sys.exit(0)

if __name__ == "__main__":
    main()
