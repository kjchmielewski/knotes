namespace Knotes {

    [GtkTemplate(ui = "/com/knotes/app/main_window.ui")]
    public class MainWindow : Adw.ApplicationWindow {
        [GtkChild]
        private unowned Gtk.Paned main_paned;
        [GtkChild]
        private unowned Gtk.Button header_new_button;
        [GtkChild]
        private unowned Gtk.MenuButton header_menu_button;

        [GtkChild]
        private unowned Gtk.Stack editor_stack;
        [GtkChild]
        private unowned Gtk.Entry title_entry;
        [GtkChild]
        private unowned Gtk.TextView content_view;
        [GtkChild]
        private unowned Gtk.Button delete_button;

        private NoteRepository repository;
        private NoteListBox note_list;
        private string? current_note_id = null;
        private uint save_timeout_id = 0;
        private bool tray_enabled;

        public MainWindow(Gtk.Application app, NoteRepository repository, bool tray_enabled) {
            Object(application: app);
            this.repository = repository;
            this.tray_enabled = tray_enabled;
            build_ui();
            connect_signals();
        }

        private void build_ui() {
            setup_header_menu();

            // --- Sidebar ---
            var sidebar = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            sidebar.add_css_class("navigation-sidebar");
            sidebar.set_size_request(250, -1);

            note_list = new NoteListBox(repository);
            sidebar.append(note_list);

            main_paned.set_start_child(sidebar);

        }

        private void connect_signals() {
            note_list.note_selected.connect(on_note_selected);
            header_new_button.clicked.connect(on_new_note);
            delete_button.clicked.connect(on_delete_note);
            title_entry.changed.connect(on_note_modified);
            content_view.buffer.changed.connect(on_note_modified);

            // Intercept close request for tray mode
            if (tray_enabled) {
                this.close_request.connect(on_close_request);
            }
        }

        private void setup_header_menu() {
            var menu = new GLib.Menu();
            menu.append("Quit", "app.quit");
            header_menu_button.menu_model = menu;
        }

        private bool on_close_request() {
            if (tray_enabled) {
                hide();
                return true; // Prevent default close/destroy
            }
            return false; // Allow normal close
        }

        /**
         * Really close the window (called from tray "Quit" action).
         */
        public void force_close() {
            tray_enabled = false; // Disable tray behaviour so close goes through
            close();
        }

        private void on_note_selected(string? id) {
            current_note_id = id;
            if (id == null) {
                editor_stack.set_visible_child_name("empty");
                return;
            }

            var note = repository.load_note(id);
            if (note == null) {
                editor_stack.set_visible_child_name("empty");
                return;
            }

            show_note(note);
        }

        private void show_note(Note note) {
            title_entry.text = note.title;
            content_view.buffer.text = note.content;
            editor_stack.set_visible_child_name("editor");
        }

        private void on_note_modified() {
            if (current_note_id == null) return;

            if (save_timeout_id > 0) {
                Source.remove(save_timeout_id);
            }

            // Debounce saves: 500ms after last keystroke
            save_timeout_id = Timeout.add(500, () => {
                save_current_note();
                save_timeout_id = 0;
                return false;
            });
        }

        private void save_current_note() {
            if (current_note_id == null) return;

            var note = repository.load_note(current_note_id);
            if (note == null) return;

            var new_title = title_entry.text;
            var new_content = content_view.buffer.text;

            // Skip save if nothing actually changed — avoids bumping
            // updated_at on mere note selection (which triggers changed
            // signals when show_note sets the entry text).
            if (note.title == new_title && note.content == new_content) {
                return;
            }

            note.title = new_title;
            note.content = new_content;
            note.updated_at = new DateTime.now_utc();
            repository.save_note(note);
            note_list.update_note(note);
        }

        private void on_delete_note() {
            if (current_note_id == null) return;

            var dialog = new Gtk.AlertDialog(
                "Delete this note?"
            );
            dialog.detail = "This action cannot be undone.";
            dialog.buttons = { "Cancel", "Delete" };
            dialog.cancel_button = 0;
            dialog.default_button = 1;

            dialog.choose.begin(this, null, (obj, res) => {
                try {
                    var btn = dialog.choose.end(res);
                    if (btn == 1) {
                        var id = current_note_id;
                        current_note_id = null;
                        repository.delete_note(id);
                        note_list.remove_note(id);
                        editor_stack.set_visible_child_name("empty");
                    }
                } catch (GLib.Error e) {
                    warning("Dialog failed: %s", e.message);
                }
            });
        }

        private void on_new_note() {
            note_list.create_note();
        }
    }
}
