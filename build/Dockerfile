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

# Add a user 'protonmail' with UID 8535
RUN useradd -u 8535 -d /home/protonmail protonmail
# change to non-privileged user for extra security
USER protonmail

ENTRYPOINT ["bash", "/protonmail/entrypoint.sh"]
