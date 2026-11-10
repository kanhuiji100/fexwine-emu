# 常见问题

## 中文显示成方框（尤其 Java/Swing 程序）

**原因**：Java 自己枚举字体族，不认 Wine 的 `HKCU\Software\Wine\Fonts\Replacements`。
程序里写 `new Font("微软雅黑", ...)`，而 Wine 的字体列表里没有这个名字时，
Java 会退回不含中文的默认字体。

**处理**：本环境在 `/opt/fexemu/share/fonts/` 放了一组「内部名字就是 Windows 字体名」的别名
（文泉驿字形），首次初始化前缀时由 `wine-fonts.sh` 复制进 `~/.wine/drive_c/windows/Fonts`。

```bash
# 重建前缀后手工补装
cp /opt/fexemu/share/fonts/*.ttf ~/.wine/drive_c/windows/Fonts/
wineserver -k
```

⚠️ **不要**用 `HKCU\Software\Wine\Fonts\Path` 指向自定义字体目录：实测会导致 Wine 字体加载堆损坏
（`free(): invalid next size`），之后**所有** Wine 进程一启动就崩。一律走前缀的 `C:\windows\Fonts`。

如果程序需要的是别的字体名，重新生成别名即可，见 [`packaging.md`](packaging.md) §5。

## 程序能启动，但主界面不出现 / 打不开网页

Wine 打开 http(s) 走 `ShellExecute → winebrowser.exe`，winebrowser 只在**沙箱内**找浏览器。
沙箱是干净的 Ubuntu chroot，没有浏览器时会打印
`err:winebrowser:launch_app could not find a suitable app to open ...` 然后**静默失败**，
调用方（Java `Desktop.browse()`、.NET）还会以为成功。

```bash
# chroot 内装浏览器
sudo chroot /opt/fexemu/chroot apt-get install -y --no-install-recommends xdg-utils surf
# 前缀里指定
wine reg add 'HKCU\Software\Wine\WineBrowser' /v Browsers /t REG_SZ \
  /d '/opt/fexemu/share/bin/fexwine-browser,xdg-open,firefox' /f
```

`fexwine-browser` 必须保留 `GDK_BACKEND=x11`，否则 GTK 可能选 Wayland 后端，
窗口创建失败（`BadWindow`）后浏览器立刻退出。

## Java 程序偶发崩溃（`hs_err_pid*.log`）

FEX/ARM64EC 上跑 JVM 会偶发 `EXCEPTION_ACCESS_VIOLATION`，崩在 **JIT 编译后**的方法里
（C1、C2 都有，方法名每次不同）。可能只是某个子进程失败，也可能直接干掉主进程。

* 复现：`tools/java/ZipStress.java`（多线程解压 + 类加载 + 反射）在 Wine+FEX 下约 1/3~1/2 的运行会崩，
  同一负载在真 x86 上不崩。
* 根因：上游 Wine ARM64EC / FEX 对 JVM 代码缓存（自修改代码、JIT 补丁）失效处理的问题，
  Hangover 11.16 仍是最新版，没有上游修复。
* 规避：`fexwine` 默认 `export JAVA_TOOL_OPTIONS="-Xint"`（解释执行，不做 JIT），
  实测压测 0/5 崩溃，代价是启动慢约 1/3。
* 无效的尝试：`-XX:-TieredCompilation`、`-Xshare:off`、`FEX_DISABLE_VIXL_INDIRECT_RUNTIME_CALLS=1`。
* 想要性能：`JAVA_TOOL_OPTIONS="-XX:+TieredCompilation" wine 程序.exe`（崩溃概率会回来）。

## `./app.exe` 提示「无法执行」/ 透明执行失效

`.exe` 双击走 `.desktop` 关联，不依赖 binfmt；而 `./app.exe`、`./hello-x86` 这类**透明执行**
依赖 binfmt_misc。部分发行版（银河麒麟 V10）的 `proc-sys-fs-binfmt_misc.automount` 是
`static/inactive`，开机不挂载，`systemd-binfmt` 会静默失败。

```bash
sudo mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc
sudo systemctl restart systemd-binfmt
ls /proc/sys/fs/binfmt_misc/     # 应有 fex-x86_64 fex-i386 fexwine
```

`postinst` 已做兜底（`modprobe` + 手动挂载 + 写 `/etc/fstab` + 自检），一般不需要手工处理。

## 没有图形界面时卡住

`fex-enter` 会探测 X socket，没有可用显示时自动 headless。也可以显式控制：

```bash
FEXEMU_NO_DISPLAY=1 wine 程序.exe                       # 强制无显示
FEXEMU_FORCE_DISPLAY=1 DISPLAY=:99 wine 程序.exe        # 指定显示（需 Xvfb 等）
```

## `libEGL warning: MESA-LOADER: failed to open hisi-dpu`

沙箱内没有麒麟 Mali 图形驱动，属正常现象，普通窗口程序不受影响。
需要 OpenGL/3D 时把宿主的 Mesa/DRI 绑定进沙箱，或使用宿主 Vulkan（DXVK 需 Vulkan 1.3）。

## 首次运行很慢

第一次 `wine` 会初始化 `~/.wine` 前缀并安装字体，1~3 分钟属正常；之后启动快得多。
FEX 是 JIT 模拟，整体比原生慢一个数量级。

## 动态链接的 x86 Linux 程序跑不起来

FEX 运行动态链接程序需要 `openat2(2)`，即内核 ≥ 5.6。5.4 内核上只能跑静态链接程序。
Windows 程序不受影响。见 [`deployment-qemupc.md`](deployment-qemupc.md)。
