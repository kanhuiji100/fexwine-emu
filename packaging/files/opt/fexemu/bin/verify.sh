#!/bin/bash
# FEX-Emu + Wine 环境自检（普通用户运行即可；结果写入 ~/fexwine-verify.log）
SH=/opt/fexemu/share
exec >"$HOME/fexwine-verify.log" 2>&1
set -x
export WINEDEBUG=-all
echo "=== 环境 ==="; fexemu 2>&1 | head -8
echo "=== wine 版本 ==="; wine --version
echo "=== 32 位 PE: 7zr.exe ==="
if [ -x "$SH/7zr.exe" ]; then (cd "$SH" && ./7zr.exe | head -2); else echo "跳过"; fi
echo "=== 64 位 PE: busybox64 ==="
if [ -x "$SH/busybox64.exe" ]; then (cd "$SH" && ./busybox64.exe uname -a); else echo "跳过"; fi
echo "=== 32 位 PE: busybox32 ==="
if [ -x "$SH/busybox32.exe" ]; then (cd "$SH" && ./busybox32.exe uname -a); \
  (cd "$SH" && ./busybox32.exe sh -c 'echo ARCH=$PROCESSOR_ARCHITECTURE W6432=$PROCESSOR_ARCHITEW6432'); else echo "跳过"; fi
echo "=== x86_64 Linux ELF 透明执行 (binfmt -> FEX) ==="
if [ -x "$SH/hello-x86" ]; then "$SH/hello-x86"; else echo "跳过"; fi
echo "=== i386 Linux ELF 透明执行 (binfmt -> FEX) ==="
if [ -x "$SH/busybox32" ]; then "$SH/busybox32" uname -a; else echo "跳过"; fi
echo "=== FEX + RootFS 运行 x86_64 Linux 程序 (需内核 >= 5.6) ==="
fex /usr/bin/uname -a 2>&1 | tail -2
echo "=== binfmt_misc 注册 ==="; ls /proc/sys/fs/binfmt_misc/
echo "=== .exe 关联 ==="; xdg-mime query default application/x-ms-dos-executable 2>&1
echo "=== 完成，日志: $HOME/fexwine-verify.log ==="
