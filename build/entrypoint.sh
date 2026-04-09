#!/usr/bin/env bash

set -euo pipefail

readonly BRIDGE_BIN="/protonmail/bridge"
SOCAT_SMTP_PID=""
SOCAT_IMAP_PID=""
BRIDGE_PID=""

: "${PASSWORD_STORE_DIR:=/data/pass}"
export PASSWORD_STORE_DIR

cleanup() {
    for pid in "${BRIDGE_PID}" "${SOCAT_SMTP_PID}" "${SOCAT_IMAP_PID}"; do
        if [[ -n "${pid}" ]]; then
            kill "${pid}" 2>/dev/null || true
        fi
    done
}

forward_signal() {
    cleanup
    exit 143
}

prepare_state() {
    install -d \
        -m 700 \
        "${XDG_CONFIG_HOME}" \
        "${XDG_DATA_HOME}" \
        "${XDG_CACHE_HOME}" \
        "${PASSWORD_STORE_DIR}"
    install -d \
        -m 700 \
        "${XDG_CACHE_HOME}/protonmail" \
        "${XDG_CACHE_HOME}/protonmail/bridge-v3" \
        "${XDG_CACHE_HOME}/protonmail/bridge-v3/unleash_startup_cache"
    install -d -m 700 "${GNUPGHOME}"
}

ensure_pass_store() {
    if ! gpg --list-secret-keys pass-key >/dev/null 2>&1; then
        gpg --generate-key --batch /protonmail/gpgparams >/dev/null
    fi

    if [[ ! -f "${PASSWORD_STORE_DIR}/.gpg-id" ]]; then
        pass init pass-key >/dev/null
    fi
}

run_mode() {
    trap cleanup EXIT
    trap forward_signal INT TERM

    ensure_pass_store

    socat TCP6-LISTEN:1125,reuseaddr,fork TCP:127.0.0.1:1025 &
    SOCAT_SMTP_PID=$!

    socat TCP6-LISTEN:1243,reuseaddr,fork TCP:127.0.0.1:1143 &
    SOCAT_IMAP_PID=$!

    "${BRIDGE_BIN}" --noninteractive "$@" &
    BRIDGE_PID=$!

    set +e
    wait "${BRIDGE_PID}"
    local status=$?
    set -e

    return "${status}"
}

init_mode() {
    ensure_pass_store
    exec "${BRIDGE_BIN}" --cli "$@"
}

prepare_state

case "${1:-run}" in
    init)
        shift
        init_mode "$@"
        ;;
    run)
        shift
        run_mode "$@"
        ;;
    *)
        run_mode "$@"
        ;;
esac
