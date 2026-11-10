# 部署与原理详解

本文说明 fexwine-emu 的结构、安装后的行为、验证结果与日常维护。
面向银河麒麟 V10 / Ubuntu 22.04 等 aarch64 发行版。

## 1. 为什么需要 chroot

宿主系统的 glibc 往往低于 FEX 与 Hangover 官方包的要求（例如麒麟 V10 是 glibc 2.31，
而官方包要求 ≥ 2.34/2.35）。因此本环境自带一套 **Ubuntu 22.04.5 LTS (arm64) 根文件系统**，
用 bubblewrap 的用户命名空间把当前用户「切」进去：

* 不需要 root、不需要密码、不需要 setuid；
* 宿主只提供内核、显示、家目录与少量目录；
* 升级 Wine/FEX 只影响这套 chroot，不污染宿主。

## 2. 目录结构

| 路径 | 说明 |
| --- | --- |
| `/opt/fexemu/chroot` | Ubuntu 22.04 arm64 根文件系统，FEX 与 Wine 安装在此 |
| `/opt/fexemu/bin/fex-enter` | 沙箱入口（bwrap）：挂载 `/home` `/tmp` `/run` `/media` `/mnt` `/opt/fexemu/share`，绑定 `/dev` `/proc`，只读 `/sys` |
| `/opt/fexemu/bin/fex-binfmt` | binfmt_misc 调用的包装（把 x86 ELF 交给 FEX） |
| `/opt/fexemu/share` | 宿主机与沙箱共享目录（1777），放 `.exe`、测试程序 |
| `/opt/fexemu/share/fonts` | Windows 字体名别名（文泉驿字形） |
| `/opt/fexemu/share/bin/fexwine-browser` | 沙箱内打开 URL 的包装（`GDK_BACKEND=x11` + surf） |
| `~/.wine` | 每个用户自己的 Wine 前缀（首次运行创建，可写、持久） |
| `~/.local/share/fex-emu/RootFS/Ubuntu_24_04` | FEX 的 x86_64 RootFS（运行 x86 Linux 程序用） |
| `/usr/lib/binfmt.d/99-fexemu.conf` | binfmt 注册：`fex-x86_64`、`fex-i386`、`fexwine` |

模拟后端（均来自 Hangover 11.16）：

* `libarm64ecfex.dll` —— 64 位 x86 Windows 程序（ARM64EC + FEX JIT）
* `libwow64fex.dll` —— 32 位 x86 Windows 程序（WoW64 + FEX JIT，默认）
* `wowbox64.dll` —— 备选 Box64 后端

## 3. 显示探测

`fex-enter` 只有在确认「X socket 存在」且「认证可用」时才设置 `DISPLAY`，否则置空（headless）。
这样可以避免在没有图形会话（ssh、开机脚本、CI）时 Wine 卡在 `wine.inf` 安装阶段。

| 变量 | 作用 |
| --- | --- |
| `FEXEMU_NO_DISPLAY=1` | 强制无显示 |
| `FEXEMU_FORCE_DISPLAY=1 DISPLAY=:99` | 强制使用指定显示（如 Xvfb） |
| `FEXEMU_CHROOT=/path` | 使用其它 chroot 路径（调试用） |

## 4. 文件可见性

沙箱只挂载：`/home`、`/tmp`、`/run`、`/media`、`/mnt`、`/opt/fexemu/share`、`/dev`、`/proc`、`/sys`（只读）。

* 待运行的程序放这些目录下，推荐 `~/下载` 或 `/opt/fexemu/share`；
* 工作目录不在上述范围内时，入口脚本会回退到 `$HOME`；
* 直接 `./app.exe` 需要执行位（`chmod +x`），文件管理器双击走 `.desktop` 关联，不需要。

## 5. 验证结果（2026-10）

| 测试项 | 结果 |
| --- | --- |
| FEX 运行 x86_64 静态程序（内核 5.4.18 与 5.10.97） | 通过 |
| FEX 运行 i386 静态程序 | 通过 |
| `wine --version` | `wine-11.16 (Hangover)` |
| 32 位 PE `7zr.exe`（7-Zip 26.04 x86） | 通过，日志 `starting FEX ... libwow64fex.dll` |
| 64 位 PE busybox-w32 `uname -a` | `Windows_NT <主机名> 10.0 19045 x86_64`（`libarm64ecfex.dll`） |
| 32 位 PE busybox-w32 | `... i686`，`PROCESSOR_ARCHITECTURE=x86`、`PROCESSOR_ARCHITEW6432=ARM64` |
| 32 位 GUI：Wine 记事本中文菜单 | 通过（截图对应 `docs/images/notepad32_fonts.png`） |
| x86_64 / i386 Linux ELF 透明执行 | 通过（binfmt → FEX） |
| 动态链接 x86 Linux 程序（内核 5.4） | 不可用，需要内核 ≥ 5.6（见 §7） |

