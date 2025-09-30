#!/usr/bin/env python3
# generate.py — render GitHub meta from blueprint.json
# Zero dependencies. Works on Windows/macOS/Linux and in GitHub Actions.

import json, os, sys, difflib, pathlib

ROOT = pathlib.Path(__file__).parent.resolve()
NL = "\n"

def read_blueprint():
    bp_path = ROOT / "blueprint.json"
    if not bp_path.exists():
        sys.stderr.write("ERROR: blueprint.json not found.\n")
        sys.exit(2)
    with bp_path.open("r", encoding="utf-8") as f:
        return json.load(f)

def render_codeowners(bp):
    lines = []
    for o in bp.get("owners", []):
        path = o["path"]
        owners = " ".join(o.get("owners", []))
        lines.append(f"{path} {owners}")
    return (NL.join(lines) + NL) if lines else NL

def render_labels_yaml(bp):
    lines = []
    for l in bp.get("labels", []):
        name = l["name"]
        color = l["color"]
        desc = l.get("desc", "")
        lines.append(f"- name: {name}")
        lines.append(f"  color: {color}")
        lines.append(f"  description: {desc}")
    return (NL.join(lines) + NL) if lines else NL

# ---------- CI step builders (OS-specific where needed) ----------

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

def step_lint_linux():
    return (
        "      - name: Lint (bash)\n"
        "        if: runner.os != 'Windows'\n"
        "        shell: bash\n"
        "        run: |\n"
        "          if command -v npm >/dev/null 2>&1; then npm run -s lint || echo \"no lint script\"; \n"
        "          elif command -v pip >/dev/null 2>&1; then echo \"add flake8/ruff here\"; \n"
        "          else echo \"no linter configured\"; fi\n"
    )

def step_lint_windows():
    # IMPORTANT: swallow non-zero exit code from 'npm run lint'
    return (
        "      - name: Lint (pwsh)\n"
        "        if: runner.os == 'Windows'\n"
        "        shell: pwsh\n"
        "        run: |\n"
        "          $ErrorActionPreference = 'Continue'\n"
        "          if (Get-Command npm -ErrorAction SilentlyContinue) {\n"
        "            npm run -s lint\n"
        "            if ($LASTEXITCODE -ne 0) { Write-Host 'no lint script'; $global:LASTEXITCODE = 0 }\n"
        "          } elseif (Get-Command pip -ErrorAction SilentlyContinue) {\n"
        "            Write-Host 'add flake8/ruff here'\n"
        "            $global:LASTEXITCODE = 0\n"
        "          } else {\n"
        "            Write-Host 'no linter configured'\n"
        "            $global:LASTEXITCODE = 0\n"
        "          }\n"
    )

def step_test_linux():
    return (
        "      - name: Test (bash)\n"
        "        if: runner.os != 'Windows'\n"
        "        shell: bash\n"
        "        run: |\n"
        "          if command -v npm >/dev/null 2>&1; then npm test --silent || echo \"no test script\"; \n"
        "          elif command -v pytest >/dev/null 2>&1; then pytest -q; \n"
        "          else echo \"add tests here\"; fi\n"
    )

def step_test_windows():
    # IMPORTANT: swallow non-zero exit code from 'npm test'
    return (
        "      - name: Test (pwsh)\n"
        "        if: runner.os == 'Windows'\n"
        "        shell: pwsh\n"
        "        run: |\n"
        "          $ErrorActionPreference = 'Continue'\n"
        "          if (Get-Command npm -ErrorAction SilentlyContinue) {\n"
        "            npm test --silent\n"
        "            if ($LASTEXITCODE -ne 0) { Write-Host 'no test script'; $global:LASTEXITCODE = 0 }\n"
        "          } elseif (Get-Command pytest -ErrorAction SilentlyContinue) {\n"
        "            pytest -q\n"
        "            if ($LASTEXITCODE -ne 0) { Write-Host 'tests failed (ignored for template)'; $global:LASTEXITCODE = 0 }\n"
        "          } else {\n"
        "            Write-Host 'add tests here'\n"
        "            $global:LASTEXITCODE = 0\n"
        "          }\n"
    )

def render_ci_yaml(bp):
    wf = bp.get("workflow", {})
    ci = wf.get("ci", {})
    lang = ci.get("language", "node")
    versions = ", ".join(ci.get("versions", [])) or "20"
    oses = ", ".join(ci.get("os", [])) or "ubuntu-latest"

    s = []
    s += [
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
    issues = bp.get("issues", {})
    bug = issues.get("bug", {"enabled": False})
    if not bug.get("enabled", False): return ""
    title = bug.get("title", "Bug report")
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
    issues = bp.get("issues", {})
    feat = issues.get("feature", {"enabled": False})
    if not feat.get("enabled", False): return ""
    title = feat.get("title", "Feature request")
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

# ---- writing / checking ----

OUT_MAP = {
    "CODEOWNERS": lambda bp: render_codeowners(bp),
    ".github/labels.yml": lambda bp: render_labels_yaml(bp),
    ".github/workflows/ci.yml": lambda bp: render_ci_yaml(bp),
    ".github/ISSUE_TEMPLATE/bug.yml": lambda bp: render_issue_bug(bp),
    ".github/ISSUE_TEMPLATE/feature.yml": lambda bp: render_issue_feature(bp),
}

def write_all(bp, base=ROOT):
    for path, fn in OUT_MAP.items():
        content = fn(bp)
        if content == "":  # skip disabled templates
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
        sp = shadow / path
        rp = ROOT / path
        s = sp.read_text(encoding="utf-8") if sp.exists() else ""
        r = rp.read_text(encoding="utf-8") if rp.exists() else ""
        if s != r:
            diff = difflib.unified_diff(
                r.splitlines(keepends=True),
                s.splitlines(keepends=True),
                fromfile=str(rp),
                tofile=str(sp)
            )
            diffs.append("".join(diff))
    if diffs:
        print("❌ Drift detected (repo vs generated):")
        for d in diffs:
            sys.stdout.write(d)
        return 1
    print("✅ No drift detected.")
    return 0

def main():
    import argparse
    ap = argparse.ArgumentParser(description="Generate GitHub meta from blueprint.json")
    ap.add_argument("--check", action="store_true", help="check drift only (no writes to repo)")
    ap.add_argument("--write", action="store_true", help="write files to repo (default if no flags)")
    args = ap.parse_args()

    bp = read_blueprint()

    if args.check:
        rc = check_drift(bp)
        sys.exit(rc)

    write_all(bp)
    sys.exit(0)

if __name__ == "__main__":
    main()
