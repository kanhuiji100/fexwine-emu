#!/bin/bash
# 让 Windows 程序（尤其是 Java/Swing）能按常用中文名找到含中文字形的字体。
#
# 背景：Wine 的 HKCU\Software\Wine\Fonts\Replacements 只影响 GDI 的字体替换；
# Java(Swing) 自己枚举字体族，请求 "微软雅黑" 时如果字体列表里没有这个名字，
# 就会退回到不含中文的默认字体 —— 表现为托盘右键菜单/对话框中文变成方框。
# 因此这里直接把「内部名字就叫微软雅黑/宋体/黑体/Tahoma/...」的字体文件装进
# 前缀的 C:\windows\Fonts（Wine 会自动扫描该目录），Java 就能解析到。
export WINEDEBUG=-all

FONTSRC=/opt/fexemu/share/fonts
FONTDST="$HOME/.wine/drive_c/windows/Fonts"

if [ -d "$FONTSRC" ]; then
  mkdir -p "$FONTDST" 2>/dev/null
  n=0
  for f in "$FONTSRC"/*.ttf; do
    [ -f "$f" ] || continue
    cp -f "$f" "$FONTDST"/ 2>/dev/null && n=$((n + 1))
  done
  echo "[fexwine] 已安装中文字体别名 $n 个 -> $FONTDST"
else
  echo "[fexwine] 警告: 未找到 $FONTSRC，Java 程序中文可能显示为方框" >&2
fi

# 重建字体缓存
wineserver -k 2>/dev/null
exit 0