## 6. 打开网页 / URL

Wine 打开 http(s) 链接走 `ShellExecute → winebrowser.exe`，而 winebrowser 只在**沙箱内**找
`xdg-open` / `firefox` / `konqueror`。沙箱是干净的 Ubuntu chroot，默认没有浏览器，于是：

```
err:winebrowser:launch_app could not find a suitable app to open L"http://..."
```

更麻烦的是 winebrowser 进程本身启动成功，**调用方（Java `Desktop.browse()`、.NET、ShellExecute）
会认为成功**，不抛异常也不弹框。镜像里已经装了 `surf`(WebKitGTK)，并用
`/opt/fexemu/share/bin/fexwine-browser` 包装，`wine` 首次初始化前缀时会把
`HKCU\Software\Wine\WineBrowser\Browsers` 指过去。

重建前缀后如遇链接打不开：

```bash
# 1) chroot 内确实有浏览器
sudo chroot /opt/fexemu/chroot apt-get install -y --no-install-recommends xdg-utils surf
# 2) 前缀里指定浏览器
wine reg add 'HKCU\Software\Wine\WineBrowser' /v Browsers /t REG_SZ \
  /d '/opt/fexemu/share/bin/fexwine-browser,xdg-open,firefox' /f
```

`fexwine-browser` 里必须保留 `GDK_BACKEND=x11`：沙箱的 `XDG_RUNTIME_DIR` 指向宿主 Wayland，
不指定时 GTK 可能选 Wayland 后端，窗口创建失败（`BadWindow`）后浏览器立即退出。

## 7. 内核要求

* **运行 Windows 程序**：内核 ≥ 5.4 即可（32/64 位、控制台、GUI 均验证过）。
* **运行 x86/x86_64 Linux 程序**：FEX 需要 `openat2(2)`（Linux **5.6+**）访问 RootFS。
  5.4 内核上只能跑静态链接的 x86 程序；内核 ≥ 5.6（建议 ≥ 5.15）时先 `fex-rootfs` 下载 RootFS，
  之后动态链接程序也可用。

## 8. 维护

```bash
# 进入沙箱 shell（普通用户）
fexshell

# 在沙箱内安装软件（需要 root；chroot 里没有 /proc 时先挂）
sudo mount --bind /proc /opt/fexemu/chroot/proc
sudo mount --bind /sys  /opt/fexemu/chroot/sys
sudo mount --bind /dev  /opt/fexemu/chroot/dev
sudo mount --bind /dev/pts /opt/fexemu/chroot/dev/pts
sudo chroot /opt/fexemu/chroot apt-get update
sudo chroot /opt/fexemu/chroot apt-get install -y <软件包>

# 升级 FEX
sudo chroot /opt/fexemu/chroot apt-get update
sudo chroot /opt/fexemu/chroot apt-get install --only-upgrade fex-emu-armv8.2

# 重建 Wine 前缀（中文字体会随初始化重新安装）
rm -rf ~/.wine && wine wineboot -u
```

升级 Hangover：从 <https://github.com/AndreRH/hangover/releases> 下载新的
`*_ubuntu2204_jammy_arm64.tar`，解包后把 deb 放进 `chroot/root/hangover/`，再
`sudo chroot /opt/fexemu/chroot apt-get install -y /root/hangover/*.deb`。

## 9. 卸载

```bash
sudo dpkg -P fexwine-emu
sudo rm -rf /opt/fexemu
rm -rf ~/.wine ~/.local/share/fex-emu
```

`postrm` 会重载 systemd 并重启 `systemd-binfmt`；`/etc/fstab` 里由 `postinst` 追加的
`binfmt_misc` 一行可手工删掉。

## 10. 已知现象

* `libEGL warning: MESA-LOADER: failed to open hisi-dpu` —— 沙箱内没有麒麟 Mali 驱动，正常现象。
* `wine: created the configuration directory` 首次运行时出现，属正常初始化。
* 若 32 位程序在 FEX 下异常，可 `HODLL=wowbox64.dll wine app.exe` 切 Box64 试试。
