#!/bin/sh
# Smoke test for the minio release image, with the mc release image it
# bundles.
#
#   MINIO_TAG=... MINIO_COMMIT=... MC_TAG=... MC_COMMIT=... \
#     buildscripts/image-smoke.sh <minio-image> <mc-image>
#
# The checks follow how the consuming stacks use the images:
#
#   1. minio and mc (both the mc image's and the one bundled in the server
#      image) print the expected release and commit.
#   2. The server starts from `server /data` arguments, as root and as
#      UID 1000 (the Kubernetes examples' securityContext), and the compose
#      healthcheck `mc ready local` and GET /minio/health/live answer.
#   3. The mc image creates a bucket through `/bin/sh -c`, as root and as
#      UID 1000 with HOME=/tmp, as the compose and Job init steps do.
#   4. Conditional writes: PUT If-None-Match: * creates the key once and
#      answers 412 the second time with the object unchanged; PUT If-Match
#      with the current ETag applies and with a stale one answers 412.
#
# Needs docker (DOCKER=podman works) and curl 7.75 or later (--aws-sigv4).
set -eu

: "${MINIO_TAG:?}" "${MINIO_COMMIT:?}" "${MC_TAG:?}" "${MC_COMMIT:?}"
minio_image=$1
mc_image=$2
docker=${DOCKER:-docker}
port=${SMOKE_PORT:-19000}
name=minio-smoke-$$

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

cleanup() {
	$docker rm -f "$name" "$name-nonroot" >/dev/null 2>&1 || true
	$docker network rm "$name" >/dev/null 2>&1 || true
}
trap cleanup EXIT

expect_version() { # <label> <want> <output>
	case $3 in
	*"$2"*) echo "ok: $1: $2" ;;
	*) fail "$1 printed: $3" ;;
	esac
}

expect_version "minio" "minio version $MINIO_TAG (commit-id=$MINIO_COMMIT)" \
	"$($docker run --rm --entrypoint minio "$minio_image" --version)"
expect_version "mc in the minio image" "mc version $MC_TAG (commit-id=$MC_COMMIT)" \
	"$($docker run --rm --entrypoint mc "$minio_image" --version)"
expect_version "mc" "mc version $MC_TAG (commit-id=$MC_COMMIT)" \
	"$($docker run --rm "$mc_image" --version)"

wait_ready() { # <container>
	i=0
	until $docker exec "$1" mc ready local >/dev/null 2>&1; do
		i=$((i + 1))
		[ "$i" -lt 60 ] || fail "$1: mc ready local never succeeded"
		sleep 1
	done
	echo "ok: $1: mc ready local"
}

# As UID 1000 on a world-writable tmpfs, like the Kubernetes examples'
# runAsUser 1000 with an emptyDir. The bundled mc needs MC_CONFIG_DIR here.
$docker run -d --name "$name-nonroot" --user 1000:1000 --tmpfs /data:rw,mode=1777 \
	-e MINIO_ROOT_USER=minioadmin -e MINIO_ROOT_PASSWORD=minioadmin \
	"$minio_image" server /data >/dev/null
wait_ready "$name-nonroot"
$docker rm -f "$name-nonroot" >/dev/null

$docker network create "$name" >/dev/null
$docker run -d --name "$name" --network "$name" -p "127.0.0.1:$port:9000" \
	-e MINIO_ROOT_USER=minioadmin -e MINIO_ROOT_PASSWORD=minioadmin \
	"$minio_image" server /data --console-address :9001 >/dev/null
wait_ready "$name"
curl -fsS -o /dev/null "http://127.0.0.1:$port/minio/health/live" || fail "GET /minio/health/live"
echo "ok: GET /minio/health/live"

init='mc alias set local http://'"$name"':9000 minioadmin minioadmin && mc mb --ignore-existing local/smoke'
$docker run --rm --network "$name" --entrypoint /bin/sh "$mc_image" -c "$init" >/dev/null ||
	fail "mc init as root"
$docker run --rm --network "$name" --user 1000:1000 -e HOME=/tmp -e MC_CONFIG_DIR=/tmp/.mc \
	--entrypoint /bin/sh "$mc_image" -c "$init" >/dev/null || fail "mc init as UID 1000"
echo "ok: bucket created by the mc image through /bin/sh -c, as root and as UID 1000"

url="http://127.0.0.1:$port/smoke/conditional"
s3() {
	curl -sS --aws-sigv4 "aws:amz:us-east-1:s3" --user minioadmin:minioadmin \
		-H "x-amz-content-sha256: UNSIGNED-PAYLOAD" "$@"
}
put() { # <body> <header>; prints the status code
	s3 -o /dev/null -w '%{http_code}' -X PUT -H "$2" --data-binary "$1" "$url"
}
expect_code() { # <label> <want> <got>
	[ "$3" = "$2" ] || fail "$1: status $3, want $2"
	echo "ok: $1: $3"
}
expect_body() { # <want>
	got=$(s3 "$url")
	[ "$got" = "$1" ] || fail "object holds '$got', want '$1'"
	echo "ok: object holds '$1'"
}

expect_code "PUT If-None-Match: * on an absent key" 200 "$(put first 'If-None-Match: *')"
expect_code "PUT If-None-Match: * on an existing key" 412 "$(put second 'If-None-Match: *')"
expect_body first
etag=$(s3 -o /dev/null -D - -I "$url" | tr -d '\r' | sed -n 's/^[Ee][Tt][Aa][Gg]: *//p')
[ -n "$etag" ] || fail "HEAD returned no ETag"
expect_code "PUT If-Match: <current ETag>" 200 "$(put third "If-Match: $etag")"
expect_code "PUT If-Match: <stale ETag>" 412 "$(put fourth "If-Match: $etag")"
expect_body third

echo "smoke: all checks passed for $minio_image and $mc_image"
