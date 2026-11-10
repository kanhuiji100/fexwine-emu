import java.awt.Font;
import java.awt.GraphicsEnvironment;
import java.util.Locale;

/** 探测 Wine 下字体的实际解析结果（无需图形界面） */
public class FontProbe {
    public static void main(String[] args) {
        String[] names = {
            "\u5fae\u8f6f\u96c5\u9ed1",      // 微软雅黑  ← 托盘菜单使用的字体
            "Microsoft YaHei",
            "Tahoma", "MS Shell Dlg", "Arial", "SimSun", "SimHei",
            "\u5b8b\u4f53", "\u9ed1\u4f53"    // 宋体 / 黑体
        };
        for (String n : names) {
            Font f = new Font(n, Font.PLAIN, 14);
            System.out.println(String.format(Locale.ROOT,
                "REQ=%-16s -> family=%-18s fontName=%-26s CJK=%s",
                n, f.getFamily(), f.getFontName(),
                (f.canDisplay('\u4e2d') && f.canDisplay('\u6587')) ? "yes" : "NO"));
        }
        String[] fams = GraphicsEnvironment.getLocalGraphicsEnvironment()
                                          .getAvailableFontFamilyNames(Locale.CHINA);
        System.out.println("FAMILIES=" + fams.length);
        for (String s : fams) {
            System.out.println("  " + s);
        }
    }
}
