#!/bin/bash
# 把 $STAGE 打成 deb：control.tar.gz + data.tar.xz + ar 容器
#
# 用法:
#   packaging/build.sh
#   STAGE=build/stage DIST=dist VERSION=1.0-4 packaging/build.sh
#
# 用 xz -T0 代替 dpkg-deb 的单线程压缩，3.2 GB 数据在多核机器上几分钟即可完成。
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)

STAGE=${STAGE:-$ROOT/build/stage}
DIST=${DIST:-$ROOT/dist}
VERSION=${VERSION:-1.0-4}

case "$STAGE" in /*) ;; *) STAGE=$ROOT/$STAGE ;; esac
case "$DIST"  in /*) ;; *) DIST=$ROOT/$DIST ;; esac

[ -d "$STAGE/DEBIAN" ] || { echo "暂存树不完整: $STAGE/DEBIAN 不存在" >&2; exit 1; }
[ -d "$STAGE/opt/fexemu/chroot" ] || { echo "暂存树里没有 chroot: $STAGE/opt/fexemu/chroot" >&2; exit 1; }
command -v xz >/dev/null || { echo "缺少 xz（apt install xz-utils）" >&2; exit 1; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$DIST"

echo "== 1. debian-binary =="
printf '2.0\n' > "$WORK/debian-binary"

echo "== 2. control.tar.gz =="
tar --numeric-owner --owner=0 --group=0 -C "$STAGE/DEBIAN" -czf "$WORK/control.tar.gz" .

echo "== 3. data.tar.xz（多线程压缩，较慢）=="
time tar --numeric-owner --owner=0 --group=0 --exclude=./DEBIAN -C "$STAGE" -cf - . \
  | xz -T0 -6 -c > "$WORK/data.tar.xz"

echo "== 4. 组装 ar =="
DEB=$DIST/fexwine-emu_${VERSION}_arm64.deb
python3 - "$WORK" "$DEB" <<'PY'
import os, sys
work, dst = sys.argv[1], sys.argv[2]
names = ['debian-binary', 'control.tar.gz', 'data.tar.xz']
with open(dst, 'wb') as out:
    out.write(b'!<arch>\n')
    for name in names:
        path = os.path.join(work, name)
        data = open(path, 'rb').read()
        hdr = (name.ljust(16) + str(int(os.path.getmtime(path))).ljust(12)
               + '0'.ljust(6) + '0'.ljust(6) + '100644'.ljust(8)
               + str(len(data)).ljust(10) + '`\n').encode()
        assert len(hdr) == 60, len(hdr)
        out.write(hdr)
        out.write(data)
        if len(data) % 2:
            out.write(b'\n')
print('written', dst)
PY

echo "== 5. 校验 =="
dpkg-deb -I "$DEB" | sed -n '1,20p'
echo "文件数: $(dpkg-deb -c "$DEB" | wc -l)"
ls -lh "$DEB"
sha256sum "$DEB" | tee "$DEB.sha256"
