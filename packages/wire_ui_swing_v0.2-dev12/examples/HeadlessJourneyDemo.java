import org.alchemy.wireui.swing.WireSwingRuntime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class HeadlessJourneyDemo {
  public static void main(String[] args) {
    System.setProperty("java.awt.headless", "true");
    WireSwingRuntime runtime = new WireSwingRuntime();
    System.out.println(runtime.hello("demo-app", "demo-session", "desktop-1"));
  }
}
