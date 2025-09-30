// blueprint.cue — stable version for CI

package repo

import "strings"

// ---- Repo configuration (edit these) ----

Blueprint: {
  repo: {
    name:        "awesome-repo"
    description: "Single-source-of-truth for GitHub meta via CUE"
    visibility:  "public"
    license:     "MIT"
  }

  owners: [
    { path: "/",    owners: ["@org/platform", "@your-user"] },
    { path: "/api", owners: ["@org/backend"] },
    { path: "/web", owners: ["@org/frontend"] },
  ]

  // Keep values simple; no apostrophes or special punctuation in desc for now.
  labels: [
    { name: "type:bug",         color: "d73a4a", desc: "Bug report" },
    { name: "type:feature",     color: "a2eeef", desc: "Feature request" },
    { name: "prio:high",        color: "b60205", desc: "High priority" },
    { name: "good first issue", color: "7057ff", desc: "Good for newcomers" },
  ]

  workflow: {
    ci: {
      language: "node"
      versions: ["20", "22"]
      os:       ["ubuntu-latest", "windows-latest"]
    }
    cache: true
    lint:  true
    test:  true
  }

  issues: {
    bug:     { enabled: true,  title: "Bug report" }
    feature: { enabled: true,  title: "Feature request" }
  }
}

// ---- Helpers ----

NL: string = "\n"

// CODEOWNERS: "/path owner1 owner2"
codeownersLines: [ for o in Blueprint.owners {
  o.path + " " + strings.Join(o.owners, " ")
}]

// Labels YAML (desc is optional in schema; here we always set it)
labelsLines: [
  for l in Blueprint.labels {
    "- name: " + l.name + NL +
    "  color: " + l.color + NL +
    "  description: " + (l.desc | "")
  }
]

// Issue templates
bugTemplateYAML: if Blueprint.issues.bug.enabled {
  "name: " + Blueprint.issues.bug.title + NL +
  "description: Report a problem" + NL +
  "labels: [type:bug]" + NL +
  "body:" + NL +
  "  - type: textarea" + NL +
  "    id: what-happened" + NL +
  "    attributes:" + NL +
  "      label: What happened?" + NL +
  "      description: Also tell us what you expected to happen." + NL +
  "      placeholder: Tell us what you see!" + NL +
  "    validations:" + NL +
  "      required: true" + NL
}

featureTemplateYAML: if Blueprint.issues.feature.enabled {
  "name: " + Blueprint.issues.feature.title + NL +
  "description: Suggest an idea" + NL +
  "labels: [type:feature]" + NL +
  "body:" + NL +
  "  - type: textarea" + NL +
  "    id: proposal" + NL +
  "    attributes:" + NL +
  "      label: Proposal" + NL +
  "      placeholder: What is the feature and why?" + NL +
  "    validations:" + NL +
  "      required: true" + NL
}

// Language setup block
langSetupStep: string = {
  if Blueprint.workflow.ci.language == "node" {
    "        - name: Setup Node" + NL +
    "          uses: actions/setup-node@v4" + NL +
    "          with:" + NL +
    "            node-version: ${{ matrix.version }}" + NL
  } else if Blueprint.workflow.ci.language == "python" {
    "        - name: Setup Python" + NL +
    "          uses: actions/setup-python@v5" + NL +
    "          with:" + NL +
    "            python-version: ${{ matrix.version }}" + NL
  } else {
    "        - name: Setup language" + NL +
    "          run: echo \"Extend CI generation for language: " + Blueprint.workflow.ci.language + "\"" + NL
  }
}

// Optional steps
cacheStep: string = if Blueprint.workflow.cache {
  "        - uses: actions/cache@v4" + NL +
  "          with:" + NL +
  "            path: |" + NL +
  "              node_modules" + NL +
  "              ~/.cache/pip" + NL +
  "            key: ${{ runner.os }}-${{ matrix.version }}-${{ hashFiles('**/lock*', '**/package-lock.json', '**/poetry.lock') }}" + NL
} else { "" }

lintStep: string = if Blueprint.workflow.lint {
  "        - name: Lint" + NL +
  "          run: |" + NL +
  "            if command -v npm >/dev/null 2>&1; then npm run -s lint || echo \"no lint script\"; " + NL +
  "            elif command -v pip >/dev/null 2>&1; then echo \"add flake8/ruff here\"; " + NL +
  "            else echo \"no linter configured\"; fi" + NL
} else { "" }

testStep: string = if Blueprint.workflow.test {
  "        - name: Test" + NL +
  "          run: |" + NL +
  "            if command -v npm >/dev/null 2>&1; then npm test --silent || echo \"no test script\"; " + NL +
  "            elif command -v pytest >/dev/null 2>&1; then pytest -q; " + NL +
  "            else echo \"add tests here\"; fi" + NL
} else { "" }

// Base CI lines up to checkout
baseCILines: [
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
  "        os: [" + strings.Join(Blueprint.workflow.ci.os, ", ") + "]",
  "        version: [" + strings.Join(Blueprint.workflow.ci.versions, ", ") + "]",
  "    steps:",
  "      - uses: actions/checkout@v4",
]

// Final CI YAML as one string
ciYAML: strings.Join(baseCILines, NL) + NL +
        langSetupStep + cacheStep + lintStep + testStep

// ---- Rendered outputs for generate.cue ----

Rendered: {
  CODEOWNERS:       strings.Join(codeownersLines, NL) + NL
  LabelsYAML:       strings.Join(labelsLines, NL) + NL
  BugTemplate:      bugTemplateYAML
  FeatureTemplate:  featureTemplateYAML
  CIYml:            ciYAML + NL
}
