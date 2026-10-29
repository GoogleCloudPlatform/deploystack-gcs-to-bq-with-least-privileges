#!/usr/bin/env bash
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Repair dsexec if the Cloud Shell image binary fails due to a GLIBC mismatch,
# and ensure Terraform >= 1.12.2 is installed (fixes #67).
mkdir -p "$HOME/bin"
export PATH="$HOME/bin:$PATH"

if ! command -v dsexec >/dev/null 2>&1 || ! dsexec -version >/dev/null 2>&1; then
  if command -v go >/dev/null 2>&1; then
    echo "Rebuilding a static dsexec binary for Cloud Shell compatibility..."
    DS_TMP_DIR=$(mktemp -d)
    (
      cd "$DS_TMP_DIR" \
        && curl -fsSL "https://raw.githubusercontent.com/GoogleCloudPlatform/deploystack/main/docker/deploystack_exec.go" -o deploystack_exec.go \
        && go mod init exec \
        && go get github.com/GoogleCloudPlatform/deploystack@latest \
        && go mod tidy \
        && grep deploystack go.mod | head -1 | sed 's|github.com/GoogleCloudPlatform/||g; s|require||g; s|deploystack||g' | xargs > versionDS \
        && date +"%m-%d-%Y %r %Z" | xargs > buildTime \
        && CGO_ENABLED=0 GOOS=linux go build -o "$HOME/bin/dsexec" deploystack_exec.go
    ) && chmod +x "$HOME/bin/dsexec"
    rm -rf "$DS_TMP_DIR"

    if [ -f "$HOME/bin/dsexec" ]; then
      if [ -w /usr/local/bin/dsexec ] || [ -w /usr/local/bin ]; then
        cp -f "$HOME/bin/dsexec" /usr/local/bin/dsexec
      elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
        sudo -n cp -f "$HOME/bin/dsexec" /usr/local/bin/dsexec || true
      fi
    fi
  fi
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ -f "${SCRIPT_DIR}/preinit.sh" ]; then
  . "${SCRIPT_DIR}/preinit.sh"
elif [ -f ".deploystack/scripts/preinit.sh" ]; then
  . ".deploystack/scripts/preinit.sh"
fi
