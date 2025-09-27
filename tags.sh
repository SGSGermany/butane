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
source "$CI_TOOLS_PATH/helper/github.sh.inc"

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$BUILD_DIR/container.env"

BUILD_INFO=""
if [ $# -gt 0 ] && [[ "$1" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
    BUILD_INFO=".${1,,}"
fi

# get latest Butane version
GITHUB_REPO_IDENT="${BUTANE_GIT_REPO#https://github.com/}"
VERSION="$(github_latest "$GITHUB_REPO_IDENT")"

if [ -z "$VERSION" ]; then
    echo "Unable to read Butane version from GitHub API" >&2
    exit 1
elif ! [[ "$VERSION" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)([+~-]|$) ]]; then
    echo "Unable to read Butane version from GitHub API: '$VERSION' is no valid version" >&2
    exit 1
fi

VERSION_FULL="${VERSION:1}"
VERSION="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
VERSION_MINOR="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
VERSION_MAJOR="${BASH_REMATCH[1]}"

# build tags
BUILD_INFO="$(date --utc +'%Y%m%d')$BUILD_INFO"

TAGS=(
    "v$VERSION" "v$VERSION-$BUILD_INFO"
    "v$VERSION_MINOR" "v$VERSION_MINOR-$BUILD_INFO"
    "v$VERSION_MAJOR" "v$VERSION_MAJOR-$BUILD_INFO"
    "latest"
)

printf 'MILESTONE="%s"\n' "$VERSION_MINOR"
printf 'VERSION="%s"\n' "$VERSION_FULL"
printf 'TAGS="%s"\n' "${TAGS[*]}"
