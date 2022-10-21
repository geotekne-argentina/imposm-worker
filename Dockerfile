FROM geotekne/gdal-worker:2.1.4-alpine
LABEL maintainer="geotekne.argentina@gmail.com"
ARG GOLANG_VERSION=1.14.3

RUN apk update && apk add --no-cache --upgrade bash git leveldb geos leveldb-dev geos-dev build-base postgresql go gcc bash musl-dev openssl-dev ca-certificates && update-ca-certificates && \
    wget https://dl.google.com/go/go$GOLANG_VERSION.src.tar.gz && tar -C /usr/local -xzf go$GOLANG_VERSION.src.tar.gz && \
    cd /usr/local/go/src && ./make.bash 
ENV PATH=$PATH:/usr/local/go/bin 
RUN rm go$GOLANG_VERSION.src.tar.gz && apk del go && go get github.com/omniscale/imposm3 && go install github.com/omniscale/imposm3/cmd/imposm

COPY ./scripts /scripts
COPY entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
EXPOSE 22
