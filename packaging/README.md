# packaging

打 deb 用的源码。完整流程见 [../docs/packaging.md](../docs/packaging.md)。

```bash
sudo packaging/assemble-stage.sh   # -> build/stage
packaging/build.sh                 # -> dist/fexwine-emu_<版本>_arm64.deb
```

| 路径 | 说明 |
| --- | --- |
| `debian/` | DEBIAN 控制文件（control/postinst/prerm/postrm） |
| `files/` | 装进包里的文件，按目标路径组织 |
| `fonts/` | 由文泉驿生成的 Windows 字体名别名 |
| `mkfont.py` | 重新生成 `fonts/` |
| `assemble-stage.sh` | 组装暂存树 |
| `build.sh` | 压缩并组装 deb |

字体是**生成物**，不要手工编辑：修改 `mkfont.py` 后重新运行即可（见 `fonts/README.md`）。
