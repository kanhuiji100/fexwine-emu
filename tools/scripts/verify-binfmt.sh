#!/bin/bash
# 安装新包并验证 binfmt 兜底 + 透明执行
set -eu
DEB=$(ls -1t /opt/fexemu/dist/fexwine-emu_*_arm64.deb | head -1)
cp "$DEB" /tmp/
echo "=== dpkg -i ==="
dpkg -i "/tmp/$(basename "$DEB")" 2>&1 | grep -vE '^(正在处理|Processing)' | tail -12

echo "=== binfmt 状态 ==="
ls /proc/sys/fs/binfmt_misc/ | tr '\n' ' '; echo
echo "--- fstab ---"
grep -n binfmt /etc/fstab || echo "(没有)"
echo "--- systemd-binfmt ---"
systemctl is-active systemd-binfmt 2>&1

echo "=== 透明执行测试 ==="
echo "--- x86_64 ELF ---"
/opt/fexemu/share/hello-x86 2>&1 | head -2
echo "--- 32 位 PE (.exe, 走 binfmt -> fexwine) ---"
cd /opt/fexemu/share && ./7zr.exe 2>&1 | head -3
