#!/bin/bash
# 在 FEX chroot 内准备 apt（挂 /proc /sys /dev），并更新索引
set -e
CH=/opt/fexemu/chroot
for d in proc sys dev dev/pts; do
  if ! mountpoint -q "$CH/$d"; then
    mount --bind "/$d" "$CH/$d"
    echo "mounted $d"
  fi
done
chroot "$CH" apt-get update -qq 2>&1 | tail -5
echo "== candidates =="
for p in xdg-utils luakit surf epiphany-browser; do
  printf '%-18s %s\n' "$p" "$(chroot "$CH" apt-cache policy $p 2>/dev/null | sed -n '2s/.*: //p')"
done
echo "== simulate installs (download size) =="
for p in luakit surf epiphany-browser; do
  echo "--- $p ---"
  chroot "$CH" apt-get -s install -y --no-install-recommends xdg-utils $p 2>/dev/null | grep -E "^(Need to get|After this|[0-9]+ upgraded|Inst )" | tail -3
done
