import java.awt.Font;
import java.awt.GridLayout;
import java.util.Locale;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.SwingUtilities;

/** 验证 Wine 下中文/菜单字体的解析与渲染（配合截图使用） */
public class FontTest {
    public static void main(String[] args) throws Exception {
        final String[] names = {
            "\u5fae\u8f6f\u96c5\u9ed1",      // 微软雅黑  (托盘菜单实际使用的字体)
            "Microsoft YaHei",
            "Tahoma", "MS Shell Dlg", "Arial", "SimSun",
            "\u5b8b\u4f53", "\u9ed1\u4f53", "SimHei"    // 宋体 黑体
        };
        final String sample = "\u4e2d\u6587\u83dc\u5355\u6d4b\u8bd5 ABC 123 \u4e0b\u8f7d\u7ba1\u7406";
        for (String n : names) {
            Font f = new Font(n, Font.PLAIN, 16);
            System.out.println(String.format(Locale.ROOT,
                "%-20s -> family=%-22s name=%-24s canDisplay('\\u4e2d')=%s",
                n, f.getFamily(), f.getFontName(), f.canDisplay('\u4e2d')));
        }
        SwingUtilities.invokeAndWait(new Runnable() {
            public void run() {
                JFrame fr = new JFrame("FONT TEST - Swing menu font");
                JPanel p = new JPanel(new GridLayout(0, 1, 4, 4));
                for (String n : names) {
                    JLabel l = new JLabel(n + " : " + sample);
                    l.setFont(new Font(n, Font.PLAIN, 16));
                    p.add(l);
                }
                JLabel l2 = new JLabel("Windows L&F 默认字体 : " + sample);
                l2.setFont(new Font(null, Font.PLAIN, 16));
                p.add(l2);
                fr.setContentPane(p);
                fr.pack();
                fr.setLocation(120, 120);
                fr.setAlwaysOnTop(true);
                fr.setVisible(true);
            }
        });
        System.out.println("window shown, sleeping 120s");
        Thread.sleep(120000);
        System.exit(0);
    }
}
