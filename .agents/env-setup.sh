#!/usr/bin/env bash
#
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

readonly BAZELISK_VERSION="v1.28.1"
readonly BUILDIFIER_VERSION="v6.4.0"
readonly BIN_DIR="${HOME}/.local/bin"

mkdir -p "${BIN_DIR}"

case "$(uname -m)" in
  x86_64) ARCH="amd64" ;;
  aarch64 | arm64) ARCH="arm64" ;;
  *)
    echo "Unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

# Install Bazelisk and symlink it as bazel.
if [[ ! -x "${BIN_DIR}/bazelisk" ]]; then
  curl -fsSL -o "${BIN_DIR}/bazelisk" \
    "https://github.com/bazelbuild/bazelisk/releases/download/${BAZELISK_VERSION}/bazelisk-linux-${ARCH}"
  chmod +x "${BIN_DIR}/bazelisk"
fi
ln -sfn "${BIN_DIR}/bazelisk" "${BIN_DIR}/bazel"

# Install Buildifier for formatting BUILD.bazel / .bzl files.
if [[ ! -x "${BIN_DIR}/buildifier" ]]; then
  curl -fsSL -o "${BIN_DIR}/buildifier" \
    "https://github.com/bazelbuild/buildtools/releases/download/${BUILDIFIER_VERSION}/buildifier-linux-${ARCH}"
  chmod +x "${BIN_DIR}/buildifier"
fi

# Install missing system development packages on Debian/Ubuntu.
if command -v apt-get >/dev/null 2>&1; then
  sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
    libnghttp2-dev \
    python3-dev \
    shellcheck
fi

# Ensure ~/.local/bin is on PATH in non-interactive shells.
sed -i '/case \$- in/,/esac/d' "${HOME}/.bashrc" 2>/dev/null || true
# shellcheck disable=SC2016
readonly PATH_EXPORT='export PATH="$HOME/.local/bin:$PATH"'
grep -qxF "${PATH_EXPORT}" "${HOME}/.bashrc" 2>/dev/null ||
  echo "${PATH_EXPORT}" >>"${HOME}/.bashrc"

# Configure Bazel's embedded JDK to use the system Java CA truststore if present.
if [[ -f /etc/ssl/certs/java/cacerts ]]; then
  readonly TRUSTSTORE_FLAG='startup --host_jvm_args=-Djavax.net.ssl.trustStore=/etc/ssl/certs/java/cacerts'
  readonly TRUSTSTORE_PASS='startup --host_jvm_args=-Djavax.net.ssl.trustStorePassword=changeit'
  grep -qxF "${TRUSTSTORE_FLAG}" "${HOME}/.bazelrc" 2>/dev/null ||
    echo "${TRUSTSTORE_FLAG}" >>"${HOME}/.bazelrc"
  grep -qxF "${TRUSTSTORE_PASS}" "${HOME}/.bazelrc" 2>/dev/null ||
    echo "${TRUSTSTORE_PASS}" >>"${HOME}/.bazelrc"
fi

# Pre-download the Bazel version pinned in .bazelversion.
"${BIN_DIR}/bazel" --version
