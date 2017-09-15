#!/bin/sh

export ENV_SYSTEM=$1

ulimit -n 1048576
su-exec nobody:nobody /usr/sbin/caddy -agree=true -conf=/etc/caddy/caddyfile$ENV_SYSTEM