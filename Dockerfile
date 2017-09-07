FROM golang:1.9.0-alpine

ENV GOPATH /home/developer
ENV CGO_ENABLED 0
ENV GOOS linux
ENV GOARCH=amd64

ENV CADDY_VERSION=v0.10.7

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

# https://github.com/mholt/caddy/issues/1843
RUN go get github.com/caddyserver/buildworker &&\
    go get -d github.com/mholt/caddy &&\
    cd /home/developer/src/github.com/mholt/caddy &&\
    git checkout ${CADDY_VERSION}

# Note: I created these patches with...
#   git diff --no-color --no-prefix
#
# Add one or more plugins.
RUN sed -i "s/\/\/ This is where other plugins get plugged in (imported)/_ \"github.com\/BTBurke\/caddy-jwt\"\n    _ \"github.com\/caddyserver\/dnsproviders\/namecheap\"\n    _ \"github.com\/captncraig\/cors\"\n    _ \"github.com\/nicolasazrak\/caddy-cache\"\n    _ \"github.com\/tarent\/loginsrv\/caddy\"\n    _ \"github.com\/xuqingfeng\/caddy-rate-limit\"/g" /home/developer/src/github.com/mholt/caddy/caddy/caddymain/run.go
RUN cat /home/developer/src/github.com/mholt/caddy/caddy/caddymain/run.go

# https://github.com/niemeyer/gopkg/issues/50
RUN git config --global http.https://gopkg.in.followRedirects true

# Fetch dependencies.
RUN go get -d ./...

# Build!
RUN mkdir /home/developer/bin/
WORKDIR /home/developer/src/github.com/mholt/caddy/caddy
RUN go run build.go

RUN cp /home/developer/src/github.com/mholt/caddy/caddy/caddy /home/developer/bin/

# http://www.thegeekstuff.com/2012/09/strip-command-examples/
RUN strip --strip-all /home/developer/bin/caddy

FROM alpine:3.6

RUN apk upgrade --no-cache --available && \
    apk add --no-cache \
      ca-certificates \
      git \
      libressl \
      openssh-client \
    && adduser -Du 1000 caddy

RUN echo "hello world" > /home/caddy/index.html
COPY ./caddyfile /etc/caddy/

RUN \
    mkdir -p /var/www && \
    chown caddy:caddy /var/www && \
    :

VOLUME ["/etc/caddy"]
VOLUME ["/var/www"]

COPY --from=0 /home/developer/bin/caddy /usr/sbin/

# Run as an unprivileged user.
USER caddy
ENTRYPOINT ["/usr/sbin/caddy"]
CMD ["-conf", "/etc/caddy/caddyfile"]


# docker build ./ --rm -t vincentserpoul/docaddy -f ./Dockerfile
# docker container stop caddy;docker container rm caddy;docker run -d \
# -p 2020:2020 \
# --name caddy \
# --read-only \
# --cap-drop all \
# -v $(pwd)/build:/home/caddy:ro \
# vincentserpoul/docaddy