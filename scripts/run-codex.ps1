[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SpecFile,

    [Parameter(Mandatory = $true)]
    [string]$SummaryFile,

    [string]$WorkDir = (Get-Location).Path,

    [ValidateSet("read-only", "workspace-write", "danger-full-access")]
    [string]$Sandbox = "workspace-write",

    [string]$Model = "",

    [ValidateSet("", "minimal", "low", "medium", "high", "xhigh", "max", "ultra")]
    [string]$ReasoningEffort = "",

    [switch]$ResumeLast,

    [switch]$SkipGitCheck,

    [string[]]$Image = @()
)

$ErrorActionPreference = "Stop"

# Ensure clean UTF-8 (no BOM) for both stdin piping to native binaries and console output
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = $utf8NoBom
[Console]::InputEncoding  = $utf8NoBom
[Console]::OutputEncoding = $utf8NoBom

# 1. Resolve Codex CLI executable
$codexExe = $null
$cmd = Get-Command codex -ErrorAction SilentlyContinue
if ($cmd) {
    $codexExe = $cmd.Source
}
if (-not $codexExe) {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\OpenAI\Codex\bin\codex.exe"),
        (Join-Path $HOME ".codex\packages\standalone\current\bin\codex.exe"),
        (Join-Path $env:APPDATA "npm\codex.cmd")
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            $codexExe = $candidate
            break
        }
    }
}
if (-not $codexExe) {
    Write-Error "[CODEX-WORKER] Could not locate codex executable. Ensure OpenAI Codex CLI is installed."
    exit 127
}

# 2. Validate paths and ensure output directory exists
$WorkDir     = [System.IO.Path]::GetFullPath($WorkDir)
$SpecFile    = [System.IO.Path]::GetFullPath($SpecFile)
$SummaryFile = [System.IO.Path]::GetFullPath($SummaryFile)

if (-not (Test-Path -LiteralPath $WorkDir -PathType Container)) {
    Write-Error "[CODEX-WORKER] WorkDir does not exist: $WorkDir"
    exit 2
}
if (-not (Test-Path -LiteralPath $SpecFile -PathType Leaf)) {
    Write-Error "[CODEX-WORKER] SpecFile does not exist: $SpecFile"
    exit 2
}

$summaryDir = Split-Path -Parent $SummaryFile
if ($summaryDir -and -not (Test-Path -LiteralPath $summaryDir)) {
    New-Item -ItemType Directory -Path $summaryDir -Force | Out-Null
}

# Remove stale summary file from any prior run so we never read outdated output on failure
if (Test-Path -LiteralPath $SummaryFile) {
    Remove-Item -LiteralPath $SummaryFile -Force
}

# 3. Auto-register .codex-tasks/ in local .git/info/exclude so task files never dirty git status
$gitDir = Join-Path $WorkDir ".git"
if (Test-Path -LiteralPath $gitDir -PathType Container) {
    $excludeFile = Join-Path $gitDir "info\exclude"
    if (Test-Path -LiteralPath $excludeFile -PathType Leaf) {
        $existing = Get-Content -LiteralPath $excludeFile -Encoding UTF8 -ErrorAction SilentlyContinue
        if ($existing -notcontains ".codex-tasks/") {
            Add-Content -LiteralPath $excludeFile -Value "`n# Antigravity codex-worker task artifacts`n.codex-tasks/" -Encoding UTF8
        }
    }
}

# 4. Build codex exec argument list
$codexArgs = @(
    "exec",
    "--cd", $WorkDir,
    "--sandbox", $Sandbox,
    "--color", "never"
)

if ($ResumeLast) {
    $codexArgs += @("resume", "--last")
}

if ($SkipGitCheck) {
    $codexArgs += "--skip-git-repo-check"
}
if ($Model -ne "") {
    $codexArgs += @("--model", $Model)
}
if ($ReasoningEffort -ne "") {
    $codexArgs += @("-c", "model_reasoning_effort=`"$ReasoningEffort`"")
}
foreach ($img in $Image) {
    if ($img) {
        $codexArgs += @("--image", ([System.IO.Path]::GetFullPath($img)))
    }
}

$codexArgs += @("--output-last-message", $SummaryFile, "-")

$specContent = Get-Content -LiteralPath $SpecFile -Raw -Encoding UTF8
if ([string]::IsNullOrWhiteSpace($specContent)) {
    Write-Error "[CODEX-WORKER] SpecFile is empty: $SpecFile"
    exit 2
}

Write-Host "[CODEX-WORKER] Binary  : $codexExe"
Write-Host "[CODEX-WORKER] WorkDir : $WorkDir"
Write-Host "[CODEX-WORKER] Sandbox : $Sandbox | ResumeLast: $ResumeLast | Model: $(if ($Model) { $Model } else { '(default)' }) | Effort: $(if ($ReasoningEffort) { $ReasoningEffort } else { '(default)' })"
Write-Host "[CODEX-WORKER] Spec    : $SpecFile"
Write-Host "[CODEX-WORKER] Summary : $SummaryFile"
Write-Host "------------------------------------------------------------"

Push-Location -LiteralPath $WorkDir
try {
    $specContent | & $codexExe @codexArgs
    $exitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}

Write-Host "------------------------------------------------------------"
if ($exitCode -ne 0) {
    Write-Error "[CODEX-WORKER] Codex exited with non-zero code: $exitCode"
    exit $exitCode
}

if (-not (Test-Path -LiteralPath $SummaryFile -PathType Leaf)) {
    Write-Warning "[CODEX-WORKER] Codex exited 0, but SummaryFile was not created at: $SummaryFile"
} else {
    Write-Host "[CODEX-WORKER] Completed successfully. Final summary saved to: $SummaryFile"
}
exit 0
