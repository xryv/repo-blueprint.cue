// generate.cue — map output paths to rendered strings

package repo

files: {
  "CODEOWNERS":                             Rendered.CODEOWNERS
  ".github/labels.yml":                     Rendered.LabelsYAML
  ".github/workflows/ci.yml":               Rendered.CIYml
  ".github/ISSUE_TEMPLATE/bug.yml":         Rendered.BugTemplate
  ".github/ISSUE_TEMPLATE/feature.yml":     Rendered.FeatureTemplate
}
