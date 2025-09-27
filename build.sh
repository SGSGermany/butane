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

ROOT_HINTS="https://www.internic.net/domain/named.cache"

set -eu -o pipefail
export LC_ALL=C.UTF-8

[ -v CI_TOOLS ] && [ "$CI_TOOLS" == "SGSGermany" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS' not set or invalid" >&2; exit 1; }

[ -v CI_TOOLS_PATH ] && [ -d "$CI_TOOLS_PATH" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS_PATH' not set or invalid" >&2; exit 1; }

source "$CI_TOOLS_PATH/helper/common.sh.inc"
source "$CI_TOOLS_PATH/helper/common-traps.sh.inc"
source "$CI_TOOLS_PATH/helper/container.sh.inc"
source "$CI_TOOLS_PATH/helper/container-alpine.sh.inc"
source "$CI_TOOLS_PATH/helper/git.sh.inc"
source "$CI_TOOLS_PATH/helper/gpg.sh.inc"

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$BUILD_DIR/container.env"

readarray -t -d' ' TAGS < <(printf '%s' "$TAGS")

echo + "CONTAINER=\"\$(buildah from $(quote "$BASE_IMAGE"))\"" >&2
CONTAINER="$(buildah from "$BASE_IMAGE")"

echo + "MOUNT=\"\$(buildah mount $(quote "$CONTAINER"))\"" >&2
MOUNT="$(buildah mount "$CONTAINER")"

echo + "rsync -v -rl --exclude .gitignore ./src/ …/" >&2
rsync -v -rl --exclude '.gitignore' "$BUILD_DIR/src/" "$MOUNT/"

# download and install `butane`
echo + "BUTANE_TMP=\"\$(mktemp -d)\"" >&2
BUTANE_TMP="$(mktemp -d)"
trap_exit rm -rf "$BUTANE_TMP"

cmd curl -sSL -f -o "$BUTANE_TMP/butane" "$BUTANE_BINARY_URL"

cmd curl -sSL -f -o "$BUTANE_TMP/butane.asc" "$BUTANE_SIGNATURE_URL"

cmd curl -sSL -f -o "$BUTANE_TMP/fedora.gpg" "$BUTANE_KEYRING_URL"

gpg_verify "$BUTANE_TMP/butane" "$BUTANE_TMP/butane.asc" "$BUTANE_TMP/fedora.gpg"

echo + "cp $(quote "$BUTANE_TMP/butane") …/usr/local/bin/butane" >&2
cp "$BUTANE_TMP/butane" "$MOUNT/usr/local/bin/butane"

cmd buildah run "$CONTAINER" -- \
    chmod +x /usr/local/bin/butane

echo + "VERSION=\"\$(buildah run $(quote "$CONTAINER") -- butane --version | sed -ne '1{s/^Butane \(.*\)$/\1/p}')\"" >&2
BUTANE_VERSION="$(buildah run "$CONTAINER" -- butane --version | sed -ne '1{s/^Butane \(.*\)$/\1/p}')"

BUTANE_HASH="$(git_latest_commit "$BUTANE_GIT_REPO" "refs/tags/v$BUTANE_VERSION")"

# download and install `mbutane`
pkg_install "$CONTAINER" --virtual .mbutane-run-deps \
    python3

pkg_install "$CONTAINER" --virtual .mbutane-fetch-deps@community \
    py3-pip

cmd buildah config \
    --env PYTHONUSERBASE="/usr/local" \
    "$CONTAINER"

cmd buildah run  "$CONTAINER" -- \
    pip config set global.root-user-action ignore

cmd buildah run  "$CONTAINER" -- \
    pip config set global.break-system-packages true

git_clone "$MBUTANE_GIT_REPO" "$MBUTANE_GIT_REF" "$MOUNT/usr/src/mbutane" "…/usr/src/mbutane"

cmd buildah run  "$CONTAINER" -- \
    pip install --user "/usr/src/mbutane/"

echo + "VERSION=\"\$(buildah run $(quote "$CONTAINER") -- mbutane --version | sed -ne '1{s/^mbutane \(.*\)$/\1/p}')\"" >&2
MBUTANE_VERSION="$(buildah run "$CONTAINER" -- mbutane --version | sed -ne '1{s/^mbutane \(.*\)$/\1/p}')"

echo + "COMMIT=\"\$(git -C …/usr/src/mbutane rev-parse HEAD)\"" >&2
MBUTANE_HASH="$(git -C "$MOUNT/usr/src/mbutane" rev-parse HEAD)"

pkg_remove "$CONTAINER" \
    .mbutane-fetch-deps

echo + "rm -rf …/root/.cache/pip …/root/.config/pip" >&2
rm -rf "$MOUNT/root/.cache/pip" "$MOUNT/root/.config/pip"

echo + "rm -rf …/usr/src/mbutane" >&2
rm -rf "$MOUNT/usr/src/mbutane"

# finalize image
cleanup "$CONTAINER"

con_cleanup "$CONTAINER"

cmd buildah config \
    --env BUTANE_VERSION="$BUTANE_VERSION" \
    --env BUTANE_HASH="$BUTANE_HASH" \
    --env MBUTANE_VERSION="$MBUTANE_VERSION" \
    --env MBUTANE_HASH="$MBUTANE_HASH" \
    "$CONTAINER"

cmd buildah config \
    --volume "/var/lib/butane" \
    "$CONTAINER"

cmd buildah config \
    --workingdir "/var/lib/butane" \
    --cmd '[ "mbutane" ]' \
    "$CONTAINER"

cmd buildah config \
    --annotation org.opencontainers.image.title="Butane" \
    --annotation org.opencontainers.image.description="A container running Butane, a config translator for FCOS' Ignition." \
    --annotation org.opencontainers.image.version="$BUTANE_VERSION" \
    --annotation org.opencontainers.image.url="https://github.com/SGSGermany/butane" \
    --annotation org.opencontainers.image.authors="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.vendor="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.licenses="MIT" \
    --annotation org.opencontainers.image.base.name="$BASE_IMAGE" \
    --annotation org.opencontainers.image.base.digest="$(podman image inspect --format '{{.Digest}}' "$BASE_IMAGE")" \
    --annotation org.opencontainers.image.created="$(date -u +'%+4Y-%m-%dT%H:%M:%SZ')" \
    "$CONTAINER"

con_commit "$CONTAINER" "$IMAGE" "${TAGS[@]}"
