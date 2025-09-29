// generate.cue — produce a JSON map: { "path": "content", ... }

package repo

// Import the Rendered content from blueprint.cue
// Then map paths to contents.
files: {
  "CODEOWNERS":            Rendered.CODEOWNERS
  ".github/labels.yml":    Rendered.LabelsYAML
  ".github/workflows/ci.yml": Rendered.CIYml
  ".github/ISSUE_TEMPLATE/bug.yml":     Rendered.BugTemplate
  ".github/ISSUE_TEMPLATE/feature.yml": Rendered.FeatureTemplate
}
