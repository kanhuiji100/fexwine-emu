# 字体别名

这里的 10 个 `.ttf` 都是 **WenQuanYi Micro Hei** 的改名副本，由 `../mkfont.py` 生成：

| 文件 | 字体族名（Family） | 用途 |
| --- | --- | --- |
| `msyh.ttf` | 微软雅黑 | 最常见的简体中文 UI 字体名 |
| `msyh_en.ttf` | Microsoft YaHei | 英文名写法 |
| `tahoma.ttf` | Tahoma | 老式 Windows UI |
| `msshelldlg.ttf` | MS Shell Dlg | 对话框默认字体 |
| `msshelldlg2.ttf` | MS Shell Dlg 2 | 对话框默认字体 |
| `simsun.ttf` | SimSun | 宋体（英文名） |
| `songti.ttf` | 宋体 | 宋体 |
| `simhei.ttf` | SimHei | 黑体（英文名） |
| `heiti.ttf` | 黑体 | 黑体 |
| `arial.ttf` | Arial | 西文默认 |

只改了 `name` 表的 Family/Full/PostScript 名，字形、cmap、度量全部来自文泉驿。

## 为什么需要

Java(Swing) 自己枚举字体族，不认 Wine 的 `Fonts\Replacements`。程序里写
`new Font("微软雅黑", ...)` 而系统里没有这个族名时，Java 会退回不含中文的默认字体，
中文就变成方框。提供「内部名字就叫微软雅黑」的字体是唯一可靠的办法。

## 重新生成

```bash
sudo apt install fonts-wqy-microhei python3-fonttools
python3 ../mkfont.py /usr/share/fonts/truetype/wqy/wqy-microhei.ttc .
```

换成其它开源中文字体（Noto Sans CJK、文泉驿正黑等）也可以，只要字形覆盖中文。
源字体的许可必须允许再分发 —— 不要用微软/苹果等商业字体。

## 许可

字形来自 WenQuanYi Micro Hei（GPLv3 + 字体嵌入例外）。本目录的文件是它的改名副本，
同样遵循该许可。字体族名中的「微软雅黑」「宋体」等仅作为兼容性别名使用，不代表字体来源。
