namespace Knotes {

    /**
     * Minimal implementation of the StatusNotifierItem D-Bus protocol
     * (KDE's System Tray Protocol, also used by GNOME AppIndicator).
     *
     * This is the modern Wayland-compatible tray icon standard.
     * Uses Cairo to generate the icon pixmap — no icon theme dependency.
     *
     * IMPORTANT: In Vala's D-Bus binding, property getters are detected
     * ONLY by the `get_PropertyName` method naming convention.
     * The [DBus(name = "...")] annotation on a getter would turn it
     * into a D-Bus METHOD instead of a PROPERTY, which would break
     * SNI's property-based protocol. So property getters have NO
     * [DBus(name = "...")] annotation — the naming is enough.
     */
    [DBus(name = "org.kde.StatusNotifierItem")]
    public class StatusNotifierItemImpl : GLib.Object {
        private const int ICON_SIZE = 24;

        public signal void toggle_window();
        public signal void quit_app();

        // --- D-Bus Properties ---
        // Vala convention: get_PropertyName → D-Bus property "PropertyName"
        // NO [DBus(name = ...)] annotation on these! That would make them
        // D-Bus methods instead of properties.

        public string get_Category() throws GLib.Error {
            return "ApplicationStatus";
        }

        public string get_Id() throws GLib.Error {
            return "knotes";
        }

        public string get_Title() throws GLib.Error {
            return "Knotes";
        }

        public string get_Status() throws GLib.Error {
            return "Active";
        }

        public int32 get_WindowId() throws GLib.Error {
            return 0;
        }

        public string get_IconName() throws GLib.Error {
            return "com.knotes.app";
        }

        public string[] get_IconThemePath() throws GLib.Error {
            return {};
        }

        public bool get_ItemIsMenu() throws GLib.Error {
            return false;
        }

        public string get_Menu() throws GLib.Error {
            return "/com/knotes/app/menu";
        }

        /**
         * Provides the icon as raw ARGB32 pixel data so the tray
         * implementation never needs to look up a themed icon file.
         * This is what makes the icon appear reliably on all DEs.
         *
         * SNI spec format: a(iiibay)
         *   struct { int32 width, int32 height, int32 rowstride,
         *            bool has_alpha, array<byte> data }
         */
        public Variant get_IconPixmap() throws GLib.Error {
            return generate_pixmap_variant(ICON_SIZE);
        }

        public Variant get_ToolTip() throws GLib.Error {
            var builder = new VariantBuilder(new VariantType("(sa{sv}ss)"));
            builder.add("s", "icon");
            var dict_builder = new VariantBuilder(new VariantType("a{sv}"));
            builder.add_value(dict_builder.end());
            builder.add("s", "Knotes");
            builder.add("s", "A simple note-taking app");
            return builder.end();
        }

        // --- D-Bus Methods ---
        // These DO need the [DBus(name = "...")] annotation to map
        // Vala method names to the D-Bus method names the SNI spec expects.

        [DBus(name = "Activate")]
        public void activate(int32 x, int32 y) throws GLib.Error {
            toggle_window();
        }

        [DBus(name = "SecondaryActivate")]
        public void secondary_activate(int32 x, int32 y) throws GLib.Error {
            toggle_window();
        }

        [DBus(name = "ContextMenu")]
        public void context_menu(int32 x, int32 y) throws GLib.Error {
            toggle_window();
        }

        [DBus(name = "Scroll")]
        public void scroll(int32 delta, string orientation) throws GLib.Error {
            // No scroll action for a notes app
        }

        // --- D-Bus Signals ---
        // These need the annotation to match SNI's signal naming.

        [DBus(name = "NewIcon")]
        public signal void new_icon_signal();

        [DBus(name = "NewToolTip")]
        public signal void new_tool_tip_signal();

        public void emit_new_icon() throws GLib.Error {
            new_icon_signal();
        }

        public void emit_new_tool_tip() throws GLib.Error {
            new_tool_tip_signal();
        }

        // --- Icon generation ---

        /**
         * Draws a simple note-document icon using Cairo and returns
         * the raw pixel data formatted as an SNI pixmap variant.
         */
        private Variant generate_pixmap_variant(int size) {
            int stride = size * 4; // ARGB32
            uchar[] pixels = new uchar[size * stride];

            var surface = new Cairo.ImageSurface.for_data(
                pixels, Cairo.Format.ARGB32, size, size, stride
            );
            var cr = new Cairo.Context(surface);

            // Transparent background
            cr.set_operator(Cairo.Operator.CLEAR);
            cr.paint();
            cr.set_operator(Cairo.Operator.OVER);

            double s = (double)size / 24.0; // scale factor

            // Document body (blue rounded rectangle)
            cr.set_source_rgba(0.38, 0.49, 0.80, 1.0);
            draw_rounded_rect(cr, 2.0 * s, 1.5 * s, 20.0 * s, 21.0 * s, 2.0 * s);
            cr.fill();

            // Fold corner (lighter triangle)
            cr.set_source_rgba(0.75, 0.78, 0.90, 1.0);
            cr.move_to(17.0 * s, 1.5 * s);
            cr.line_to(22.0 * s, 6.5 * s);
            cr.line_to(17.0 * s, 6.5 * s);
            cr.close_path();
            cr.fill();

            // Fold edge line
            cr.move_to(17.0 * s, 1.5 * s);
            cr.line_to(22.0 * s, 6.5 * s);
            cr.set_source_rgba(0.30, 0.40, 0.70, 0.5);
            cr.set_line_width(1.0);
            cr.stroke();

            // Text lines (white)
            cr.set_source_rgba(1.0, 1.0, 1.0, 1.0);
            cr.set_line_width(1.8 * s);
            cr.set_line_cap(Cairo.LineCap.ROUND);

            double[] line_lengths = { 12.0, 10.0, 11.0, 7.0 };
            for (int i = 0; i < 4; i++) {
                double y = 8.0 * s + i * 3.5 * s;
                cr.move_to(5.0 * s, y);
                cr.line_to((5.0 + line_lengths[i]) * s, y);
                cr.stroke();
            }

            surface.flush();
            return build_sni_pixmap_variant(size, stride, pixels);
        }

