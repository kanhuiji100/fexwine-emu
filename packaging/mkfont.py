#!/usr/bin/env python3
"""从文泉驿字体生成「Windows 常见字体名」别名字体。

为什么需要别名：Wine 的 HKCU\\Software\\Wine\\Fonts\\Replacements 只影响 GDI 的
字体替换；Java(Swing) 自己枚举字体族，请求 "微软雅黑"/"宋体" 时如果字体列表里
没有这个名字，就会退回到不含中文的默认字体 —— 表现为托盘菜单/对话框中文变方框。

做法：以 WenQuanYi Micro Hei（GPLv3 + 字体嵌入例外，可自由再分发）为字形来源，
只改 name 表里的 Family/Full/PostScript 名，生成 Java/Wine 认得的 Windows 字体名。

用法：
    python3 mkfont.py [源字体.ttc|.ttf] [输出目录]
默认源：/usr/share/fonts/truetype/wqy/wqy-microhei.ttc，默认输出：./fonts
需要 fonttools（pip install fonttools）。
"""
import os
import sys

from fontTools.ttLib import TTFont

# 输出名: (Family 名, PostScript 名)
TARGETS = [
    ("msyh",        "\u5fae\u8f6f\u96c5\u9ed1", "MicrosoftYaHei"),   # 微软雅黑
    ("msyh_en",     "Microsoft YaHei",          "MicrosoftYaHeiUI"),
    ("tahoma",      "Tahoma",                   "TahomaCN"),
    ("msshelldlg",  "MS Shell Dlg",             "MSShellDlgCN"),
    ("msshelldlg2", "MS Shell Dlg 2",           "MSShellDlg2CN"),
    ("simsun",      "SimSun",                   "SimSunCN"),
    ("songti",      "\u5b8b\u4f53",             "SongtiCN"),          # 宋体
    ("simhei",      "SimHei",                   "SimHeiCN"),
    ("heiti",       "\u9ed1\u4f53",             "HeitiCN"),           # 黑体
    ("arial",       "Arial",                    "ArialCN"),
]

DEFAULT_SRC = "/usr/share/fonts/truetype/wqy/wqy-microhei.ttc"


def rename(src, dst, family, psname):
    f = TTFont(src, fontNumber=0) if src.lower().endswith(".ttc") else TTFont(src)
    name = f["name"]
    name.names = [r for r in name.names if r.nameID not in (1, 2, 3, 4, 6, 16, 17)]
    for lang in (0x409, 0x804):          # en-US / zh-CN
        name.setName(family, 1, 3, 1, lang)              # Family
        name.setName("Regular", 2, 3, 1, lang)           # Subfamily
        name.setName(family + " Regular", 3, 3, 1, lang)  # Unique ID
        name.setName(family, 4, 3, 1, lang)              # Full name
        name.setName(psname, 6, 3, 1, lang)              # PostScript name
        name.setName(family, 16, 3, 1, lang)             # Typographic family
        name.setName("Regular", 17, 3, 1, lang)
    f.save(dst)
    return dst


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SRC
    outdir = sys.argv[2] if len(sys.argv) > 2 else os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "fonts")
    if not os.path.exists(src):
        sys.exit("找不到源字体: %s" % src)
    os.makedirs(outdir, exist_ok=True)
    for key, family, ps in TARGETS:
        p = rename(src, os.path.join(outdir, key + ".ttf"), family, ps)
        print("wrote %-34s family=%s" % (p, family))


if __name__ == "__main__":
    main()
