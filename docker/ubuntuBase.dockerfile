# syntax=docker/dockerfile:1.7
ARG OS_BASE=ubuntu:24.04

FROM ${OS_BASE} AS base

ARG OS_BASE
ENV OS_BASE=${OS_BASE}
ENV APT_VAR_CACHE_ID=infracommons-apt-var-cache-${OS_BASE}
ENV APT_LIST_CACHE_ID=infracommons-apt-list-cache-${OS_BASE}
ENV DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Trim documentation, manuals, and non-English locales at the dpkg level so every package
# installed in this image and in its descendants stays lean.
RUN printf '%s\n'                                                                                  \
    'path-exclude /usr/share/doc/*'                                                                \
    'path-exclude /usr/share/man/*'                                                                \
    'path-include /usr/share/locale/locale.alias'                                                  \
    'path-include /usr/share/locale/en*/*'                                                         \
    'path-exclude /usr/share/locale/*'                                                             \
    'path-exclude /usr/share/info/*'                                                               \
    > /etc/dpkg/dpkg.cfg.d/01_nodoc

# Work around hash-sum mismatches that intermediate proxies cause by disabling pipelining and
# proxy caching for apt downloads.
RUN printf '%s\n'                                                                                  \
    'Acquire::http::Pipeline-Depth 0;'                                                             \
    'Acquire::https::Pipeline-Depth 0;'                                                            \
    'Acquire::http::No-Cache true;'                                                                \
    'Acquire::https::No-Cache true;'                                                               \
    'Acquire::BrokenProxy    true;'                                                                \
    >> /etc/apt/apt.conf.d/90fix-hashsum-mismatch

# Make apt resilient to flaky upstreams (e.g., Launchpad PPA hosting under stress):
# 5 retries with short per-request timeouts so each failed attempt fails fast and
# we get more shots at reaching a healthy backend behind the load balancer.
RUN printf '%s\n'                                                                                  \
    'Acquire::Retries "5";'                                                                        \
    'Acquire::http::Timeout "30";'                                                                 \
    'Acquire::https::Timeout "30";'                                                                \
    > /etc/apt/apt.conf.d/91retry-and-timeouts

RUN --mount=type=cache,target=/var/cache/apt,id=${APT_VAR_CACHE_ID},sharing=locked                 \
    --mount=type=cache,target=/var/lib/apt/lists,id=${APT_LIST_CACHE_ID},sharing=locked            \
    apt-get update &&                                                                              \
    apt-get full-upgrade -y --no-install-recommends &&                                             \
    apt-get autoremove -y --no-install-recommends &&                                               \
    apt-get autoclean -y --no-install-recommends

# Install the minimum set of packages that addAptSources.sh itself requires. Package selection
# stays with consumers, so nothing beyond that minimum is installed here.
RUN --mount=type=cache,target=/var/cache/apt,id=${APT_VAR_CACHE_ID},sharing=locked                 \
    --mount=type=cache,target=/var/lib/apt/lists,id=${APT_LIST_CACHE_ID},sharing=locked            \
    apt-get update &&                                                                              \
    apt-get install -y --no-install-recommends                                                     \
      ca-certificates curl gnupg software-properties-common

# Register all vendor apt sources (gnu, llvm, nvidia, kitware). The build context is the
# repository root, so the bind mount source resolves to this repository's own script.
RUN --mount=type=cache,target=/var/cache/apt,id=${APT_VAR_CACHE_ID},sharing=locked                 \
    --mount=type=cache,target=/var/lib/apt/lists,id=${APT_LIST_CACHE_ID},sharing=locked            \
    --mount=type=bind,src=tools/apt/addAptSources.sh,dst=/tmp/addAptSources.sh                     \
    bash /tmp/addAptSources.sh -y

# Refresh the package lists against the freshly registered sources and bake the resulting
# upgrades into the image. The list cache mount is deliberately absent here: the lists are
# written into the layer for the upgrade and then removed, so consumers inherit an upgraded
# image with the vendor sources registered and no stale lists.
RUN --mount=type=cache,target=/var/cache/apt,id=${APT_VAR_CACHE_ID},sharing=locked                 \
    apt-get update &&                                                                              \
    apt-get full-upgrade -y --no-install-recommends &&                                             \
    rm -rf /var/lib/apt/lists/*
