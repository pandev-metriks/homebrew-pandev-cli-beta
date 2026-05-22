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
      a6327254dd61c009fccf03af8f4d8bae20ead1424fd02eb087001d10425f983e  - checksum of the Windows .zip asset

    EXECUTION MODEL:
    Designed to be safe under `iwr | iex` - i.e., when iex runs the
    downloaded text in the user's CURRENT PowerShell session. That means:
      - DON'T set $ErrorActionPreference at the top level (would leak to
        the user's session and turn every later command-not-found into a
        session-killing terminating error).
      - DON'T use `exit` for error paths (would close the user's terminal).
    Everything runs inside a scriptblock `& { ... }` so $ErrorActionPreference
    is scoped to that block, and error paths use `return` instead of `exit`.
#>

# Wrap the whole installer in a scriptblock so any preference changes
# (especially $ErrorActionPreference = 'Stop') stay scoped to the block.
# When invoked as `iwr | iex`, the script's top level runs in the caller's
# session - leaking 'Stop' into that session would kill the terminal on
# the next command-not-found.
& {
    $ErrorActionPreference = 'Stop'

    # Force UTF-8 on the console so user-facing messages don't get mangled
    # on hosts with non-UTF-8 OEM code pages. Best-effort.
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    } catch {
        # Pre-PS 5.0 / locked-down hosts. Not fatal.
    }

    # Templated by CI. Publish step rewrites these literals on every release.
    $VERSION = '2.0.8.11'
    $WINDOWS_AMD64_SHA256 = 'a6327254dd61c009fccf03af8f4d8bae20ead1424fd02eb087001d10425f983e'

    $REPO = 'pandev-metriks/homebrew-pandev-cli-beta'
    $ASSET_NAME = "pandev-cli-plugin_${VERSION}_Windows_amd64.zip"
    $DOWNLOAD_URL = "https://github.com/$REPO/releases/download/v${VERSION}/$ASSET_NAME"

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "  PanDev CLI Plugin - Beta install (Windows)" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "  Version: $VERSION"
    Write-Host ""

    # -----------------------------------------------------------------------
    # Sanity checks. Use `return` (exits the scriptblock) instead of `exit`
    # (would close the iex-invoking session). The caller sees a no-op return,
    # not a dead terminal.
    # -----------------------------------------------------------------------
    if ($PSVersionTable.PSEdition -eq 'Core' -and -not $IsWindows) {
        Write-Host "ERROR: This installer is Windows-only." -ForegroundColor Red
        Write-Host "       For macOS/Linux use the Homebrew tap or install-experimental.sh." -ForegroundColor Red
        return
    }

    if ([string]::IsNullOrWhiteSpace($WINDOWS_AMD64_SHA256) -or $WINDOWS_AMD64_SHA256 -eq 'a6327254dd61c009fccf03af8f4d8bae20ead1424fd02eb087001d10425f983e') {
        Write-Host "ERROR: Windows installer is not available for v$VERSION." -ForegroundColor Red
        Write-Host "       The CI build for Windows failed for this release." -ForegroundColor Red
        Write-Host "       Try a newer beta version once it lands, or contact the team." -ForegroundColor Red
        return
    }

    # -----------------------------------------------------------------------
    # Download + verify + extract + hand off
    # -----------------------------------------------------------------------
    $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pandev-install-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmpRoot -Force | Out-Null
    $zipPath = Join-Path $tmpRoot $ASSET_NAME

    # Track success so the catch block can report cleanly without bubbling
    # an exception up into the user's session.
    $installSucceeded = $false

    try {
        Write-Host "Downloading $ASSET_NAME..."
        Invoke-WebRequest -UseBasicParsing -Uri $DOWNLOAD_URL -OutFile $zipPath

        Write-Host "Verifying checksum..."
        $actualSha = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
        $expectedSha = $WINDOWS_AMD64_SHA256.ToLowerInvariant()
        if ($actualSha -ne $expectedSha) {
            throw "SHA256 mismatch for $ASSET_NAME. expected=$expectedSha actual=$actualSha"
        }

        Write-Host "Extracting..."
        Expand-Archive -Path $zipPath -DestinationPath $tmpRoot -Force

        $installer = Join-Path $tmpRoot 'install-pandev.ps1'
        if (-not (Test-Path -LiteralPath $installer)) {
            throw "install-pandev.ps1 missing from $ASSET_NAME after extract."
        }

        # Hand off in a SEPARATE powershell.exe process (not in this scope):
        #   - install-pandev.ps1 self-elevates via UAC and calls `exit` on
        #     finish; running in a separate process keeps that exit from
        #     terminating either our scriptblock or the user's session.
        #   - The child uses its own console window (no -NoNewWindow) so
        #     the install log doesn't compete with the user's prompt and
        #     the elevation flow is visually obvious.
        Write-Host ""
        Write-Host "Launching install-pandev.ps1 (UAC prompt will appear)..." -ForegroundColor Yellow
        Write-Host ""

        $childArgs = @(
            '-NoProfile',
            '-ExecutionPolicy', 'Bypass',
            '-File', "`"$installer`""
        )
        $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList $childArgs -Wait -PassThru
        if ($proc.ExitCode -ne 0) {
            # Don't throw - that would propagate via iex back to the user
            # session and (with their EAP) could close the terminal.
            # Print and return instead.
            Write-Host ""
            Write-Host "ERROR: install-pandev.ps1 exited with code $($proc.ExitCode)." -ForegroundColor Red
            Write-Host "       See the elevated PowerShell window for details." -ForegroundColor Red
            return
        }

        $installSucceeded = $true
    } catch {
        Write-Host ""
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
        # Swallow the exception - don't propagate to caller's session.
    } finally {
        try {
            Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Host "(temp directory $tmpRoot was left behind; delete manually if you care)" -ForegroundColor DarkGray
        }
    }

    if (-not $installSucceeded) {
        # Already printed the failure reason above; just return so the
        # caller's session continues unharmed.
        return
    }

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "  PanDev CLI installed successfully" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "Open a NEW PowerShell window (so the 'pandev' appExecutionAlias resolves),"
    Write-Host "then run: pandev login"
    Write-Host ""
}
