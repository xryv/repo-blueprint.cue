// blueprint.cue — your repo config (edit this)

package repo

import "strings"

// Pull in types
// (Same package, so types are visible from schema.cue)

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

// Helper for CODEOWNERS line rendering
ownerLine: o: string = "\(o.path) \(strings.Join(o.owners, " "))"

// Rendered content (consumed by generate.cue)
Rendered: {
  CODEOWNERS: string & strings.Join([ for o in Blueprint.owners { ownerLine: o } ], "\n") + "\n"

  LabelsYAML: """
  - name: \(Blueprint.labels[0].name)
    color: \(Blueprint.labels[0].color)
    description: \(Blueprint.labels[0].desc)
  \(for l in Blueprint.labels[1:] { """
  - name: \(l.name)
    color: \(l.color)
    description: \(l.desc)
  """ })
  """

  BugTemplate: if Blueprint.issues.bug.enabled {
    """
    name: \(Blueprint.issues.bug.title)
    description: Report a problem
    labels: [type:bug]
    body:
      - type: textarea
        id: what-happened
        attributes:
          label: What happened?
          description: Also tell us what you expected to happen.
          placeholder: Tell us what you see!
        validations:
          required: true
    """
  }

  FeatureTemplate: if Blueprint.issues.feature.enabled {
    """
    name: \(Blueprint.issues.feature.title)
    description: Suggest an idea
    labels: [type:feature]
    body:
      - type: textarea
        id: proposal
        attributes:
          label: Proposal
          placeholder: What's the feature and why?
        validations:
          required: true
    """
  }

  CIYml: """
  name: CI
  on:
    push:
      branches: [ main, master ]
    pull_request:

  jobs:
    build:
      runs-on: \(_os)
      strategy:
        matrix:
          os: [\(strings.Join(Blueprint.workflow.ci.os, ", "))]
          version: [\(strings.Join(Blueprint.workflow.ci.versions, ", "))]
      steps:
        - uses: actions/checkout@v4
        - name: Setup \(Blueprint.workflow.ci.language)
          \(if Blueprint.workflow.ci.language == "node" {
            """
            uses: actions/setup-node@v4
            with:
              node-version: \${{ matrix.version }}
            """
          } else if Blueprint.workflow.ci.language == "python" {
            """
            uses: actions/setup-python@v5
            with:
              python-version: \${{ matrix.version }}
            """
          } else {
            """
            run: echo "Please extend generate for your language"
            """
          })
        \(if Blueprint.workflow.cache {
          """
        - uses: actions/cache@v4
          with:
            path: |
              node_modules
              ~/.cache/pip
            key: \${{ runner.os }}-\${{ matrix.version }}-\${{ hashFiles('**/lock*', '**/package-lock.json', '**/poetry.lock') }}
          """
        })
        \(if Blueprint.workflow.lint {
          """
        - name: Lint
          run: |
            if command -v npm 2>/dev/null; then npm run -s lint || echo "no lint script"
            elif command -v pip 2>/dev/null; then echo "add flake8/ruff here"
            fi
          """
        })
        \(if Blueprint.workflow.test {
          """
        - name: Test
          run: |
            if command -v npm 2>/dev/null; then npm test --silent || echo "no test script"
            elif command -v pytest 2>/dev/null; then pytest -q
            else echo "add tests here"
            fi
          """
        })
  """
}
