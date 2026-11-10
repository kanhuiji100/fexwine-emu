#!/bin/bash
# 组装 deb 暂存树：chroot + 仓库里的脚本/字体/桌面文件 -> $STAGE
#
# 用法:
#   sudo packaging/assemble-stage.sh
#   CHROOT=/opt/fexemu/chroot FEXEMU=/opt/fexemu STAGE=build/stage sudo -E packaging/assemble-stage.sh
#
# 前提：构建机已按 docs/deployment.md 装好 /opt/fexemu（chroot 内有 FEX、Wine、surf）。
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)

CHROOT=${CHROOT:-/opt/fexemu/chroot}
FEXEMU=${FEXEMU:-/opt/fexemu}
STAGE=${STAGE:-$ROOT/build/stage}
VERSION=${VERSION:-1.0-4}

case "$STAGE" in /*) ;; *) STAGE=$ROOT/$STAGE ;; esac

[ -x "$CHROOT/usr/bin/bash" ] || { echo "chroot 未就绪: $CHROOT" >&2; exit 1; }
[ -d "$FEXEMU/share" ] || { echo "FEX 环境未就绪: $FEXEMU" >&2; exit 1; }

echo "== 1. 复制 chroot（约 3.2 GB，需要几分钟）=="
mkdir -p "$STAGE"
rm -rf "$STAGE/opt" "$STAGE/usr" "$STAGE/DEBIAN"
mkdir -p "$STAGE/opt/fexemu"
cp -a "$CHROOT" "$STAGE/opt/fexemu/chroot"

echo "== 2. 复制仓库里的包内文件 =="
cp -a "$HERE/files/." "$STAGE/"

echo "== 3. 共享目录：测试程序 + 字体 + 浏览器包装 =="
mkdir -p "$STAGE/opt/fexemu/share/bin" "$STAGE/opt/fexemu/share/fonts"
for f in busybox32 busybox64.exe busybox32.exe 7zr.exe hello-x86; do
  [ -f "$FEXEMU/share/$f" ] && cp -a "$FEXEMU/share/$f" "$STAGE/opt/fexemu/share/$f"
done
cp -a "$FEXEMU/share/bin/fexwine-browser" "$STAGE/opt/fexemu/share/bin/" 2>/dev/null || \
  cp -a "$HERE/files/opt/fexemu/share/bin/fexwine-browser" "$STAGE/opt/fexemu/share/bin/"
cp -a "$HERE/fonts/"*.ttf "$STAGE/opt/fexemu/share/fonts/"
chmod 755 "$STAGE"/opt/fexemu/share/bin/*
chmod 755 "$STAGE"/opt/fexemu/share/busybox32 "$STAGE"/opt/fexemu/share/hello-x86 2>/dev/null || true
chmod 644 "$STAGE"/opt/fexemu/share/fonts/*.ttf

echo "== 4. 文档 =="
install -m644 "$ROOT/README.md" "$STAGE/opt/fexemu/README.md"

echo "== 5. DEBIAN =="
mkdir -p "$STAGE/DEBIAN"
cp -a "$HERE/debian/." "$STAGE/DEBIAN/"
sed -i "s/^Version: .*/Version: $VERSION/" "$STAGE/DEBIAN/control"
chmod 644 "$STAGE/DEBIAN/control"
chmod 755 "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/prerm" "$STAGE/DEBIAN/postrm"

echo "== 6. 清理构建残留 =="
rm -f  "$STAGE"/opt/fexemu/chroot/var/cache/apt/archives/*.deb 2>/dev/null || true
rm -rf "$STAGE"/opt/fexemu/chroot/var/lib/apt/lists/* 2>/dev/null || true
rm -rf "$STAGE"/opt/fexemu/chroot/root/hangover 2>/dev/null || true
rm -rf "$STAGE"/opt/fexemu/chroot/tmp/* 2>/dev/null || true
rm -rf "$STAGE"/opt/fexemu/chroot/proc/* "$STAGE"/opt/fexemu/chroot/sys/* 2>/dev/null || true

echo "== 汇总 =="
du -sh "$STAGE"
echo "字体: $(ls "$STAGE/opt/fexemu/share/fonts" | wc -l) 个"
echo "chroot 内的 surf: $(ls "$STAGE/opt/fexemu/chroot/usr/bin/surf" 2>/dev/null || echo 缺失)"
echo "文件总数: $(find "$STAGE" | wc -l)"
