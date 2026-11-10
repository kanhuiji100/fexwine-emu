# tools

诊断与压测工具，用于定位 FEX/Wine 环境里的问题。均为独立小程序，不参与打包。

## java/

在 Wine + FEX 下跑的 Java 探针（用 chroot 内的 `java.exe` 执行，或编译后放 `/opt/fexemu/share`）：

| 文件 | 作用 |
| --- | --- |
| `ZipStress.java` | 多线程解压 + 类加载 + 反射，压测 JVM JIT 崩溃（见 `docs/troubleshooting.md`） |
| `FontProbe.java` / `FontProbe2.java` | 枚举 Java 可见字体族，确认 `微软雅黑`/`宋体` 等是否被解析到 |
| `FontTest.java` | 用指定字体名渲染中文，输出图像，判断是否缺字形 |
| `TrayMenuTest.java` / `TrayMenuFrame.java` | Swing 托盘/右键菜单复现工具，验证中文菜单显示 |

编译（chroot 内已带 JDK 时可省去 `-cp`）：

```bash
# 宿主机有 javac 时
javac -encoding UTF-8 -d tools/java/out tools/java/*.java
cp -a tools/java/out /opt/fexemu/share/
wine java.exe -cp 'Z:\opt\fexemu\share\out' ZipStress
```

## scripts/

| 文件 | 作用 |
| --- | --- |
| `verify-binfmt.sh` | 安装最新 deb 后检查 binfmt 兜底与透明执行（需 root） |
| `setup-chroot.sh` | 给 chroot 挂 `/proc` `/sys` `/dev` 并 `apt-get update`（需 root） |

`verify-binfmt.sh` 默认从 `/opt/fexemu/dist/` 取最新的 deb；如路径不同，改脚本开头的 `DEB=` 一行。

## 环境自检

安装后随手验证，直接用包内的脚本即可（普通用户）：

```bash
/opt/fexemu/bin/verify.sh          # 结果写入 ~/fexwine-verify.log
```
