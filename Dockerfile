# syntax=docker/dockerfile:1-labs
# kics-scan disable=ae9c56a6-3ed1-4ac0-9b54-31267f51151d,4b410d24-1cbe-4430-a632-62c9a931cf1c,d3499f6d-1651-41bb-a9a7-de925fea487b,aa93e17f-b6db-4162-9334-c70334e7ac28,9513a694-aa0d-41d8-be61-3271e056f36b

ARG ALPINE_VERSION="3.18"

FROM alpine:${ALPINE_VERSION} AS builder
COPY apk_packages /tmp/
# hadolint ignore=DL3018
RUN --mount=type=cache,id=builder_apk_cache,target=/var/cache/apk \
    apk add gettext-envsubst

FROM golang:alpine${ALPINE_VERSION} as gobuilder
ENV PARANOIA_REPOSITORY="https://github.com/jetstack/paranoia.git"
ENV PARANOIA_VERSION="v0.2.1"
ENV PARANOIA_BUILD_DIR="/go/src/github.com/jetstack/paranoia"
ENV PARANOIA_PKG="paranoia"
ENV GOOS="linux"
ENV GOARCH="amd64"
ENV CGO_ENABLED="0" 

# PARANOIA
#checkov:skip=CKV_DOCKER_4
ADD ${PARANOIA_REPOSITORY}#${PARANOIA_VERSION} ${PARANOIA_BUILD_DIR}
WORKDIR ${PARANOIA_BUILD_DIR}
RUN go get ./... \
    && go build -o "${PARANOIA_PKG}" \
                -a -ldflags="-installsuffix cgo"
RUN chmod 4755 "${PARANOIA_PKG}"

FROM alpine:${ALPINE_VERSION}
LABEL maintainer="Thomas GUIRRIEC <thomas@guirriec.fr>"
ARG PARANOIA_BUILD_DIR="/go/src/github.com/jetstack/paranoia"
ARG PARANOIA_PKG="paranoia"
ENV USERNAME="paranoia"
ENV UID="1000"
COPY --from=gobuilder ${PARANOIA_BUILD_DIR}/${PARANOIA_PKG} /bin/${PARANOIA_PKG}
RUN --mount=type=bind,from=builder,source=/usr/bin/envsubst,target=/usr/bin/envsubst \
    --mount=type=bind,from=builder,source=/usr/lib/libintl.so.8,target=/usr/lib/libintl.so.8 \
    --mount=type=bind,from=builder,source=/tmp,target=/tmp \
    --mount=type=cache,id=apk_cache,target=/var/cache/apk \
    apk --update add `envsubst < /tmp/apk_packages` \
    && useradd -l -u "${UID}" -U -s /bin/sh -m "${USERNAME}"
USER ${USERNAME}
HEALTHCHECK CMD paranoia -h || exit 1
WORKDIR /home/${USERNAME}
ENTRYPOINT ["/bin/sh", "-c", "sleep infinity"]
