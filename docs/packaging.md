# 打包说明

deb 是「把一台已装好的机器打成包」：先在一台 aarch64 机器上把 `/opt/fexemu` 环境装好并验证，
再把这些文件按目标路径放进暂存树，最后压成 deb。仓库里的 `packaging/files/` 就是这些「装进包里的文件」，
按它们在目标系统上的路径组织。

## 1. 包信息

| 项 | 值 |
| --- | --- |
| 包名 | `fexwine-emu` |
| 架构 | `arm64` |
| 依赖 | `bubblewrap` |
| 建议 | `fonts-wqy-microhei | fonts-noto-cjk` |
| 安装体积 | 约 3.2 GB（`/opt/fexemu`） |
| 版本 | `1.0-4`（当前） |

## 2. 目录

```
packaging/
├── debian/                 # DEBIAN 控制文件
│   ├── control             # 包元数据
│   ├── postinst            # 装后：同步 passwd/group、binfmt 兜底、.exe 关联、图标缓存
│   ├── prerm               # 卸前：结束沙箱内 wine
│   └── postrm              # 卸后：重启 systemd-binfmt
├── files/                  # 按目标路径组织的文件
│   ├── opt/fexemu/bin/     # fex-enter、fex-binfmt、wine-fonts.sh、verify.sh
│   ├── opt/fexemu/share/bin/fexwine-browser
│   ├── usr/local/bin/      # wine 及各种包装命令
│   ├── usr/share/applications/*.desktop
│   └── usr/lib/binfmt.d/99-fexemu.conf
├── fonts/                  # Windows 字体名别名（文泉驿字形，见 §5）
├── mkfont.py               # 生成 fonts/
├── assemble-stage.sh       # 组装暂存树
└── build.sh                # 打成 deb
```

`/opt/fexemu/chroot`（Ubuntu 根文件系统）不放进仓库 —— 它体积大且是上游发行版的产物，
构建时由构建机提供（见 §3）。

## 3. 构建

前提：一台 aarch64 构建机，已按 [`deployment.md`](deployment.md) 装好 `/opt/fexemu`，
并在 chroot 内装好 `xdg-utils` 与 `surf`（浏览器），否则打开 URL 会静默失败。

```bash
# 1) 生成暂存树（需要 sudo 读取 chroot；默认输出 build/stage）
sudo packaging/assemble-stage.sh

# 2) 打 deb（默认输出 dist/）
packaging/build.sh
```

两个脚本都支持用环境变量覆盖路径：

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `CHROOT` | `/opt/fexemu/chroot` | 源根文件系统 |
| `FEXEMU` | `/opt/fexemu` | 源环境目录（bin/share） |
| `STAGE` | `build/stage` | 暂存树 |
| `DIST` | `dist` | 输出目录 |
| `VERSION` | `1.0-4` | 版本号（写入 control 与文件名） |

`build.sh` 用 `xz -T0 -6` 压 `data.tar.xz` 并手工组装 ar 容器 —— 比 `dpkg-deb -b` 快很多
（3.2 GB 数据在多核机器上压缩时间从半小时级降到几分钟级）。

## 4. 包内容要点

* `/opt/fexemu/chroot`：Ubuntu 22.04.5 LTS arm64 根文件系统；FEX 来自 `ppa:fex-emu/fex`
  （`fex-emu-armv8.2`），Wine 来自 Hangover 11.16 的 `hangover_11.16_ubuntu2204_jammy_arm64.tar`。
* `/opt/fexemu/share`：`busybox32/64.exe`、`7zr.exe`、`hello-x86`、`busybox32` 等测试程序，
  以及字体与浏览器包装。
* `/usr/local/bin`：`wine` 是指向 `fexwine` 的软链，其余是几行的包装脚本。
* `postinst` 还会：把宿主的 `passwd`/`group`/`resolv.conf`/`localtime` 同步进 chroot；
  给 `/opt/fexemu/share` 设 1777；兜底挂载 `binfmt_misc` 并写 `/etc/fstab`；
  把 `.exe` 默认关联到 `fexwine.desktop`；刷新图标与 desktop 数据库。

## 5. 字体

`packaging/fonts/*.ttf` 是用 `mkfont.py` 从 **WenQuanYi Micro Hei** 生成的别名文件：
字形来自文泉驿，只改 name 表，使字体族名变成 `微软雅黑` / `Microsoft YaHei` / `Tahoma` /
`MS Shell Dlg` / `MS Shell Dlg 2` / `SimSun` / `宋体` / `SimHei` / `黑体` / `Arial`。

原因：Java(Swing) 自己枚举字体族，**不认** Wine 的 `Fonts\Replacements`；程序里写
`new Font("微软雅黑", ...)` 时，如果字体列表里没有这个名字，Java 会退回不含中文的默认字体，
菜单/对话框就变成方框。提供「内部名字就叫这些名字」的字体是唯一可靠的做法。

重新生成（需要 `fonttools`）：

```bash
sudo apt install fonts-wqy-microhei python3-fonttools
python3 packaging/mkfont.py /usr/share/fonts/truetype/wqy/wqy-microhei.ttc packaging/fonts
```

也可以换成别的开源中文字体（如 Noto Sans CJK），只要字形覆盖中文即可。

## 6. 安装后在目标机上的路径

| 路径 | 说明 |
| --- | --- |
| `/opt/fexemu/chroot` | 运行底座 |
| `/opt/fexemu/share` | 共享目录（1777） |
| `/usr/local/bin/wine` 等 | 命令入口 |
| `/usr/lib/binfmt.d/99-fexemu.conf` | binfmt 注册 |
| `/usr/share/applications/fexwine*.desktop` | 开始菜单项与 `.exe` 关联 |
| `/usr/share/icons/hicolor/128x128/apps/fexwine.png` | 图标 |

## 7. 发布

```bash
# 打 tag 并上传 deb 到 Release
git tag v1.0-4 && git push origin v1.0-4
gh release create v1.0-4 dist/fexwine-emu_1.0-4_arm64.deb \
  --title "fexwine-emu 1.0-4" --notes "见 CHANGELOG"
```
