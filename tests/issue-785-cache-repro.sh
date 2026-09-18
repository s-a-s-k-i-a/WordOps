#!/usr/bin/env bash
set -euo pipefail

probe_dir=$(mktemp -d)
nginx_bin=${NGINX_BIN:-nginx}
trap '"$nginx_bin" -p "$probe_dir/" -c nginx.conf -s quit >/dev/null 2>&1 || true' EXIT
mkdir -p "$probe_dir/logs"

cat > "$probe_dir/nginx.conf" <<'NGINX'
worker_processes 1;
pid logs/nginx.pid;
error_log logs/error.log info;
events { worker_connections 128; }
http {
    server {
        listen 127.0.0.1:18085;
        location / {
            set $key "nginx-cache:$scheme$request_method$host$request_uri";
            set_escape_uri $escaped_key $key;
            return 200 "$escaped_key\n";
        }
        location = /bypass {
            return 200 "bypass\n";
        }
    }
}
NGINX

"$nginx_bin" -V 2>&1
"$nginx_bin" -p "$probe_dir/" -c nginx.conf -t
"$nginx_bin" -p "$probe_dir/" -c nginx.conf

set +e
curl --silent --show-error --max-time 5 -o "$probe_dir/bypass.body" -w 'bypass HTTP %{http_code}\n' 'http://127.0.0.1:18085/bypass'
curl --silent --show-error --max-time 5 -o "$probe_dir/cache.body" -w 'cache HTTP %{http_code}\n' 'http://127.0.0.1:18085/?a=1&b=2'
cache_result=$?
set -e

test "$(cat "$probe_dir/bypass.body")" = bypass
if test "$cache_result" -eq 0; then
    test -s "$probe_dir/cache.body"
    printf 'Cache response: %s\n' "$(cat "$probe_dir/cache.body")"
else
    printf 'Cache request failed with curl exit %s\n' "$cache_result"
fi
sed -n '1,120p' "$probe_dir/logs/error.log"
if test "${EXPECT_CRASH:-0}" = 1; then
    test "$cache_result" -ne 0
    grep -q 'exited on signal 11' "$probe_dir/logs/error.log"
    printf 'Expected crash reproduced.\n'
    exit 0
fi
exit "$cache_result"
