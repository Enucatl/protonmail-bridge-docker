#!/usr/bin/env bash

set -euo pipefail

VERSION="$(< VERSION)"
ARCHIVE_URL="https://github.com/ProtonMail/proton-bridge/archive/refs/tags/v${VERSION}.tar.gz"

curl -fsSL "${ARCHIVE_URL}" | tar -xz
mv "proton-bridge-${VERSION}" proton-bridge
cd proton-bridge

export GOFLAGS="-trimpath"
go get golang.org/x/text@v0.39.0 google.golang.org/grpc@v1.82.1
make build-nogui

strip bridge proton-bridge
