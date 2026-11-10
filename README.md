# fexwine-emu

在 **aarch64（ARM64）Linux** 上运行 **Windows 32/64 位程序** 的自包含运行环境。

用 [FEX-Emu](https://fex-emu.com/) 做 x86/x86_64 指令级模拟，用 [Hangover](https://github.com/AndreRH/hangover)
（Wine 11.16）提供 Windows API：Wine 的 Unix 侧是原生 arm64，只有 Windows(PE) 代码被 FEX 翻译执行。
整套环境装在 `/opt/fexemu` 里，用 bubblewrap 用户命名空间进入沙箱，**运行时不需要 root、不需要密码**，
也不受宿主 glibc 版本限制（宿主 glibc 2.31 也能跑）。

已在银河麒麟 V10（aarch64，内核 5.4.18 / 5.10.97）、Ubuntu 22.04 上实测。

```
Windows PE (x86 / x86_64)
        │  FEX JIT（libwow64fex.dll / libarm64ecfex.dll）
        ▼
   Wine 11.16 (Hangover)  ──  ntdll/kernel32/user32…  ──►  Linux syscall
        │                                                   ▲
        └──────────── Ubuntu 22.04 arm64 chroot ────────────┘
                        （bwrap 用户命名空间）
```

## 特性

* **32 位与 64 位 Windows 程序都支持**：32 位走 WoW64 + `libwow64fex.dll`，64 位走 ARM64EC + `libarm64ecfex.dll`；
  个别程序可用 `HODLL=wowbox64.dll` 临时切到 Box64 后端。
* **开箱即用的命令**：`wine` `winecfg` `wineboot` `wineserver` `winetricks` `regedit` `notepad` `msiexec`
  `winedbg` `wineconsole` `fexshell` `fex` `fexbash` `fexemu` `fex-rootfs`，全部装在 `/usr/local/bin`。
* **透明执行**：注册了 binfmt_misc，`./app.exe` 双击/直接执行都走 Wine，x86/x86_64 Linux ELF 直接走 FEX。
  针对银河麒麟 V10 上 `binfmt_misc` 开机不挂载的问题，`postinst` 已做兜底。
* **中文正常显示**：自带一组以文泉驿微米黑为字形来源、内部名字为 `微软雅黑`/`宋体`/`SimSun`/`Tahoma`…
  的字体别名，解决 Java(Swing) 程序不认 Wine 字体替换、中文变成方框的问题。
* **能打开网页**：沙箱内自带 `surf`(WebKitGTK) 与 `fexwine-browser` 包装，
  `ShellExecute` / `Desktop.browse()` 打开 http(s) 链接不会静默失败。
* **GUI 启动器**：`fexwine-launcher` 可为任意 `.exe` 生成开始菜单/桌面快捷方式（可指定图标、参数、工作目录、前缀）。
* **无图形会话也不卡死**：入口脚本自动探测 X socket，没有显示时自动 headless；也可用
  `FEXEMU_NO_DISPLAY=1` / `FEXEMU_FORCE_DISPLAY=1 DISPLAY=:99` 显式控制。

## 安装

从 [Releases](../../releases) 下载最新的 `fexwine-emu_*_arm64.deb`：

```bash
sudo apt install ./fexwine-emu_1.0-4_arm64.deb     # 会自动装 bubblewrap
# 或
sudo dpkg -i fexwine-emu_1.0-4_arm64.deb && sudo apt -f install
```

安装后占用约 3.2 GB（`/opt/fexemu`，含 Ubuntu 22.04 arm64 根文件系统与 FEX/Wine）。
卸载：`sudo dpkg -P fexwine-emu`（各用户的 `~/.wine`、`~/.local/share/fex-emu` 需自行删除）。

## 快速开始

```bash
wine 程序.exe                  # 32/64 位自动识别；首次运行会初始化前缀（1~3 分钟）
wine ~/下载/setup.exe
cd ~/下载 && wine setup.exe    # 相对路径也可以
winecfg                       # 图形化配置
winetricks -q vcrun2019       # 安装 Windows 运行库
chmod +x app.exe && ./app.exe # 透明执行（文件管理器双击不需要执行位）
```

程序请放在 `/home`、`/tmp`、`/run`、`/media`、`/mnt`、`/opt/fexemu/share` 下 —— 只有这些目录会挂进沙箱，
`/root` 等路径在沙箱里不可见。`/opt/fexemu/share` 是 1777 的共享目录，适合放绿色软件。

## 命令一览

| 命令 | 作用 |
| --- | --- |
| `wine <exe>` | 运行 Windows 程序（`/usr/local/bin/wine` 是 `fexwine` 的软链） |
| `winecfg` / `wineboot -u` / `wineserver -k` | 配置 / 更新前缀 / 结束前缀内所有进程 |
| `winetricks` | 安装运行库（需联网） |
| `fexshell` | 进入沙箱 shell（普通用户，可用 `wine`、`winetricks`、`apt list`） |
| `fex <x86程序>` | 用 FEX 运行 x86/x86_64 **Linux** 程序（动态链接需内核 ≥ 5.6，见下） |
| `fexbash` / `fex-rootfs` / `fexemu` | FEX RootFS 内的 shell / 下载 RootFS / 查看环境状态 |
| `fexwine-launcher` | 为 `.exe` 创建开始菜单与桌面启动器 |
| `/opt/fexemu/bin/verify.sh` | 一键自检（结果写入 `~/fexwine-verify.log`） |

## 已知限制

* **动态链接的 x86 Linux 程序需要内核 ≥ 5.6**（FEX 依赖 `openat2(2)` 访问 RootFS）。
  5.4 内核上只能跑静态链接的 x86 程序；**32/64 位 Windows 程序不受此限制**。
* 沙箱内没有麒麟/Mali 的 `hisi-dpu` 驱动，日志里出现
  `libEGL warning: MESA-LOADER: failed to open hisi-dpu` 属正常现象，普通窗口程序不受影响。
* 3D 硬件加速依赖宿主 Vulkan 1.3；DXVK 放在 `/opt/fexemu/hangover/`，Mali 驱动可能不满足要求。
* `winetricks vcrun2019` 的 x64 安装包可能返回 1（Wine 兼容性问题），32 位运行库正常。
* 中文字体由文泉驿改名而来，字形与真正的微软雅黑/宋体不同，仅保证「按名字能解析到中文字形」。

## 项目结构

```
.
├── packaging/                 # 打 deb 的全部源码
│   ├── debian/                # control / postinst / prerm / postrm
│   ├── files/                 # 装进包里的脚本与桌面文件（按目标路径组织）
│   ├── fonts/                 # 由文泉驿生成的 Windows 字体名别名
│   ├── mkfont.py              # 生成上述字体别名
│   ├── assemble-stage.sh      # 组装暂存树
│   └── build.sh               # 打成 .deb
├── docs/
│   ├── deployment.md          # 原理、结构、部署与维护详解
│   ├── deployment-qemupc.md   # 内核 5.4 环境（QEMU 虚机）专项说明
│   ├── packaging.md           # 打包流程与包内容
│   └── troubleshooting.md     # 常见问题（字体/浏览器/JVM/binfmt）
└── tools/                     # 诊断脚本与 Java 压测/探针
```

## 从源码构建

需要一台 aarch64 机器（或 qemu-user 环境）与 root 权限来准备 chroot：

```bash
# 1) 准备 Ubuntu 22.04 arm64 根文件系统（略，见 docs/deployment.md）
# 2) 把 chroot、脚本装到 /opt/fexemu（略）
# 3) 组装暂存树并打包
sudo packaging/assemble-stage.sh          # 产出 build/stage
packaging/build.sh                        # 产出 dist/fexwine-emu_1.0-4_arm64.deb
```

细节见 [docs/packaging.md](docs/packaging.md)。

## 第三方组件与许可

本仓库的脚本、文档、打包代码以 MIT 许可发布（见 [LICENSE](LICENSE)）。

发布物（deb）内包含第三方组件，各自遵循其原许可：

| 组件 | 许可 |
| --- | --- |
| FEX-Emu | MIT |
| Wine / Hangover | LGPL-2.1+ |
| Ubuntu 22.04 arm64 根文件系统及各软件包 | 各自开源许可 |
| surf / WebKitGTK | MIT / LGPL |
| 文泉驿微米黑（字体字形来源） | GPLv3 + 字体嵌入例外 |

`packaging/fonts/*.ttf` 由 `packaging/mkfont.py` 从 WenQuanYi Micro Hei 生成，仅修改了 name 表，
未包含任何微软或其他商业字体文件。字体家族名（微软雅黑、宋体等）仅作为兼容性别名，
用于让按 Windows 字体名取字的程序（主要是 Java/Swing）能解析到中文字形。

## 致谢

* [FEX-Emu](https://github.com/FEX-Emu/FEX) —— x86/x86_64 用户态模拟器
* [Hangover](https://github.com/AndreRH/hangover) —— aarch64 上的 Wine + WoW64/ARM64EC 后端
* [bubblewrap](https://github.com/containers/bubblewrap) —— 无 root 沙箱
* [文泉驿](http://wenq.org/) —— 开源中文字体
