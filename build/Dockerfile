# The build image could be golang, but it currently does not support riscv64. Only debian:sid does, at the time of writing.
FROM ubuntu:latest AS build

# Install dependencies
RUN apt-get update && apt-get install -y git golang build-essential libsecret-1-dev

# Build
WORKDIR /build/
COPY build.sh VERSION /build/
RUN bash build.sh

FROM ubuntu:latest
LABEL maintainer="Simon Felding <sife@adm.ku.dk>"

EXPOSE 25/tcp
EXPOSE 143/tcp

# Install dependencies and protonmail bridge
RUN apt-get update \
    && apt-get install -y --no-install-recommends dbus-x11 socat pass libsecret-1-0 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy bash scripts
COPY gpgparams entrypoint.sh /protonmail/

# Copy protonmail
COPY --from=build /build/proton-bridge/bridge /protonmail/
COPY --from=build /build/proton-bridge/proton-bridge /protonmail/
COPY --from=build /build/proton-bridge/vault-editor /protonmail/

# 1. Tell Bridge where to store config and data
ENV XDG_CONFIG_HOME=/data/config
ENV XDG_DATA_HOME=/data/data

# 2. Tell GPG where to store keys
ENV GNUPGHOME=/data/gpg

# 3. Tell Pass where to store the password store
ENV PASSWORD_STORE_DIR=/data/pass

# Add a user 'protonmail'
RUN useradd protonmail \
    && mkdir -p /data/config /data/data/ /data/gpg /data/pass \
    && chown -R protonmail:protonmail /data \
    && chmod 700 /data/gpg
USER protonmail
VOLUME /data
WORKDIR /home/protonmail

ENTRYPOINT ["bash", "/protonmail/entrypoint.sh"]
