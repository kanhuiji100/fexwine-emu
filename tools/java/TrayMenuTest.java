import java.awt.Color;
import java.awt.FlowLayout;
import java.awt.Font;
import java.awt.GridLayout;
import javax.swing.BorderFactory;
import javax.swing.JDialog;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.SwingUtilities;
import javax.swing.UIManager;
import javax.swing.border.EmptyBorder;

/**
 * 复刻典型的 Swing 托盘右键菜单字体用法：
 *   label.setFont(new Font("微软雅黑", 0, 14))
 * 用来验证 Wine 下按 Windows 字体名能否正常显示中文。
 */
public class TrayMenuTest {
    public static void main(String[] args) throws Exception {
        for (UIManager.LookAndFeelInfo info : UIManager.getInstalledLookAndFeels()) {
            if ("Windows".equalsIgnoreCase(info.getName())) {
                UIManager.setLookAndFeel(info.getClassName());
                break;
            }
        }
        final String[] items = {
            "\u6253\u5f00", "\u65b0\u5efa", "\u5bfc\u5165", "\u5bfc\u51fa",
            "\u641c\u7d22", "\u4e0b\u8f7d", "\u8bbe\u7f6e", "\u5e2e\u52a9",
            "\u5173\u4e8e", "\u9000\u51fa"
        };
        SwingUtilities.invokeAndWait(new Runnable() {
            public void run() {
                JDialog dialog = new JDialog();
                dialog.setUndecorated(true);
                dialog.setAlwaysOnTop(true);
                dialog.setSize(210, 380);
                JPanel inner = new JPanel(new GridLayout(items.length, 1));
                inner.setBorder(BorderFactory.createMatteBorder(0, 1, 0, 1, new Color(204, 204, 204)));
                for (String text : items) {
                    JPanel page = new JPanel(new FlowLayout(FlowLayout.LEFT, 0, 0));
                    JLabel label = new JLabel(text);
                    label.setFont(new Font("\u5fae\u8f6f\u96c5\u9ed1", 0, 14));  // 微软雅黑, PLAIN, 14
                    label.setBorder(new EmptyBorder(6, 10, 0, 0));
                    page.add(label);
                    page.setBackground(new Color(255, 255, 255));
                    page.setBorder(BorderFactory.createMatteBorder(1, 0, 0, 0, new Color(204, 204, 204)));
                    inner.add(page);
                }
                dialog.add(inner);
                dialog.setLocation(700, 180);
                dialog.setVisible(true);
            }
        });
        System.out.println("menu shown, resolved font = "
            + new Font("\u5fae\u8f6f\u96c5\u9ed1", 0, 14).getFontName());
        Thread.sleep(150000);
        System.exit(0);
    }
}