        /**
         * Draws a rectangle with rounded corners.
         */
        private void draw_rounded_rect(Cairo.Context cr,
                double x, double y, double w, double h, double r) {
            double degrees = GLib.Math.PI / 180.0;
            cr.new_sub_path();
            cr.arc(x + w - r, y + r, r, -90 * degrees, 0 * degrees);
            cr.arc(x + w - r, y + h - r, r, 0 * degrees, 90 * degrees);
            cr.arc(x + r, y + h - r, r, 90 * degrees, 180 * degrees);
            cr.arc(x + r, y + r, r, 180 * degrees, 270 * degrees);
            cr.close_path();
        }

        /**
         * Wraps raw pixel data in the Variant format expected by SNI's
         * IconPixmap property: a(iiibay)
         *   struct { int32 width, int32 height, int32 rowstride,
         *            bool has_alpha, array<byte> data }
         */
        private Variant build_sni_pixmap_variant(int size, int stride, uchar[] pixels) {
            var outer = new VariantBuilder(new VariantType("a(iiibay)"));
            var entry = new VariantBuilder(new VariantType("(iiibay)"));
            entry.add("i", size);
            entry.add("i", size);
            entry.add("i", stride);
            entry.add("b", true);  // has_alpha
            entry.add("ay", pixels);
            outer.add_value(entry.end());
            return outer.end();
        }
    }

    /**
     * Manages the system tray icon lifecycle.
     * Registers the StatusNotifierItem on D-Bus and
     * connects to the StatusNotifierWatcher.
     */
    public class TrayManager : GLib.Object {
        private StatusNotifierItemImpl sni;
        private DBusConnection? conn = null;
        private uint watcher_watch_id = 0;
        private uint registration_id = 0;
        private bool registered = false;

        public signal void toggle_window();
        public signal void quit_app();

        ~TrayManager() {
            disconnect_watcher();
            if (conn != null && registration_id > 0) {
                try {
                    conn.unregister_object(registration_id);
                } catch (Error e) {
                    // Ignore errors during cleanup
                }
            }
        }

        /**
         * Try to register with the system tray.
         * Returns true if the D-Bus setup succeeds.
         */
        public bool try_register() {
            try {
                conn = Bus.get_sync(BusType.SESSION);

                sni = new StatusNotifierItemImpl();
                sni.toggle_window.connect(() => { toggle_window(); });
                sni.quit_app.connect(() => { quit_app(); });

                registration_id = conn.register_object("/StatusNotifierItem", sni);
                register_with_watcher();
                return true;
            } catch (GLib.Error e) {
                warning("Failed to register tray icon: %s", e.message);
                return false;
            }
        }

        private void register_with_watcher() {
            if (conn == null) return;

            // Watch for the watcher to appear (so we can register)
            watcher_watch_id = Bus.watch_name(
                BusType.SESSION,
                "org.kde.StatusNotifierWatcher",
                BusNameWatcherFlags.NONE,
                on_watcher_appeared,
                on_watcher_vanished
            );
        }

        private void on_watcher_appeared(DBusConnection conn2, string name) {
            // We already have our own connection; use it to register
            do_register();
        }

        private void on_watcher_vanished(DBusConnection? conn2, string name) {
            registered = false;
        }

        private void do_register() {
            if (conn == null || registered) return;

            try {
                conn.call_sync(
                    "org.kde.StatusNotifierWatcher",   // bus name
                    "/StatusNotifierWatcher",           // object path
                    "org.kde.StatusNotifierWatcher",    // interface
                    "RegisterStatusNotifierItem",       // method
                    new Variant("(s)", conn.get_unique_name()),  // our unique name
                    null,                               // reply type
                    DBusCallFlags.NONE,
                    -1,                                 // timeout
                    null
                );
                registered = true;
                info("Tray icon registered successfully");
            } catch (GLib.Error e) {
                warning("Could not register with StatusNotifierWatcher: %s", e.message);
                registered = false;
            }
        }

        private void disconnect_watcher() {
            if (watcher_watch_id > 0) {
                Bus.unwatch_name(watcher_watch_id);
                watcher_watch_id = 0;
            }
        }
    }
}
