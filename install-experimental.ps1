<#
.SYNOPSIS
    PanDev CLI - Beta install bootstrap (PowerShell-native).

.DESCRIPTION
    Single-command install entry point for Windows users who don't have
    Git Bash / WSL / Cygwin available. Mirrors the macOS/Linux
    `curl ... install-experimental.sh | bash` UX but speaks native
    PowerShell so users can copy-paste:

      iwr -useb https://raw.githubusercontent.com/pandev-metriks/homebrew-pandev-cli-beta/main/install-experimental.ps1 | iex

    Steps:
      1. Download the Windows .zip release asset for the templated VERSION.
      2. Verify SHA256 against the value baked in at publish time.
      3. Extract into a temp directory.
      4. Invoke install-pandev.ps1 from the extracted bundle. That script
         self-elevates via UAC, imports the publisher cert into
         LocalMachine\TrustedPeople, and runs Add-AppxPackage.

    Source-of-truth lives in pdm-source/release/install-experimental.ps1.
    The beta release CI workflow copies it into the beta tap repo verbatim
    and replaces the @-tokens below with the actual release version and
    Windows asset checksum.

    Tokens replaced by the publish step (do NOT pre-fill them here):
      2.0.8.11               - semantic version, e.g. 2.0.8.11
        - checksum of the Windows .zip asset
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Force UTF-8 on the console so user-facing messages don't get mangled on
# hosts with non-UTF-8 OEM code pages. Best-effort; older hosts can opt out.
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {
    # Pre-PS 5.0 / locked-down hosts. Not fatal.
}

# Templated by CI. The publish step rewrites these literals on every release.
$VERSION = '2.0.8.11'
$WINDOWS_AMD64_SHA256 = ''

$REPO = 'pandev-metriks/homebrew-pandev-cli-beta'
$ASSET_NAME = "pandev-cli-plugin_${VERSION}_Windows_amd64.zip"
$DOWNLOAD_URL = "https://github.com/$REPO/releases/download/v${VERSION}/$ASSET_NAME"

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  PanDev CLI Plugin - Beta install (Windows)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Version: $VERSION"
Write-Host ""

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------

# Refuse to run on non-Windows hosts. PowerShell 7+ runs on macOS/Linux too,
# and someone might pipe this into pwsh by mistake; bail early with a clear
# message instead of producing a broken half-install.
if ($PSVersionTable.PSEdition -eq 'Core' -and -not $IsWindows) {
    Write-Host "ERROR: This installer is Windows-only." -ForegroundColor Red
    Write-Host "       For macOS/Linux use the Homebrew tap or install-experimental.sh." -ForegroundColor Red
    exit 1
}

# Blank token means CI couldn't produce a real checksum for this release.
# Almost always the Windows build job failed; the .zip asset will not exist
# in the GitHub release. Fail fast with an actionable message instead of
# letting Invoke-WebRequest hit a 404.
if ([string]::IsNullOrWhiteSpace($WINDOWS_AMD64_SHA256) -or $WINDOWS_AMD64_SHA256 -eq '') {
    Write-Host "ERROR: Windows installer is not available for v$VERSION." -ForegroundColor Red
    Write-Host "       The CI build for Windows failed for this release." -ForegroundColor Red
    Write-Host "       Try a newer beta version once it lands, or contact the team." -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------------
# Download + verify
# ---------------------------------------------------------------------------

$tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pandev-install-" + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmpRoot -Force | Out-Null
$zipPath = Join-Path $tmpRoot $ASSET_NAME

# Best-effort cleanup. Bundles install-pandev.ps1 which we hand off to a
# separate elevated process, so we MUST keep the temp dir alive until that
# process completes - hence the try/finally wrapping the whole flow rather
# than a one-shot trap-style cleanup.
try {
    Write-Host "Downloading $ASSET_NAME..."
    # -UseBasicParsing keeps PowerShell 5.1 from initialising IE COM
    # objects (faster + works on Server Core where IE is absent).
    Invoke-WebRequest -UseBasicParsing -Uri $DOWNLOAD_URL -OutFile $zipPath

    Write-Host "Verifying checksum..."
    $actualSha = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $expectedSha = $WINDOWS_AMD64_SHA256.ToLowerInvariant()
    if ($actualSha -ne $expectedSha) {
        throw @"
SHA256 mismatch for $ASSET_NAME.
  expected: $expectedSha
  actual:   $actualSha
Refusing to install a tampered or stale archive.
"@
    }

    Write-Host "Extracting..."
    Expand-Archive -Path $zipPath -DestinationPath $tmpRoot -Force

    $installer = Join-Path $tmpRoot 'install-pandev.ps1'
    if (-not (Test-Path -LiteralPath $installer)) {
        throw "install-pandev.ps1 missing from $ASSET_NAME after extract."
    }

    # ---------------------------------------------------------------------------
    # Hand off to install-pandev.ps1
    # ---------------------------------------------------------------------------
    # install-pandev.ps1 self-elevates via UAC if needed. We invoke it in a
    # SEPARATE powershell.exe child process for two reasons:
    #   1. The current session may have been started by `iwr|iex`, in which
    #      case $PSCommandPath is empty inside it and install-pandev.ps1's
    #      Resolve-MsixPath would fail to locate the .msix.
    #   2. install-pandev.ps1 calls `exit` on success/failure paths; doing so
    #      inside the current session would kill the user's interactive
    #      PowerShell window. A subprocess keeps the parent alive.
    Write-Host ""
    Write-Host "Launching install-pandev.ps1 (UAC prompt will appear)..." -ForegroundColor Yellow
    Write-Host ""

    $childArgs = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', "`"$installer`""
    )
    $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList $childArgs -Wait -PassThru -NoNewWindow
    if ($proc.ExitCode -ne 0) {
        throw "install-pandev.ps1 exited with code $($proc.ExitCode)."
    }

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "  PanDev CLI installed successfully" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "Open a NEW PowerShell window (so the 'pandev' appExecutionAlias resolves),"
    Write-Host "then run: pandev login"
    Write-Host ""
} finally {
    # Remove-Item -Recurse can fail when files are still locked by the
    # elevated child; treat cleanup as best-effort so a stale temp dir
    # never overrides the actual install exit code.
    try {
        Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction Stop
    } catch {
        Write-Host "(temp directory $tmpRoot was left behind; delete manually if you care)" -ForegroundColor DarkGray
    }
}
