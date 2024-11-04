# Smallest base image, latests stable image
# Alpine would be nice, but it's linked again musl and breaks the bitcoin core download binary
#FROM alpine:latest

FROM ubuntu:latest AS builder
ARG TARGETARCH

FROM builder AS builder_amd64
ENV ARCH=x86_64

FROM builder_${TARGETARCH} AS build

# Testing: gosu
#RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing/" >> /etc/apk/repositories \
#    && apk add --update --no-cache gnupg gosu gcompat libgcc
RUN apt update \
    && apt install -y --no-install-recommends \
    ca-certificates \
    gnupg \
    libatomic1 \
    wget \
    libboost-dev \
    libboost-filesystem-dev \
    libboost-system-dev \
    libboost-test-dev \
    libevent-dev \
    libminiupnpc-dev \
    libnatpmp-dev \
    libsqlite3-dev \
    libtool \
    libzmq3-dev \
    libboost-chrono-dev \
    libboost-thread-dev \
    libssl-dev \
    libsqlite3-dev \
    && apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ARG VERSION=v28.0
# Don't use base image's bitcoin package for a few reasons:
# 1. Would need to use ppa/latest repo for the latest release.
# 2. Some package generates /etc/bitcoin.conf on install and that's dangerous to bake in with Docker Hub.
# 3. Verifying pkg signature from main website should inspire confidence and reduce chance of surprises.
# Instead fetch, verify, and extract to Docker image
# COPY libre-relay-${VERSION}.tar.gz /tmp  # local file debugging use
RUN cd /tmp \
    && wget https://github.com/levinster82/bitcoin/releases/download/libre-relay-v28.0/libre-relay-v28.0.tar.gz \
    && tar -xzvf libre-relay-${VERSION}.tar.gz -C /opt \
    && ln -sv libre-relay-${VERSION} /opt/bitcoin \
    && /opt/bitcoin/bin/test_bitcoin --show_progress \
    && rm -v /opt/bitcoin/bin/test_bitcoin # /opt/bitcoin/bin/bitcoin-qt

FROM ubuntu:latest
LABEL maintainer="levinster82"
LABEL original-creator="Kyle Manna <kyle@kylemanna.com>"

ENTRYPOINT ["docker-entrypoint.sh"]
ENV HOME /bitcoin
EXPOSE 8332 8333
VOLUME ["/bitcoin/.bitcoin"]
WORKDIR /bitcoin

ARG GROUP_ID=1000
ARG USER_ID=1000
RUN userdel ubuntu \
    && groupadd -g ${GROUP_ID} bitcoin \
    && useradd -u ${USER_ID} -g bitcoin -d /bitcoin bitcoin

COPY --from=build /opt/ /opt/

RUN apt update \
    && apt install -y --no-install-recommends gosu libatomic1 libminiupnpc17 libnatpmp1t64 libevent-dev libzmq3-dev \
    && apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && ln -sv /opt/bitcoin/bin/* /usr/local/bin

COPY ./bin ./docker-entrypoint.sh /usr/local/bin/

CMD ["btc_oneshot"]
