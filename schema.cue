// schema.cue — types + defaults for the blueprint

package repo

// Basic repo identity
Repo: {
  name:        string
  description: string
  visibility:  *"public" | "private"
  license:     *"MIT" | "Apache-2.0" | "GPL-3.0" | string
}

// Code owners per path
Owner: {
  path:   string // e.g. "/" or "/api"
  owners: [...string] // e.g. ["@org/team", "@user"]
}

// Labels
Label: {
  name:  string
  color: =~"^[0-9a-fA-F]{6}$" // hex without '#'
  desc?: string
}

// Workflows
Matrix: {
  language: *"node" | "python" | "go" | "rust" | "dotnet"
  versions: [...string] // e.g. ["20", "22"] or ["3.11","3.12"]
  os:       [...string] // e.g. ["ubuntu-latest","windows-latest","macos-latest"]
}

Workflow: {
  ci: Matrix
  cache: *true | false
  lint:  *true | false
  test:  *true | false
}

// Issue templates
IssueTemplates: {
  bug: {
    enabled: *true | false
    title:   *"Bug report"
  }
  feature: {
    enabled: *true | false
    title:   *"Feature request"
  }
}

// The top-level blueprint
Blueprint: {
  repo: Repo
  owners: [...Owner]
  labels: [...Label]
  workflow: Workflow
  issues: IssueTemplates
}
