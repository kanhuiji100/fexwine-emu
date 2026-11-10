import java.awt.Font;
import java.util.Locale;
public class FontProbe2 {
    public static void main(String[] a) {
        String[] names = { "Dialog", "SansSerif", "Serif", "Monospaced", "Segoe UI",
                           "Times New Roman", "Courier New", "Tahoma", "MS Shell Dlg",
                           "\u5fae\u8f6f\u96c5\u9ed1", "\u5b8b\u4f53" };
        for (String n : names) {
            Font f = new Font(n, Font.PLAIN, 14);
            System.out.println(String.format(Locale.ROOT, "%-16s -> %-20s CJK=%s",
                n, f.getFontName(), (f.canDisplay('\u4e2d') && f.canDisplay('\u6587')) ? "yes" : "NO"));
        }
    }
}
