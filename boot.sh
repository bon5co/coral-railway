#!/bin/sh
# Railway boot for Coral Talk.
#
# Refuses to start without a strong admin password, a signing secret and the database and Redis settings. Starts the server on a
# loopback port, installs the tenant and the admin account and closes public registration (bootstrap.js, idempotent), stops it,
# and starts the real server on Railway's injected PORT.
set -u
fail() { echo "[railway] $1" >&2; exit 1; }
[ -n "${ADMIN_EMAIL:-}" ] || fail "ADMIN_EMAIL is not set"
[ -n "${ADMIN_PASSWORD:-}" ] || fail "ADMIN_PASSWORD is not set; refusing to start a comment server with no admin login"
[ "${#ADMIN_PASSWORD}" -ge 12 ] || fail "ADMIN_PASSWORD must be at least 12 characters"
SIGNING_SECRET="${SIGNING_SECRET:-}"
[ "${#SIGNING_SECRET}" -ge 24 ] || fail "SIGNING_SECRET must be set and at least 24 characters"
[ -n "${MONGO_HOST:-}" ] || fail "MONGO_HOST is not set"
[ -n "${MONGO_PASSWORD:-}" ] || fail "MONGO_PASSWORD is not set"
[ -n "${REDIS_HOST:-}" ] || fail "REDIS_HOST is not set"
[ -n "${REDIS_PASSWORD:-}" ] || fail "REDIS_PASSWORD is not set"
[ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ] || fail "RAILWAY_PUBLIC_DOMAIN is not set"
case "${PORT:=8080}" in ''|*[!0-9]*) fail "PORT must be a number, got '$PORT'";; esac
export MONGODB_URI="mongodb://root:$MONGO_PASSWORD@$MONGO_HOST:27017/coral?authSource=admin"
export REDIS_URI="redis://:$REDIS_PASSWORD@$REDIS_HOST:6379"
# ioredis defaults to IPv4 only; family 0 resolves Railway's private names over IPv4 or IPv6
export REDIS_OPTIONS='{"family":0}'
REAL_PORT="$PORT"
INTERNAL_PORT=5999
echo "[railway] Coral on :$REAL_PORT as https://$RAILWAY_PUBLIC_DOMAIN, mongo $MONGO_HOST, redis $REDIS_HOST; bootstrapping on 127.0.0.1:$INTERNAL_PORT first"
PORT="$INTERNAL_PORT" "$@" &
APP=$!
if ! node /railway-bootstrap.js "$INTERNAL_PORT"; then
  kill "$APP" 2>/dev/null
  fail "bootstrap failed, see the lines above"
fi
kill "$APP" 2>/dev/null
wait "$APP" 2>/dev/null
echo "[railway] bootstrap done, starting on :$REAL_PORT"
PORT="$REAL_PORT" exec "$@"
