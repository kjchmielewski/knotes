namespace Knotes {

    /**
     * D-Bus interface for the StatusNotifierItem protocol (SNI).
     *
     * Vala translates abstract properties and methods in a [DBus]-annotated
     * interface directly into D-Bus properties, methods, and signals.
     * This avoids Vala's class-level D-Bus binding which doesn't generate
     * property entries — the root cause of the invisible tray icon.
     */
    [DBus(name = "org.kde.StatusNotifierItem")]
    public interface StatusNotifierItemIface : GLib.Object {

        // --- Properties ---
        public abstract string Category { owned get; }
        public abstract string Id { owned get; }
        public abstract string Title { owned get; }
        public abstract string Status { owned get; }
        public abstract int32 WindowId { get; }
        public abstract string IconName { owned get; }
        public abstract string[] IconThemePath { owned get; }
        public abstract bool ItemIsMenu { get; }
        public abstract string Menu { owned get; }
        public abstract Variant IconPixmap { owned get; }
        public abstract Variant ToolTip { owned get; }

        // --- Methods ---
        public abstract void Activate(int32 x, int32 y) throws GLib.Error;
        public abstract void SecondaryActivate(int32 x, int32 y) throws GLib.Error;
        public abstract void ContextMenu(int32 x, int32 y) throws GLib.Error;
        public abstract void Scroll(int32 delta, string orientation) throws GLib.Error;

        // --- Signals ---
        public signal void NewIcon();
        public signal void NewToolTip();
    }

    /**
     * Implementation of the StatusNotifierItem D-Bus interface.
     *
     * Generates the tray icon using Cairo (no icon theme dependency).
     */
    public class StatusNotifierItemImpl : GLib.Object, StatusNotifierItemIface {
        private const int ICON_SIZE = 24;

        // Internal signals (not D-Bus)
        public signal void toggle_window();
        public signal void quit_app();

        // --- D-Bus Properties ---

        public string Category { owned get { return "ApplicationStatus"; } }
        public string Id { owned get { return "knotes"; } }
        public string Title { owned get { return "Knotes"; } }
        public string Status { owned get { return "Active"; } }
        public int32 WindowId { get { return 0; } }
        public string IconName { owned get { return "com.knotes.app"; } }
        public string[] IconThemePath { owned get { return {}; } }
        public bool ItemIsMenu { get { return false; } }
        public string Menu { owned get { return "/com/knotes/app/menu"; } }

        public Variant IconPixmap {
            owned get { return generate_pixmap_variant(ICON_SIZE); }
        }

        public Variant ToolTip {
            owned get {
                var builder = new VariantBuilder(new VariantType("(sa{sv}ss)"));
                builder.add("s", "icon");
                var dict_builder = new VariantBuilder(new VariantType("a{sv}"));
                builder.add_value(dict_builder.end());
                builder.add("s", "Knotes");
                builder.add("s", "A simple note-taking app");
                return builder.end();
            }
        }

        // --- D-Bus Methods ---

        public void Activate(int32 x, int32 y) throws GLib.Error {
            toggle_window();
        }

        public void SecondaryActivate(int32 x, int32 y) throws GLib.Error {
            toggle_window();
        }

        public void ContextMenu(int32 x, int32 y) throws GLib.Error {
            toggle_window();
        }

        public void Scroll(int32 delta, string orientation) throws GLib.Error {
            // No scroll action for a notes app
        }

        // --- D-Bus Signals ---
        // 'NewIcon' and 'NewToolTip' are inherited from the interface.
        // They can be emitted via e.g. this.NewIcon().

        public void emit_new_icon() {
            this.NewIcon();
        }

        public void emit_new_tool_tip() {
            this.NewToolTip();
        }

        // --- Icon generation ---

        /**
         * Draws a simple note-document icon using Cairo and returns
         * the raw pixel data formatted as an SNI pixmap variant.
         *
         * SNI spec format: a(iiibay)
         *   struct { int32 width, int32 height, int32 rowstride,
         *            bool has_alpha, array<byte> data }
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

            double s = (double)size / 24.0;

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

                registration_id = conn.register_object<StatusNotifierItemIface>("/StatusNotifierItem", sni);
                register_with_watcher();
                return true;
            } catch (GLib.Error e) {
                warning("Failed to register tray icon: %s", e.message);
                return false;
            }
        }

        private void register_with_watcher() {
            if (conn == null) return;

            watcher_watch_id = Bus.watch_name(
                BusType.SESSION,
                "org.kde.StatusNotifierWatcher",
                BusNameWatcherFlags.NONE,
                on_watcher_appeared,
                on_watcher_vanished
            );
        }

        private void on_watcher_appeared(DBusConnection conn2, string name) {
            do_register();
        }

        private void on_watcher_vanished(DBusConnection? conn2, string name) {
            registered = false;
        }

        private void do_register() {
            if (conn == null || registered) return;

            try {
                conn.call_sync(
                    "org.kde.StatusNotifierWatcher",
                    "/StatusNotifierWatcher",
                    "org.kde.StatusNotifierWatcher",
                    "RegisterStatusNotifierItem",
                    new Variant("(s)", conn.get_unique_name()),
                    null,
                    DBusCallFlags.NONE,
                    -1,
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
