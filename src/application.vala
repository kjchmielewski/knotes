namespace Knotes {

    public class Application : Adw.Application {
        private const string STYLE_RESOURCE_PATH = "/com/knotes/app/style.css";

        private NoteRepository repository;
        private TrayManager? tray_manager = null;
        private MainWindow? main_window = null;
        private bool is_style_loaded = false;
        private bool tray_enabled;
        private bool start_minimized;

        public Application(bool tray_enabled, bool start_minimized) {
            Object(
                application_id: "com.knotes.app",
                flags: ApplicationFlags.FLAGS_NONE
            );
            this.tray_enabled = tray_enabled || start_minimized;
            this.start_minimized = start_minimized;
        }

        protected override void activate() {
            if (start_minimized) {
                start_minimized = false;
                return;
            }

            show_main_window();
        }

        protected override void startup() {
            base.startup();
            load_application_style();
            repository = new NoteRepository();

            setup_quit_action();

            if (tray_enabled) {
                tray_enabled = setup_tray();
            }

            if (start_minimized && tray_enabled) {
                ensure_main_window();
                hold();
            } else if (start_minimized) {
                start_minimized = false;
            }
        }

        private MainWindow ensure_main_window() {
            if (main_window == null) {
                main_window = new MainWindow(this, repository, tray_enabled);
            }
            return main_window;
        }

        private void show_main_window() {
            var window = ensure_main_window();
            window.restore_from_tray();
        }

        private void load_application_style() {
            if (is_style_loaded) {
                return;
            }

            var display = Gdk.Display.get_default();
            if (display == null) {
                warning("Unable to load application CSS: no default display available");
                return;
            }

            var provider = new Gtk.CssProvider();
            provider.load_from_resource(STYLE_RESOURCE_PATH);
            Gtk.StyleContext.add_provider_for_display(display, provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
            is_style_loaded = true;
        }

        private void setup_quit_action() {
            var quit_action = new SimpleAction("quit", null);
            quit_action.activate.connect(() => {
                if (main_window != null) {
                    main_window.force_close();
                }
                quit();
            });
            add_action(quit_action);
            set_accels_for_action("app.quit", { "<Control>q", null });
        }

        private bool setup_tray() {
            tray_manager = new TrayManager();
            tray_manager.toggle_window.connect(() => {
                if (main_window != null && main_window.should_hide_to_tray()) {
                    main_window.set_visible(false);
                } else {
                    show_main_window();
                }
            });
            tray_manager.quit_app.connect(() => {
                activate_action("quit", null);
            });

            // Silently fail if no tray is available (no DE support)
            return tray_manager.try_register();
        }
    }
}
