# gen.ps1 — write files from CUE 'files' map (Windows PowerShell)
param()

$ErrorActionPreference = "Stop"

$Tmp = New-TemporaryFile
cue export generate.cue -e files | Out-File -FilePath $Tmp -Encoding utf8

# Try jq first, fallback to PowerShell JSON
if (Get-Command jq -ErrorAction SilentlyContinue) {
  $keys = jq -r 'keys[]' $Tmp
  foreach ($k in $keys) {
    $content = jq -r --arg k $k '.[$k]' $Tmp
    $dir = Split-Path $k
    if ($dir -and $dir -ne ".") { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($k, $content, [System.Text.Encoding]::UTF8)
    Write-Host "wrote $k"
  }
}
else {
  $json = Get-Content $Tmp -Raw | ConvertFrom-Json
  foreach ($prop in $json.PSObject.Properties) {
    $path = $prop.Name
    $content = [string]$prop.Value
    $dir = Split-Path $path
    if ($dir -and $dir -ne ".") { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, [System.Text.Encoding]::UTF8)
    Write-Host "wrote $path"
  }
}
