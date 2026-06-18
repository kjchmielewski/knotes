using Gee;

namespace Knotes {

    public class NoteRow : Gtk.Box {
        public string note_id { get; construct; }
        public signal void activated();

        public NoteRow(Note note) {
            Object(
                note_id: note.id,
                orientation: Gtk.Orientation.VERTICAL,
                spacing: 2,
                margin_start: 8,
                margin_end: 8,
                margin_top: 6,
                margin_bottom: 6
            );
            build_ui(note);
        }

        private void build_ui(Note note) {
            var title_label = new Gtk.Label(note.title) {
                halign = Gtk.Align.START,
                use_markup = true,
                ellipsize = Pango.EllipsizeMode.END,
                max_width_chars = 30
            };
            title_label.add_css_class("heading");

            var preview_label = new Gtk.Label(note.preview(60)) {
                halign = Gtk.Align.START,
                ellipsize = Pango.EllipsizeMode.END,
                max_width_chars = 30,
                opacity = 0.7
            };
            preview_label.add_css_class("caption");

            append(title_label);
            append(preview_label);

            var gesture = new Gtk.GestureClick();
            gesture.pressed.connect(() => { activated(); });
            add_controller(gesture);
        }

        public void update(Note note) {
            var children = get_first_child();
            if (children is Gtk.Label) {
                ((Gtk.Label) children).label = note.title;
                var next = children.get_next_sibling();
                if (next is Gtk.Label) {
                    ((Gtk.Label) next).label = note.preview(60);
                }
            }
        }
    }

    public class NoteListBox : Gtk.Box {
        private Gtk.ListBox list_box;
        private Gtk.Entry search_entry;
        private Gtk.Button new_button;
        private NoteRepository repository;
        private HashMap<string, Note> notes_map;
        private HashMap<string, NoteRow> rows_map;
        private HashMap<string, Gtk.ListBoxRow> row_wrappers_map;
        private string? selected_id = null;

        public signal void note_selected(string? id);

        public NoteListBox(NoteRepository repository) {
            Object(
                orientation: Gtk.Orientation.VERTICAL,
                spacing: 4
            );
            this.repository = repository;
            this.notes_map = new HashMap<string, Note>();
            this.rows_map = new HashMap<string, NoteRow>();
            this.row_wrappers_map = new HashMap<string, Gtk.ListBoxRow>();
            build_ui();
            load_notes();
            connect_signals();
        }

        private void build_ui() {
            var header_bar = new Gtk.CenterBox();

            var title_label = new Gtk.Label("Notes") {
                halign = Gtk.Align.START,
                margin_start = 8
            };
            title_label.add_css_class("title");

            new_button = new Gtk.Button() {
                icon_name = "document-new-symbolic",
                tooltip_text = "New note"
            };
            new_button.add_css_class("flat");
            new_button.add_css_class("circular");

            // Menu button with Quit option
            var menu = new GLib.Menu();
            menu.append("Quit", "app.quit");

            var menu_button = new Gtk.MenuButton() {
                menu_model = menu,
                icon_name = "open-menu-symbolic",
                tooltip_text = "Menu"
            };
            menu_button.add_css_class("flat");
            menu_button.add_css_class("circular");

            var header_end_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0) {
                margin_end = 8
            };
            header_end_box.append(new_button);
            header_end_box.append(menu_button);

            header_bar.set_start_widget(title_label);
            header_bar.set_end_widget(header_end_box);

            search_entry = new Gtk.Entry() {
                placeholder_text = "Search notes…",
                margin_start = 8,
                margin_end = 8,
                margin_bottom = 4
            };

            list_box = new Gtk.ListBox() {
                vexpand = true
            };
            list_box.add_css_class("boxed-list");
            list_box.set_selection_mode(Gtk.SelectionMode.SINGLE);

            var scrolled = new Gtk.ScrolledWindow() {
                vexpand = true
            };
            scrolled.set_child(list_box);

            append(header_bar);
            append(search_entry);
            append(scrolled);
        }

        private void connect_signals() {
            new_button.clicked.connect(on_new_note);
            search_entry.changed.connect(on_search_changed);
            list_box.row_activated.connect(on_row_activated);
            repository.note_updated.connect(on_external_note_updated);
            repository.note_deleted.connect(on_external_note_deleted);
        }

        private void load_notes() {
            list_box.remove_all();
            notes_map.clear();
            rows_map.clear();
            row_wrappers_map.clear();
            selected_id = null;

            var notes = repository.list_all();
            notes.sort((a, b) => {
                return a.created_at.compare(b.created_at);
            });

            foreach (var note in notes) {
                notes_map[note.id] = note;
                add_note_row(note);
            }
        }

        private void add_note_row(Note note) {
            var row = new NoteRow(note);
            var wrapper = new Gtk.ListBoxRow();
            wrapper.set_child(row);

            row.activated.connect(() => {
                selected_id = note.id;
                note_selected(note.id);
            });

            rows_map[note.id] = row;
            row_wrappers_map[note.id] = wrapper;
            list_box.append(wrapper);
        }

        private void on_new_note() {
            var note = new Note.with_new_content("Untitled", "");
            repository.save_note(note);
            notes_map[note.id] = note;
            add_note_row(note);
            selected_id = note.id;
            note_selected(note.id);
        }

        private void on_search_changed() {
            var query = search_entry.text.down();
            foreach (var entry in rows_map.entries) {
                var note = notes_map[entry.key];
                if (note == null) continue;
                bool visible = query.length == 0 ||
                    note.title.down().contains(query) ||
                    note.content.down().contains(query);
                var wrapper = row_wrappers_map[entry.key];
                if (wrapper != null) {
                    wrapper.visible = visible;
                }
            }
        }

        private void on_row_activated(Gtk.ListBoxRow row) {
            var note_row = row.get_child() as NoteRow;
            if (note_row != null) {
                selected_id = note_row.note_id;
                note_selected(note_row.note_id);
            }
        }

        /**
         * Public helper called by both the sidebar's and the editor's
         * "New note" button so that a visual row is always created.
         */
        public void create_note() {
            on_new_note();
        }

        public void update_note(Note note) {
            notes_map[note.id] = note;
            var note_row = rows_map[note.id];
            if (note_row != null) {
                note_row.update(note);
            }
        }

        public void remove_note(string id) {
            var wrapper = row_wrappers_map[id];

            notes_map.unset(id);
            rows_map.unset(id);
            row_wrappers_map.unset(id);

            if (wrapper != null) {
                list_box.remove(wrapper);
            }
        }

        private void on_external_note_updated(string id) {
            var note = repository.load_note(id);
            if (note == null) return;

            if (notes_map.has_key(id)) {
                notes_map[id] = note;
                var note_row = rows_map[id];
                if (note_row != null) {
                    note_row.update(note);
                }
            } else {
                notes_map[id] = note;
                add_note_row(note);
            }
        }

        private void on_external_note_deleted(string id) {
            if (selected_id == id) {
                selected_id = null;
                note_selected(null);
            }
            remove_note(id);
        }
    }
}
