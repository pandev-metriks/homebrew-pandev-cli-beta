<#
    The PanDev CLI beta installer has moved.

    Everything public about the CLI now lives in one repository:
      https://github.com/pandev-metriks/pandev-cli
    This stub keeps old bookmarks and scripts working by delegating to the
    current installer. Update your notes to the new URL:
      iwr https://raw.githubusercontent.com/pandev-metriks/pandev-cli/main/install-experimental.ps1 -UseBasicParsing | iex
#>
Write-Host "The PanDev CLI installer moved to https://github.com/pandev-metriks/pandev-cli - redirecting..."
Invoke-WebRequest https://raw.githubusercontent.com/pandev-metriks/pandev-cli/main/install-experimental.ps1 -UseBasicParsing | Invoke-Expression
