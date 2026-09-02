[CmdletBinding()]
param(
    [string]$ProjectPath = (Get-Location).Path
)

$resolvedProject = (Resolve-Path -LiteralPath $ProjectPath -ErrorAction Stop).Path
$gitCommand = Get-Command git -ErrorAction SilentlyContinue
$mode = 'no-git'
$remote = $null

if ($gitCommand) {
    $inside = (& $gitCommand.Source -C $resolvedProject rev-parse --is-inside-work-tree 2>$null)
    if ($LASTEXITCODE -eq 0 -and ($inside -join '').Trim() -eq 'true') {
        $remote = (& $gitCommand.Source -C $resolvedProject remote get-url origin 2>$null | Select-Object -First 1)
        if ($LASTEXITCODE -eq 0 -and $remote) {
            $remote = $remote.Trim()
            $mode = if ($remote -match '(?i)(github\.com)') { 'github-remote-candidate' } else { 'local-git-with-remote' }
        } else {
            $mode = 'local-git'
        }
    }
}

[pscustomobject]@{
    project_path = $resolvedProject
    mode = $mode
    origin = $remote
    github_connector_required = ($mode -eq 'github-remote-candidate')
    note = 'github-remote-candidate still requires an accessible committed snapshot and GitHub Connector; otherwise use gpt-web text handoff.'
} | ConvertTo-Json -Compress
