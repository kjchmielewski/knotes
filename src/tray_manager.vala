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
        [DBus(signature = "a(iiibay)")]
        public abstract Variant IconPixmap { owned get; }
        [DBus(signature = "(sa(iiay)ss)")]
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
     * Exposes the app icon as an SNI IconPixmap so trays do not need to
     * resolve the themed icon name. The pixmap is rendered from the bundled
     * SVG resource, with a Cairo-generated fallback if loading fails.
     */
    public class StatusNotifierItemImpl : GLib.Object, StatusNotifierItemIface {
        private const int ICON_SIZE = 24;
        private const string ICON_RESOURCE_PATH = "/com/knotes/app/icons/com.knotes.app.svg";

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
                var builder = new VariantBuilder(new VariantType("(sa(iiay)ss)"));
                builder.add("s", "com.knotes.app");

                // SNI tooltip pixmaps use the original spec format:
                // a(iiay) = array of (width, height, ARGB32 bytes).
                // The icon name above is enough for the tooltip, so keep
                // the pixmap list empty instead of duplicating IconPixmap.
                var pixmaps = new VariantBuilder(new VariantType("a(iiay)"));
                builder.add_value(pixmaps.end());

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
         * Returns the app icon's raw pixel data formatted as an SNI pixmap
         * variant. The preferred source is the bundled SVG resource; the
         * drawn Cairo icon remains as a defensive fallback.
         *
         * SNI spec format: a(iiibay)
         *   struct { int32 width, int32 height, int32 rowstride,
         *            bool has_alpha, array<byte> data }
         */
        private Variant generate_pixmap_variant(int size) {
            try {
                var pixbuf = new Gdk.Pixbuf.from_resource_at_scale(
                    ICON_RESOURCE_PATH,
                    size,
                    size,
                    true
                );
                return pixbuf_to_sni_pixmap_variant(pixbuf);
            } catch (GLib.Error e) {
                warning("Failed to load tray icon resource: %s", e.message);
                return generate_fallback_pixmap_variant(size);
            }
        }

        private Variant generate_fallback_pixmap_variant(int size) {
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
            return build_sni_pixmap_variant(size, size, stride, pixels);
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

        private Variant pixbuf_to_sni_pixmap_variant(Gdk.Pixbuf pixbuf) {
            int width = pixbuf.get_width();
            int height = pixbuf.get_height();
            int source_stride = pixbuf.get_rowstride();
            int channels = pixbuf.get_n_channels();
            bool has_alpha = pixbuf.get_has_alpha();
            int stride = width * 4;
            unowned uchar[] source = pixbuf.get_pixels();
            uchar[] pixels = new uchar[height * stride];

            for (int y = 0; y < height; y++) {
                for (int x = 0; x < width; x++) {
                    int source_index = y * source_stride + x * channels;
                    int target_index = y * stride + x * 4;

                    uchar r = source[source_index];
                    uchar g = source[source_index + 1];
                    uchar b = source[source_index + 2];
                    uchar a = has_alpha ? source[source_index + 3] : 255;

                    if (a != 255) {
                        r = (uchar)(((int) r * (int) a + 127) / 255);
                        g = (uchar)(((int) g * (int) a + 127) / 255);
                        b = (uchar)(((int) b * (int) a + 127) / 255);
                    }

                    // Match Cairo.Format.ARGB32 memory layout on little-endian
                    // Linux, which is what the existing SNI pixmap path used.
                    pixels[target_index] = b;
                    pixels[target_index + 1] = g;
                    pixels[target_index + 2] = r;
                    pixels[target_index + 3] = a;
                }
            }

            return build_sni_pixmap_variant(width, height, stride, pixels);
        }

        private Variant build_sni_pixmap_variant(int width, int height, int stride, uchar[] pixels) {
            var outer = new VariantBuilder(new VariantType("a(iiibay)"));
            var entry = new VariantBuilder(new VariantType("(iiibay)"));
            entry.add("i", width);
            entry.add("i", height);
            entry.add("i", stride);
            entry.add("b", true);  // has_alpha

            // Build the byte array variant via from_bytes to avoid Vala's
            // variadic limitation with the "ay" format specifier in
            // VariantBuilder.add(), which doesn't pass the array length.
            var pixmap_var = new Variant.from_bytes(
                new VariantType("ay"),
                new Bytes(pixels),
                true
            );
            entry.add_value(pixmap_var);

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
