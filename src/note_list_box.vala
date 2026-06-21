using Gee;

namespace Knotes {

    public class NoteRow : Gtk.ListBoxRow {
        public string note_id { get; construct; }
        private Gtk.Box content_box;

        public NoteRow(Note note) {
            Object(note_id: note.id);
            build_ui(note);
        }

        private void build_ui(Note note) {
            content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 2) {
                margin_start = 8,
                margin_end = 8,
                margin_top = 6,
                margin_bottom = 6
            };

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

            content_box.append(title_label);
            content_box.append(preview_label);
            set_child(content_box);
        }

        public void update(Note note) {
            var title = content_box.get_first_child();
            if (title is Gtk.Label) {
                ((Gtk.Label) title).label = note.title;
                var preview = title.get_next_sibling();
                if (preview is Gtk.Label) {
                    ((Gtk.Label) preview).label = note.preview(60);
                }
            }
        }
    }

    public class NoteListBox : Gtk.Box {
        private Gtk.ListBox list_box;
        private Gtk.Entry search_entry;
        private NoteRepository repository;
        private HashMap<string, Note> notes_map;
        private HashMap<string, NoteRow> rows_map;
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
            build_ui();
            load_notes();
            connect_signals();
        }

        private void build_ui() {
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

            append(search_entry);
            append(scrolled);
        }

        private void connect_signals() {
            search_entry.changed.connect(on_search_changed);
            list_box.row_activated.connect(on_row_activated);
            repository.note_updated.connect(on_external_note_updated);
            repository.note_deleted.connect(on_external_note_deleted);
        }

        private void load_notes() {
            list_box.remove_all();
            notes_map.clear();
            rows_map.clear();
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
            rows_map[note.id] = row;
            list_box.append(row);
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
                entry.value.visible = visible;
            }
        }

        private void on_row_activated(Gtk.ListBoxRow row) {
            var note_row = row as NoteRow;
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
            var row = rows_map[id];

            notes_map.unset(id);
            rows_map.unset(id);

            if (row != null) {
                list_box.remove(row);
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
