#!/bin/bash
# Unbound
# A container running Butane, a config translator for FCOS' Ignition.
#
# Copyright (c) 2025  SGS Serious Gaming & Simulations GmbH
#
# This work is licensed under the terms of the MIT license.
# For a copy, see LICENSE file or <https://opensource.org/licenses/MIT>.
#
# SPDX-License-Identifier: MIT
# License-Filename: LICENSE

set -eu -o pipefail
export LC_ALL=C.UTF-8

[ -v CI_TOOLS ] && [ "$CI_TOOLS" == "SGSGermany" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS' not set or invalid" >&2; exit 1; }

[ -v CI_TOOLS_PATH ] && [ -d "$CI_TOOLS_PATH" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS_PATH' not set or invalid" >&2; exit 1; }

source "$CI_TOOLS_PATH/helper/common.sh.inc"
source "$CI_TOOLS_PATH/helper/chkupd.sh.inc"
source "$CI_TOOLS_PATH/helper/git.sh.inc"
source "$CI_TOOLS_PATH/helper/github.sh.inc"

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$BUILD_DIR/container.env"

TAG="${TAGS%% *}"

# check whether the base image was updated
chkupd_baseimage "$REGISTRY/$OWNER/$IMAGE" "$TAG" || exit 0

# check Butane and mbutane versions (use latest GitHub release for Butane, and Git hash for mbutane)
if [[ ! "$BUTANE_GIT_REPO" =~ ^https://github\.com/([^/]+/[^/]+)\.git$ ]]; then
    echo "Failed to extract GitHub repo slug from Git repo URL: $BUTANE_GIT_REPO" >&2
    exit 1
fi

BUTANE_LATEST_VERSION="$(github_latest "${BASH_REMATCH[1]}")"
MBUTANE_LATEST_HASH="$(git_latest_commit "$MBUTANE_GIT_REPO" "$MBUTANE_GIT_REF")"

chkupd_image_env_vars "$REGISTRY/$OWNER/$IMAGE" \
    BUTANE_VERSION="${BUTANE_LATEST_VERSION#v}" \
    MBUTANE_HASH="$MBUTANE_LATEST_HASH" \
    || exit 0
