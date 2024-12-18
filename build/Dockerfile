# Use official golang image
FROM golang:1.23-bullseye AS build

# Install dependencies
RUN apt-get update && apt-get install -y git build-essential libsecret-1-dev

# Build
WORKDIR /build/
COPY build.sh VERSION /build/
RUN bash build.sh

FROM ubuntu:noble
LABEL org.opencontainers.image.source="https://github.com/Enucatl/protonmail-bridge-docker/"

# Install dependencies and protonmail bridge
RUN apt-get update \
    && apt-get install -y --no-install-recommends dbus-x11 socat pass libsecret-1-0 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy bash scripts
COPY gpgparams entrypoint.sh /protonmail/

# Copy protonmail
COPY --from=build /build/proton-bridge/bridge /protonmail/
COPY --from=build /build/proton-bridge/proton-bridge /protonmail/

# Add a user 'protonmail' with UID 8535
RUN useradd -u 8535 -d /home/protonmail protonmail
# change to non-privileged user for extra security
USER protonmail

ENTRYPOINT ["bash", "/protonmail/entrypoint.sh"]
