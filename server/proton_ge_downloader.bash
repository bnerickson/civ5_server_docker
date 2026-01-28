#!/usr/bin/env bash
# Original script source: https://github.com/jerluc/proton-ge-downloader/tree/main

# Exit on error, fail if an unset variable is referenced, turn on tracing, and fail if a command fails in a pipe.
set -o errexit -o nounset -o xtrace -o pipefail

GE_PROTON_VERSION="${1}"
RELEASES=$(curl -s "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases?per_page=1")
LATEST_RELEASE=$(echo $RELEASES | jq '.[0]')
TARBALL_ASSET=$(echo $LATEST_RELEASE | jq '.assets[] | select(.name | endswith("tar.gz"))')
if [ "${GE_PROTON_VERSION}" = "latest" ]; then
    DOWNLOAD_URL=$(echo $TARBALL_ASSET | jq -r '.browser_download_url')
    FILENAME=$(echo $TARBALL_ASSET | jq -r '.name')
else
    DOWNLOAD_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${GE_PROTON_VERSION}/${FILENAME}"
    FILENAME="${GE_PROTON_VERSION}.tar.gz"
fi

OUTPUT_PARENT_DIR="${HOME}/proton"
OUTPUT_DIR=$(basename --suffix=".tar.gz" "${FILENAME}")

if [ -d "${OUTPUT_PARENT_DIR}/${OUTPUT_DIR}" ]; then
    echo "Proton-GE (${OUTPUT_DIR}) already exists"
    exit 1
else
    echo "Found new Proton-GE release (${OUTPUT_DIR}). Downloading..."
    curl --location --output "/tmp/${FILENAME}" "${DOWNLOAD_URL}"
    tar --extract --file="/tmp/${FILENAME}" --directory="${OUTPUT_PARENT_DIR}"
    rm "/tmp/${FILENAME}"
fi
