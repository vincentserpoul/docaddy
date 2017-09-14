FROM golang:1.9.0-alpine

ENV GOPATH /home/developer
ENV GOOS linux
ENV GOARCH=amd64

ENV CADDY_VERSION=v0.10.9

RUN apk upgrade --no-cache --available && \
    apk add --no-cache \
      bash \
      binutils \
      ca-certificates \
      file \
      git \
      libressl-dev \
      musl-dev \
      scanelf \
    && adduser -D developer

USER developer
WORKDIR /home/developer

# Buildworker has been renamed, so depend on master now
RUN go get github.com/caddyserver/builds &&\
    go get -d github.com/mholt/caddy &&\
    cd /home/developer/src/github.com/mholt/caddy &&\
    git checkout ${CADDY_VERSION}

# Note: I created these patches with...
#   git diff --no-color --no-prefix
#
# Add one or more plugins.
RUN sed -i "s/\/\/ This is where other plugins get plugged in (imported)/_ \"github.com\/BTBurke\/caddy-jwt\"\n    _ \"github.com\/caddyserver\/dnsproviders\/namecheap\"\n    _ \"github.com\/captncraig\/cors\"\n    _ \"github.com\/nicolasazrak\/caddy-cache\"\n    _ \"github.com\/tarent\/loginsrv\/caddy\"\n    _ \"github.com\/xuqingfeng\/caddy-rate-limit\"/g" /home/developer/src/github.com/mholt/caddy/caddy/caddymain/run.go

# https://github.com/niemeyer/gopkg/issues/50
RUN git config --global http.https://gopkg.in.followRedirects true

# Fetch dependencies.
RUN go get -d ./...

# Build!
RUN mkdir /home/developer/bin/
WORKDIR /home/developer/src/github.com/mholt/caddy/caddy
RUN go get -d ./...
RUN go run build.go

RUN cp /home/developer/src/github.com/mholt/caddy/caddy/caddy /home/developer/bin/

# http://www.thegeekstuff.com/2012/09/strip-command-examples/
RUN strip --strip-all /home/developer/bin/caddy

FROM alpine:3.6

RUN sed -i -e 's/dl-cdn/dl-5/g' /etc/apk/repositories && apk add --no-cache su-exec libcap openssl

RUN mkdir -p /var/www && \
    mkdir /.caddy && \
    mkdir /.ssh && \
    chown nobody:nobody /var/www /.caddy /.ssh
RUN echo StrictHostKeyChecking no >> /.ssh/ssh_config

COPY ./caddyfile /etc/caddy/
COPY ./start.sh /
RUN chmod +x ./start.sh

COPY --from=0 /home/developer/bin/caddy /usr/sbin/caddy

RUN /usr/sbin/setcap cap_net_bind_service=+ep /usr/sbin/caddy


VOLUME ["/etc/caddy", "/.caddy", "/var/www"]
EXPOSE 80 443 2015

ENTRYPOINT ["/start.sh"]

# docker build ./ --rm -t vincentserpoul/docaddy -f ./Dockerfile
# docker container stop caddy;docker container rm caddy;docker run -d \
# -p 2020:2020 \
# --name caddy \
# --read-only \
# --cap-drop all \
# -v $(pwd)/build:/home/caddy:ro \
# vincentserpoul/docaddy