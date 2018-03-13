FROM alpine:latest

EXPOSE 3001
ENV GOPATH=/tmp/go

RUN set -ex \
    && apk add --update --no-cache bash \
    && apk add --update --no-cache --virtual .build-deps \
        rsync \
        git \
        go \
        build-base \
    && cd /tmp \
    && { go get -d github.com/github/orchestrator-agent ; : ; }
    && find $GOPATH/src/ -name *.go \
    && bash -x build.sh -b \
    && rsync -av $(find /tmp/orchestrator-agent-release -type d -name orchestrator-agent -maxdepth 2)/ / \
    && cd / \
    && apk del .build-deps \
    && rm -rf /tmp/*

WORKDIR /usr/local/orchestrator-agent
ADD docker/entrypoint.sh /entrypoint.sh
CMD /entrypoint.sh
