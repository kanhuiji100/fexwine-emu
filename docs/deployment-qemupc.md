# 低内核环境（5.4 / QEMU 虚机）部署说明

面向银河麒麟 V10 国防版等 **内核 5.4.x、glibc 2.31** 的 aarch64 环境（常见于 QEMU 虚机：
4 核 / 7 GB 内存左右）。与 [`deployment.md`](deployment.md) 相同的部分不再重复，这里只列差异。

## 结论

* **Windows 程序（32 位 + 64 位）：可正常运行**，控制台与 GUI 均实测通过。
* x86/x86_64 **Linux** 程序：静态链接的可用；**动态链接的不可用**，原因是内核缺少
  FEX 所需的 `openat2(2)`（Linux 5.6 引入）。

## 与高内核环境的差异

| 项目 | 内核 ≥ 5.6 | 内核 5.4 |
| --- | --- | --- |
| 32/64 位 Windows 程序 | 可用 | 可用 |
| 静态 x86 Linux 程序 | 可用 | 可用 |
| 动态 x86 Linux 程序（`fex /usr/bin/ls`） | 可用 | 失败（`openat2` 不存在） |
| FEX RootFS 下载 | 可用 | 可下载，但动态程序仍受限 |

## 实测（内核 5.4.18）

| 测试项 | 结果 |
| --- | --- |
| FEX 运行 x86_64 静态程序 | exit 0 |
| FEX 运行 i386 静态程序 | exit 0 |
| `wine --version` | `wine-11.16 (Hangover)` |
| 32 位 PE `7zr.exe` | 通过，`starting FEX ... libwow64fex.dll` |
| 32 位 PE busybox-w32 | `Windows_NT <主机名> 10.0 19045 i686` |
| 64 位 PE busybox-w32 | `... x86_64`（`libarm64ecfex.dll`） |
| 32 位进程架构变量 | `ARCH=x86 W6432=ARM64` |
| 32 位 GUI：Wine 记事本中文菜单 | 通过（Xvfb 无头验证，见 `docs/images/notepad32_m2_headless.png`） |
| 32/64 位 Linux ELF 透明执行 | 通过（binfmt → FEX） |
| 动态链接 x86 Linux 程序 | 失败（内核限制） |

## 无头验证

虚机没有桌面时，可用 Xvfb 跑 GUI 自检：

```bash
sudo chroot /opt/fexemu/chroot apt-get install -y xvfb imagemagick
FEXEMU_FORCE_DISPLAY=1 DISPLAY=:99 /opt/fexemu/bin/fex-enter /bin/bash /opt/fexemu/bin/verify.sh
```

`fex-enter` 默认会在没有 X socket 时自动切换为 headless，控制台程序不会卡死。

## 性能提示

* FEX 是 JIT 模拟，首次启动比原生慢一个数量级，属正常；
* QEMU 虚机再叠加一层虚拟化，I/O 与 CPU 都更慢，初始化 Wine 前缀可能需要数分钟；
* 内存建议 ≥ 4 GB，`/opt/fexemu` 需要约 3.2 GB 磁盘。
