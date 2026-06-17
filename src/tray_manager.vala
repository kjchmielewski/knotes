namespace Knotes {

    /**
     * Minimal implementation of the StatusNotifierItem D-Bus protocol
     * (KDE's System Tray Protocol, also used by GNOME AppIndicator).
     *
     * This is the modern Wayland-compatible tray icon standard.
     * No external libraries needed — pure GLib D-Bus.
     */
    [DBus(name = "org.kde.StatusNotifierItem")]
    public class StatusNotifierItemImpl : GLib.Object {

        public signal void toggle_window();
        public signal void quit_app();

        // --- D-Bus Properties (exposed via get_ methods) ---

        [DBus(name = "Category")]
        public string get_category() throws GLib.Error { return "ApplicationStatus"; }

        [DBus(name = "Id")]
        public string get_id() throws GLib.Error { return "knotes"; }

        [DBus(name = "Title")]
        public string get_title() throws GLib.Error { return "Knotes"; }

        [DBus(name = "Status")]
        public string get_status() throws GLib.Error { return "Active"; }

        [DBus(name = "WindowId")]
        public int32 get_window_id() throws GLib.Error { return 0; }

        [DBus(name = "IconName")]
        public string get_icon_name() throws GLib.Error { return "com.knotes.app"; }

        [DBus(name = "IconThemePath")]
        public string[] get_icon_theme_path() throws GLib.Error { return {}; }

        [DBus(name = "ItemIsMenu")]
        public bool get_item_is_menu() throws GLib.Error { return false; }

        [DBus(name = "Menu")]
        public string get_menu() throws GLib.Error { return "/com/knotes/app/menu"; }

        [DBus(name = "ToolTip")]
        public Variant get_tool_tip() throws GLib.Error {
            var builder = new VariantBuilder(new VariantType("(sa{sv}ss)"));
            builder.add("s", "icon");
            // Empty dict
            var dict_builder = new VariantBuilder(new VariantType("a{sv}"));
            builder.add_value(dict_builder.end());
            builder.add("s", "Knotes");
            builder.add("s", "A simple note-taking app");
            return builder.end();
        }

        // --- D-Bus Methods ---

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
