namespace Knotes {

    public class MainWindow : Gtk.ApplicationWindow {
        private NoteRepository repository;
        private NoteListBox note_list;
        private Gtk.Stack editor_stack;
        private Gtk.Box editor_view;
        private Gtk.Entry title_entry;
        private Gtk.TextView content_view;
        private Gtk.Button delete_button;
        private Gtk.Button new_button;
        private Gtk.Label no_selection_label;
        private string? current_note_id = null;
        private uint save_timeout_id = 0;
        private bool tray_enabled;

        public MainWindow(Gtk.Application app, NoteRepository repository, bool tray_enabled) {
            Object(
                application: app,
                title: "Knotes",
                default_width: 900,
                default_height: 600
            );
            this.repository = repository;
            this.tray_enabled = tray_enabled;
            build_ui();
            connect_signals();
        }

        construct {
            var css_provider = new Gtk.CssProvider();
            css_provider.load_from_string("""
                .note-title { font-size: 1.4em; font-weight: bold; }
                .note-content text { font-size: 1.1em; }
                .sidebar { background: @sidebar_bg_color; }
            """);
            Gtk.StyleContext.add_provider_for_display(
                get_display(),
                css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );
        }

        private void build_ui() {
            var paned = new Gtk.Paned(Gtk.Orientation.HORIZONTAL);

            // --- Sidebar ---
            var sidebar = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            sidebar.add_css_class("sidebar");
            sidebar.set_size_request(250, -1);

            note_list = new NoteListBox(repository);
            sidebar.append(note_list);

            paned.set_start_child(sidebar);

            // --- Editor area ---
            editor_stack = new Gtk.Stack();
            editor_stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE);

            no_selection_label = new Gtk.Label("Select a note or create a new one") {
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER,
                opacity = 0.5
            };
            no_selection_label.add_css_class("large-title");
            editor_stack.add_named(no_selection_label, "empty");

            editor_view = new Gtk.Box(Gtk.Orientation.VERTICAL, 8) {
                margin_start = 16,
                margin_end = 16,
                margin_top = 16,
                margin_bottom = 16
            };

            // Title bar with title entry and actions
            var title_bar = new Gtk.CenterBox();
            title_entry = new Gtk.Entry() {
                hexpand = true,
                placeholder_text = "Note title…"
            };
            title_entry.add_css_class("note-title");
            title_entry.add_css_class("flat");

            delete_button = new Gtk.Button() {
                icon_name = "user-trash-symbolic",
                tooltip_text = "Delete note"
            };
            delete_button.add_css_class("destructive-action");

            new_button = new Gtk.Button() {
                icon_name = "document-new-symbolic",
                tooltip_text = "New note"
            };

            title_bar.set_start_widget(new_button);
            title_bar.set_center_widget(title_entry);
            title_bar.set_end_widget(delete_button);
            editor_view.append(title_bar);

            // Separator
            editor_view.append(new Gtk.Separator(Gtk.Orientation.HORIZONTAL));

            // Content text view
            content_view = new Gtk.TextView() {
                hexpand = true,
                vexpand = true,
                wrap_mode = Gtk.WrapMode.WORD_CHAR,
                top_margin = 8,
                right_margin = 8,
                bottom_margin = 8,
                left_margin = 8
            };
            content_view.add_css_class("note-content");

            var scrolled = new Gtk.ScrolledWindow() {
                hexpand = true,
                vexpand = true
            };
            scrolled.set_child(content_view);
            editor_view.append(scrolled);

            editor_stack.add_named(editor_view, "editor");
            paned.set_end_child(editor_stack);

            set_child(paned);
        }

        private void connect_signals() {
            note_list.note_selected.connect(on_note_selected);
            delete_button.clicked.connect(on_delete_note);
            new_button.clicked.connect(on_new_note);
            title_entry.changed.connect(on_note_modified);
            content_view.buffer.changed.connect(on_note_modified);

            // Intercept close request for tray mode
            if (tray_enabled) {
                this.close_request.connect(on_close_request);
            }
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
                        editor_stack.set_visible_child_name("empty");
                    }
                } catch (GLib.Error e) {
                    warning("Dialog failed: %s", e.message);
                }
            });
        }

        private void on_new_note() {
            var note = new Note.with_new_content("Untitled", "");
            repository.save_note(note);
            note_list.update_note(note);
            note_list.note_selected(note.id);
        }
    }
}
