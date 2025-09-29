// blueprint.cue — fixed version (no interpolation inside triple quotes)

package repo

import "strings"

// Types come from schema.cue (same package)

// ---- Repo configuration (edit these) ----

Blueprint: {
  repo: {
    name:        "awesome-repo"
    description: "Single-source-of-truth for GitHub meta via CUE"
    visibility:  "public"
    license:     "MIT"
  }

  owners: [
    { path: "/",     owners: ["@org/platform", "@your-user"] },
    { path: "/api",  owners: ["@org/backend"] },
    { path: "/web",  owners: ["@org/frontend"] },
  ]

  labels: [
    { name: "type:bug",          color: "d73a4a", desc: "Something isn't working" },
    { name: "type:feature",      color: "a2eeef", desc: "New feature or request" },
    { name: "prio:high",         color: "b60205", desc: "Needs attention soon" },
    { name: "good first issue",  color: "7057ff", desc: "Good for newcomers" },
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

// ---- Helpers (pure string building; no triple-quote interpolation) ----

NL: string = "\n"

codeownersLines: [ for o in Blueprint.owners {
  // "/path owner1 owner2"
  o.path + " " + strings.Join(o.owners, " ")
}]

labelsLines: [
  for l in Blueprint.labels {
    "- name: " + l.name + NL +
    "  color: " + l.color + NL +
    "  description: " + (if l.desc != _|_ { l.desc } else { "" })
  }
]

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
  "      placeholder: What's the feature and why?" + NL +
  "    validations:" + NL +
  "      required: true" + NL
}

// Dynamic part of CI setup step based on language
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
    "          run: echo \"Extend CI generation for language: " + Blueprint.workflow.ci.language + "\""+ NL
  }
}

// Optional cache step
cacheStep: string = if Blueprint.workflow.cache {
  "        - uses: actions/cache@v4" + NL +
  "          with:" + NL +
  "            path: |" + NL +
  "              node_modules" + NL +
  "              ~/.cache/pip" + NL +
  "            key: ${{ runner.os }}-${{ matrix.version }}-${{ hashFiles('**/lock*', '**/package-lock.json', '**/poetry.lock') }}" + NL
} else { "" }

// Optional lint step
lintStep: string = if Blueprint.workflow.lint {
  "        - name: Lint" + NL +
  "          run: |" + NL +
  "            if command -v npm >/dev/null 2>&1; then npm run -s lint || echo \"no lint script\"; " + NL +
  "            elif command -v pip >/dev/null 2>&1; then echo \"add flake8/ruff here\"; " + NL +
  "            else echo \"no linter configured\"; fi" + NL
} else { "" }

// Optional test step
testStep: string = if Blueprint.workflow.test {
  "        - name: Test" + NL +
  "          run: |" + NL +
  "            if command -v npm >/dev/null 2>&1; then npm test --silent || echo \"no test script\"; " + NL +
  "            elif command -v pytest >/dev/null 2>&1; then pytest -q; " + NL +
  "            else echo \"add tests here\"; fi" + NL
} else { "" }

// CI workflow YAML lines joined (no interpolation in triple quotes)
ciYamlLines: [
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
] + [langSetupStep, cacheStep, lintStep, testStep]

// ---- Rendered outputs consumed by generate.cue ----

Rendered: {
  CODEOWNERS: strings.Join(codeownersLines, NL) + NL
  LabelsYAML: strings.Join(labelsLines, NL) + NL
  BugTemplate: bugTemplateYAML
  FeatureTemplate: featureTemplateYAML
  CIYml: strings.Join(ciYamlLines, NL) + NL
}
