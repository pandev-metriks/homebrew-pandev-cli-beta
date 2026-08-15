#!/bin/bash
# =============================================================================
# The PanDev CLI beta installer has moved.
#
# Everything public about the CLI now lives in one repository:
#   https://github.com/pandev-metriks/pandev-cli
# This stub keeps old bookmarks and scripts working by delegating to the
# current installer. Update your notes to the new URL:
#   curl -fsSL https://raw.githubusercontent.com/pandev-metriks/pandev-cli/main/install-experimental.sh | bash
# =============================================================================
set -e
echo "The PanDev CLI installer moved to https://github.com/pandev-metriks/pandev-cli — redirecting..."
exec bash <(curl -fsSL https://raw.githubusercontent.com/pandev-metriks/pandev-cli/main/install-experimental.sh)
