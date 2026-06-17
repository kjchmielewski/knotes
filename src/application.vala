namespace Knotes {

    public class Application : Gtk.Application {
        private NoteRepository repository;
        private TrayManager? tray_manager = null;
        private MainWindow? main_window = null;
        private bool tray_enabled;

        public Application(bool tray_enabled) {
            Object(
                application_id: "com.knotes.app",
                flags: ApplicationFlags.FLAGS_NONE
            );
            this.tray_enabled = tray_enabled;
        }

        protected override void activate() {
            if (main_window == null) {
                main_window = new MainWindow(this, repository, tray_enabled);
            }
            main_window.present();
            main_window.set_visible(true);
        }

        protected override void startup() {
            base.startup();
            repository = new NoteRepository();

            setup_quit_action();

            if (tray_enabled) {
                setup_tray();
            }
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

        private void setup_tray() {
            tray_manager = new TrayManager();
            tray_manager.toggle_window.connect(() => {
                if (main_window == null) return;
                if (main_window.visible) {
                    main_window.hide();
                } else {
                    main_window.present();
                    main_window.set_visible(true);
                }
            });
            tray_manager.quit_app.connect(() => {
                activate_action("quit", null);
            });

            // Silently fail if no tray is available (no DE support)
            tray_manager.try_register();
        }
    }
}
