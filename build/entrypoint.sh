#!/usr/bin/env bash

set -euo pipefail

readonly BRIDGE_BIN="/protonmail/bridge"
readonly BRIDGE_TLS_CERT_PATH="${BRIDGE_TLS_CERT_PATH:-/protonmail/certs/cert.pem}"
readonly BRIDGE_TLS_KEY_PATH="${BRIDGE_TLS_KEY_PATH:-/protonmail/certs/key.pem}"
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

has_custom_tls_certs() {
    [[ -r "${BRIDGE_TLS_CERT_PATH}" && -r "${BRIDGE_TLS_KEY_PATH}" ]]
}

import_tls_certs() {
    if ! has_custom_tls_certs; then
        echo "No readable custom Bridge TLS certificate found at ${BRIDGE_TLS_CERT_PATH} and ${BRIDGE_TLS_KEY_PATH}; skipping import." >&2
        return 0
    fi

    printf 'cert import\n%s\n%s\nexit\n' \
        "${BRIDGE_TLS_CERT_PATH}" \
        "${BRIDGE_TLS_KEY_PATH}" \
        | "${BRIDGE_BIN}" --cli "$@"
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
    "${BRIDGE_BIN}" --cli "$@"
    local status=$?

    if [[ "${status}" -eq 0 ]]; then
        import_tls_certs
    fi

    return "${status}"
}

import_certs_mode() {
    ensure_pass_store
    import_tls_certs "$@"
}

prepare_state

case "${1:-run}" in
    init)
        shift
        init_mode "$@"
        ;;
    import-certs)
        shift
        import_certs_mode "$@"
        ;;
    run)
        shift
        run_mode "$@"
        ;;
    *)
        run_mode "$@"
        ;;
esac
