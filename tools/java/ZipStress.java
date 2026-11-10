import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.net.URL;
import java.net.URLClassLoader;
import java.util.ArrayList;
import java.util.Enumeration;
import java.util.Random;
import java.util.concurrent.atomic.AtomicLong;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;

/**
 * 压力测试：模拟 JVM 启动期「解压 jar + 加载类 + JIT」的混合负载，
 * 用来复现 FEX(ARM64EC) 下 JVM JIT 代码执行崩溃。
 *   java ZipStress <jar> <seconds> <threads>
 */
public class ZipStress {
    static final byte[] BUF = new byte[16384];
    static final AtomicLong BYTES = new AtomicLong();
    static final AtomicLong CLASSES = new AtomicLong();

    public static void main(String[] args) throws Exception {
        final File jar = new File(args[0]);
        final long seconds = args.length > 1 ? Long.parseLong(args[1]) : 60;
        final int threads = args.length > 2 ? Integer.parseInt(args[2]) : 4;
        final long deadline = System.currentTimeMillis() + seconds * 1000L;

        // 先取一份类名清单，供 ClassLoader 压力测试用
        final ArrayList<String> classNames = new ArrayList<String>();
        ZipFile zf = new ZipFile(jar);
        try {
            Enumeration<? extends ZipEntry> e = zf.entries();
            while (e.hasMoreElements() && classNames.size() < 4000) {
                String n = e.nextElement().getName();
                if (n.endsWith(".class")) {
                    classNames.add(n.substring(0, n.length() - 6).replace('/', '.'));
                }
            }
        } finally {
            zf.close();
        }
        System.out.println("entries=" + classNames.size() + " threads=" + threads + " seconds=" + seconds);

        Thread[] ts = new Thread[threads];
        for (int i = 0; i < threads; i++) {
            final int id = i;
            ts[i] = new Thread(new Runnable() {
                public void run() {
                    Random rnd = new Random(1000 + id);
                    while (System.currentTimeMillis() < deadline) {
                        // 1) 反复解压 jar 中的随机条目（Inflater / ZipFile 路径）
                        try {
                            ZipFile z = new ZipFile(jar);
                            try {
                                ArrayList<ZipEntry> list = new ArrayList<ZipEntry>();
                                Enumeration<? extends ZipEntry> e = z.entries();
                                while (e.hasMoreElements()) {
                                    ZipEntry ze = e.nextElement();
                                    if (!ze.isDirectory()) list.add(ze);
                                }
                                for (int k = 0; k < 120 && !list.isEmpty(); k++) {
                                    ZipEntry ze = list.get(rnd.nextInt(list.size()));
                                    InputStream in = z.getInputStream(ze);
                                    long tot = 0;
                                    int n;
                                    while ((n = in.read(BUF)) > 0) tot += n;
                                    in.close();
                                    BYTES.addAndGet(tot);
                                }
                            } finally {
                                z.close();
                            }
                        } catch (IOException ioe) {
                            // ignore
                        }

                        // 2) 用新的 ClassLoader 加载随机类：触发 JIT 编译新方法 + 常量池解析
                        if (!classNames.isEmpty()) {
                            try {
                                URLClassLoader cl = new URLClassLoader(new URL[] {jar.toURI().toURL()}, null);
                                try {
                                    for (int k = 0; k < 120; k++) {
                                        String cn = classNames.get(rnd.nextInt(classNames.size()));
                                        if (cn.startsWith("META-INF") || cn.indexOf("module-info") >= 0) continue;
                                        try {
                                            Class<?> c = Class.forName(cn, false, cl);
                                            c.getDeclaredMethods();
                                            c.getDeclaredFields();
                                            CLASSES.incrementAndGet();
                                        } catch (Throwable t) {
                                            // 忽略（很多类依赖缺失）
                                        }
                                    }
                                } finally {
                                    cl.close();
                                }
                            } catch (Throwable t) {
                                // ignore
                            }
                        }
                    }
                }
            }, "stress-" + i);
            ts[i].start();
        }
        for (Thread t : ts) t.join();
        System.out.println("done bytes=" + BYTES.get() + " classes=" + CLASSES.get());
    }
}
