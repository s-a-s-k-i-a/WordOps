#!/usr/bin/env bash
set -euo pipefail

nginx_bin=${NGINX_BIN:-nginx}
repo_dir=$(cd "$(dirname "$0")/.." && pwd)
probe_dir=$(mktemp -d)
mkdir -p "$probe_dir/logs"
trap '"$nginx_bin" -p "$probe_dir/" -c "$repo_dir/tests/issue-785-map.conf" -s quit >/dev/null 2>&1 || true' EXIT

"$nginx_bin" -p "$probe_dir/" -c "$repo_dir/tests/issue-785-map.conf" -t
"$nginx_bin" -p "$probe_dir/" -c "$repo_dir/tests/issue-785-map.conf"

check() {
    label=$1
    expected=$2
    shift 2
    actual=$(curl --silent --show-error --fail --max-time 5 "$@")
    printf '%s: skip_cache=%s (expected %s)\n' "$label" "$actual" "$expected"
    test "$actual" = "$expected"
}

check anonymous-home 0 'http://127.0.0.1:18086/'
check anonymous-page 0 'http://127.0.0.1:18086/product/example/'
check cart 1 'http://127.0.0.1:18086/cart/'
check checkout 1 'http://127.0.0.1:18086/checkout/'
check account 1 'http://127.0.0.1:18086/my-account/'
check cart-cookie 1 -H 'Cookie: woocommerce_items_in_cart=1' 'http://127.0.0.1:18086/product/example/'
check logged-in-cookie 1 -H 'Cookie: wordpress_logged_in_example=1' 'http://127.0.0.1:18086/'
check authorization 1 -H 'Authorization: Basic synthetic' 'http://127.0.0.1:18086/'
check woo-ajax 1 'http://127.0.0.1:18086/?wc-ajax=update_order_review'
