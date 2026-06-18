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
        public abstract ObjectPath Menu { owned get; }
        [DBus(signature = "a(iiay)")]
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
     * Minimal D-BusMenu interface used by StatusNotifierItem hosts to render
     * the tray icon context menu.
     */
    [DBus(name = "com.canonical.dbusmenu")]
    public interface TrayMenuIface : GLib.Object {
        public abstract string Status { owned get; }
        public abstract uint32 Version { get; }
        public abstract string TextDirection { owned get; }
        public abstract string[] IconThemePath { owned get; }

        public abstract void GetLayout(
            int32 parentId,
            int32 recursionDepth,
            string[] propertyNames,
            out uint32 revision,
            [DBus(signature = "(ia{sv}av)")] out Variant layout
        ) throws GLib.Error;

        public abstract void Event(
            int32 id,
            string eventId,
            Variant data,
            uint32 timestamp
        ) throws GLib.Error;

        public abstract int32[] EventGroup(
            [DBus(signature = "a(isvu)")] Variant events
        ) throws GLib.Error;

        public abstract bool AboutToShow(int32 id) throws GLib.Error;
        public abstract Variant GetProperty(int32 id, string name) throws GLib.Error;

        public abstract void AboutToShowGroup(
            int32[] ids,
            out int32[] updatesNeeded,
            out int32[] idErrors
        ) throws GLib.Error;

        [DBus(signature = "a(ia{sv})")]
        public abstract Variant GetGroupProperties(
            int32[] ids,
            string[] propertyNames
        ) throws GLib.Error;

        public signal void LayoutUpdated(uint32 revision, int32 parent);
    }

    public class TrayMenuImpl : GLib.Object, TrayMenuIface {
        private const int32 ROOT_ID = 0;
        private const int32 QUIT_ITEM_ID = 1;
        private const uint32 REVISION = 1;

        public signal void quit_app();

        public string Status { owned get { return "normal"; } }
        public uint32 Version { get { return 3; } }
        public string TextDirection { owned get { return "ltr"; } }
        public string[] IconThemePath { owned get { return {}; } }

        public void GetLayout(
            int32 parentId,
            int32 recursionDepth,
            string[] propertyNames,
            out uint32 revision,
            out Variant layout
        ) throws GLib.Error {
            revision = REVISION;
            layout = build_root_layout();
        }

        public void Event(
            int32 id,
            string eventId,
            Variant data,
            uint32 timestamp
        ) throws GLib.Error {
            handle_menu_event(id, eventId);
        }

        public int32[] EventGroup(Variant events) throws GLib.Error {
            VariantIter iter = events.iterator();
            int32 id;
            string eventId;
            Variant data;
            uint32 timestamp;

            while (iter.next("(isvu)", out id, out eventId, out data, out timestamp)) {
                handle_menu_event(id, eventId);
            }

            return {};
        }

        public bool AboutToShow(int32 id) throws GLib.Error {
            return false;
        }

        public Variant GetProperty(int32 id, string name) throws GLib.Error {
            if (id == ROOT_ID) {
                return get_root_property(name);
            }

            if (id == QUIT_ITEM_ID) {
                return get_quit_item_property(name);
            }

            return new Variant.string("");
        }

        public void AboutToShowGroup(
            int32[] ids,
            out int32[] updatesNeeded,
            out int32[] idErrors
        ) throws GLib.Error {
            updatesNeeded = {};
            idErrors = {};
        }

        public Variant GetGroupProperties(
            int32[] ids,
            string[] propertyNames
        ) throws GLib.Error {
            var items = new VariantBuilder(new VariantType("a(ia{sv})"));

            if (ids.length == 0) {
                items.add_value(build_item_properties(ROOT_ID, build_root_properties()));
                items.add_value(build_item_properties(QUIT_ITEM_ID, build_quit_item_properties()));
                return items.end();
            }

            foreach (int32 id in ids) {
                if (id == ROOT_ID) {
                    items.add_value(build_item_properties(ROOT_ID, build_root_properties()));
                } else if (id == QUIT_ITEM_ID) {
                    items.add_value(build_item_properties(QUIT_ITEM_ID, build_quit_item_properties()));
                }
            }

            return items.end();
        }

        private void handle_menu_event(int32 id, string eventId) {
            if (id == QUIT_ITEM_ID && eventId == "clicked") {
                quit_app();
            }
        }

        private Variant build_root_layout() {
            var children = new VariantBuilder(new VariantType("av"));
            children.add_value(new Variant.variant(build_quit_item_layout()));
            return build_menu_node(ROOT_ID, build_root_properties(), children.end());
        }

        private Variant build_quit_item_layout() {
            var children = new VariantBuilder(new VariantType("av"));
            return build_menu_node(QUIT_ITEM_ID, build_quit_item_properties(), children.end());
        }

        private Variant build_menu_node(int32 id, Variant properties, Variant children) {
            var node = new VariantBuilder(new VariantType("(ia{sv}av)"));
            node.add("i", id);
            node.add_value(properties);
            node.add_value(children);
            return node.end();
        }

        private Variant build_root_properties() {
            var properties = new VariantBuilder(new VariantType("a{sv}"));
            properties.add("{sv}", "children-display", get_root_property("children-display"));
            properties.add("{sv}", "visible", get_root_property("visible"));
            properties.add("{sv}", "enabled", get_root_property("enabled"));
            return properties.end();
        }

        private Variant build_quit_item_properties() {
            var properties = new VariantBuilder(new VariantType("a{sv}"));
            properties.add("{sv}", "label", get_quit_item_property("label"));
            properties.add("{sv}", "visible", get_quit_item_property("visible"));
            properties.add("{sv}", "enabled", get_quit_item_property("enabled"));
            return properties.end();
        }

        private Variant get_root_property(string name) {
            switch (name) {
                case "children-display":
                    return new Variant.string("submenu");
                case "visible":
                case "enabled":
                    return new Variant.boolean(true);
                default:
                    return new Variant.string("");
            }
        }

        private Variant get_quit_item_property(string name) {
            switch (name) {
                case "label":
                    return new Variant.string("Quit");
                case "visible":
                case "enabled":
                    return new Variant.boolean(true);
                default:
                    return new Variant.string("");
            }
        }

        private Variant build_item_properties(int32 id, Variant properties) {
            var item = new VariantBuilder(new VariantType("(ia{sv})"));
            item.add("i", id);
            item.add_value(properties);
            return item.end();
        }
    }

    /**
     * Implementation of the StatusNotifierItem D-Bus interface.
     *
     * IconName is the primary tray icon path. IconPixmap is kept as an
     * opt-in fallback for environments that fail to resolve the installed
     * themed icon by name.
     */
    public class StatusNotifierItemImpl : GLib.Object, StatusNotifierItemIface {
        private const int ICON_SIZE = 24;
        private const bool USE_ICON_PIXMAP_FALLBACK = false;
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
        public string[] IconThemePath {
            owned get {
                return { Path.build_filename(Environment.get_user_data_dir(), "icons") };
            }
        }
        public bool ItemIsMenu { get { return false; } }
        public ObjectPath Menu { owned get { return new ObjectPath("/com/knotes/app/menu"); } }

        public Variant IconPixmap {
            owned get {
                if (USE_ICON_PIXMAP_FALLBACK) {
                    return generate_pixmap_variant(ICON_SIZE);
                }

                return empty_icon_pixmap_variant();
            }
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
            // Context menus are exposed through the D-BusMenu object at Menu.
            // Do not toggle the window on right-click.
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
         * Returns an empty SNI pixmap list so hosts prefer IconName.
         */
        private Variant empty_icon_pixmap_variant() {
            var builder = new VariantBuilder(new VariantType("a(iiay)"));
            return builder.end();
        }

        /**
         * Returns the app icon's raw pixel data formatted as a standard SNI
         * pixmap variant. This is intentionally disabled by default and should
         * only be enabled as a compatibility fallback for hosts that do not
         * resolve the installed IconName correctly.
         *
         * SNI spec format: a(iiay)
         *   struct { int32 width, int32 height, array<byte> ARGB32 data }
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
            return build_sni_pixmap_variant(size, size, pixels);
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

            return build_sni_pixmap_variant(width, height, pixels);
        }

        private Variant build_sni_pixmap_variant(int width, int height, uchar[] pixels) {
            var outer = new VariantBuilder(new VariantType("a(iiay)"));
            var entry = new VariantBuilder(new VariantType("(iiay)"));
            entry.add("i", width);
            entry.add("i", height);

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
        private TrayMenuImpl menu;
        private uint watcher_watch_id = 0;
        private uint registration_id = 0;
        private uint menu_registration_id = 0;
        private bool registered = false;

        public signal void toggle_window();
        public signal void quit_app();

        ~TrayManager() {
            disconnect_watcher();
            if (conn != null) {
                if (registration_id > 0) {
                    try {
                        conn.unregister_object(registration_id);
                    } catch (Error e) {
                        // Ignore errors during cleanup
                    }
                }

                if (menu_registration_id > 0) {
                    try {
                        conn.unregister_object(menu_registration_id);
                    } catch (Error e) {
                        // Ignore errors during cleanup
                    }
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

                menu = new TrayMenuImpl();
                menu.quit_app.connect(() => { quit_app(); });

                menu_registration_id = conn.register_object<TrayMenuIface>("/com/knotes/app/menu", menu);
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
