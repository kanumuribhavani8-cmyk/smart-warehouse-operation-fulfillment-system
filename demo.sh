#!/usr/bin/env bash
set -euo pipefail
API="${1:-${API_URL:-http://127.0.0.1:4000/api}}"
API="${API%/}"

echof() { echo -e "\n==> $*"; }

echof "1) state"
curl -fsS "$API/state" | jq '.' >/dev/stdout

echof "2) allocate"
alloc=$(curl -fsS -X POST "$API/allocate")
echo "$alloc" | jq '.' >/dev/stdout
# assert orders exist
orders_count=$(echo "$alloc" | jq '.orders | length')
if [ "$orders_count" -le 0 ]; then echo "No orders returned from allocate"; exit 2; fi

echof "3) pick items (o1 p1 x3)"
pick=$(curl -fsS -X POST -H 'Content-Type: application/json' -d '{"productId":"p1","qty":3}' "$API/pick-item/o1")
echo "$pick" | jq '.' >/dev/stdout
if echo "$pick" | jq -e 'has("error")' >/dev/null; then echo "Pick failed"; exit 3; fi

echof "4) pack o1"
pack=$(curl -fsS -X POST "$API/pack/o1")
echo "$pack" | jq '.' >/dev/stdout
if echo "$pack" | jq -e 'has("error")' >/dev/null; then echo "Pack failed"; exit 4; fi

echof "5) dispatch o1"
disp=$(curl -fsS -X POST "$API/dispatch/o1")
echo "$disp" | jq '.' >/dev/stdout
if echo "$disp" | jq -e 'has("error")' >/dev/null; then echo "Dispatch failed"; exit 5; fi

echof "6) analytics"
curl -fsS "$API/analytics" | jq '.' >/dev/stdout

echof "7) damage o3 p2 qty=2 + auto-resolve"
damage=$(curl -fsS -X POST -H 'Content-Type: application/json' -d '{"orderId":"o3","productId":"p2","qty":2,"autoResolve":true}' "$API/damage")
echo "$damage" | jq '.' >/dev/stdout

echof "8) backorders"
curl -fsS "$API/backorders" | jq '.' >/dev/stdout

echof "9) done"

exit 0
