using Gee;

namespace Knotes {

    [GtkTemplate(ui = "/com/knotes/app/note_row.ui")]
    public class NoteRow : Gtk.ListBoxRow {
        [GtkChild]
        private unowned Gtk.Label title_label;
        [GtkChild]
        private unowned Gtk.Label preview_label;

        public string note_id { get; construct; }

        public NoteRow(Note note) {
            Object(note_id: note.id);
            update(note);
        }

        public void update(Note note) {
            title_label.label = note.title;
            preview_label.label = note.preview(60);
        }
    }

    public class CompactNoteRow : Gtk.ListBoxRow {
        private Gtk.Label avatar_label;

        public string note_id { get; construct; }

        public CompactNoteRow(Note note) {
            Object(note_id: note.id);

            avatar_label = new Gtk.Label(initial_for_title(note.title));
            avatar_label.add_css_class("compact-note-avatar");
            avatar_label.halign = Gtk.Align.CENTER;
            avatar_label.valign = Gtk.Align.CENTER;

            var row_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            row_box.halign = Gtk.Align.CENTER;
            row_box.append(avatar_label);
            child = row_box;

            update(note);
        }

        public void update(Note note) {
            avatar_label.label = initial_for_title(note.title);
            tooltip_text = note.title;
        }

        private static string initial_for_title(string title) {
            var trimmed_title = title.strip();
            if (trimmed_title.length == 0) {
                return "?";
            }

            var first_character = trimmed_title.get_char(0);
            return first_character.toupper().to_string();
        }
    }

    [GtkTemplate(ui = "/com/knotes/app/note_list_box.ui")]
    public class NoteListBox : Gtk.Box {
        [GtkChild]
        private unowned Gtk.Stack view_stack;
        [GtkChild]
        private unowned Gtk.ListBox list_box;
        [GtkChild]
        private unowned Gtk.ListBox compact_list_box;
        [GtkChild]
        private unowned Gtk.Entry search_entry;
        private NoteRepository repository;
        private HashMap<string, Note> notes_map;
        private HashMap<string, NoteRow> rows_map;
        private HashMap<string, CompactNoteRow> compact_rows_map;
        private string? selected_id = null;
        private bool is_compact = false;

        public bool compact {
            get {
                return is_compact;
            }
            set {
                if (is_compact == value) return;

                is_compact = value;
                view_stack.set_visible_child_name(is_compact ? "compact" : "expanded");
                select_visible_row(selected_id);
            }
        }

        public signal void note_selected(string? id);

        public NoteListBox(NoteRepository repository) {
            Object();
            this.repository = repository;
            this.notes_map = new HashMap<string, Note>();
            this.rows_map = new HashMap<string, NoteRow>();
            this.compact_rows_map = new HashMap<string, CompactNoteRow>();
            load_notes();
            connect_signals();
        }

        private void connect_signals() {
            search_entry.changed.connect(on_search_changed);
            list_box.row_activated.connect(on_row_activated);
            compact_list_box.row_activated.connect(on_compact_row_activated);
            repository.note_updated.connect(on_external_note_updated);
            repository.note_deleted.connect(on_external_note_deleted);
        }

        private void load_notes() {
            list_box.remove_all();
            notes_map.clear();
            rows_map.clear();
            compact_list_box.remove_all();
            compact_rows_map.clear();
            selected_id = null;

            var notes = repository.list_all();
            notes.sort((a, b) => {
                return a.created_at.compare(b.created_at);
            });

            foreach (var note in notes) {
                insert_note(note);
            }
        }

        private void add_note_row(Note note) {
            var row = new NoteRow(note);
            rows_map[note.id] = row;
            list_box.append(row);

            var compact_row = new CompactNoteRow(note);
            compact_rows_map[note.id] = compact_row;
            compact_list_box.append(compact_row);
        }

        private void insert_note(Note note) {
            notes_map[note.id] = note;
            add_note_row(note);
        }

        private void select_note(string? id) {
            selected_id = id;
            select_visible_row(id);
            note_selected(id);
        }

        private void select_visible_row(string? id) {
            if (id == null) {
                list_box.select_row(null);
                compact_list_box.select_row(null);
                return;
            }

            var row = rows_map[id];
            var compact_row = compact_rows_map[id];
            list_box.select_row(row);
            compact_list_box.select_row(compact_row);
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

                var compact_row = compact_rows_map[entry.key];
                if (compact_row != null) {
                    compact_row.visible = visible;
                }
            }
        }

        private void on_row_activated(Gtk.ListBoxRow row) {
            var note_row = row as NoteRow;
            if (note_row != null) {
                select_note(note_row.note_id);
            }
        }

        private void on_compact_row_activated(Gtk.ListBoxRow row) {
            var compact_note_row = row as CompactNoteRow;
            if (compact_note_row != null) {
                select_note(compact_note_row.note_id);
            }
        }

        /**
         * Creates a new note and adds it to the list.
         */
        public void create_note(Note note) {
            insert_note(note);

            var row = rows_map[note.id];
            if (row != null) {
                list_box.select_row(row);
            }

            select_note(note.id);
        }

        /**
         * Updates the note with the given ID.
         */
        public void update_note(Note note) {
            notes_map[note.id] = note;
            var note_row = rows_map[note.id];
            if (note_row != null) {
                note_row.update(note);
            }

            var compact_note_row = compact_rows_map[note.id];
            if (compact_note_row != null) {
                compact_note_row.update(note);
            }
        }

        /**
         * Removes the note with the given ID.
         */
        public void remove_note(string id) {
            var row = rows_map[id];
            var compact_row = compact_rows_map[id];

            notes_map.unset(id);
            rows_map.unset(id);
            compact_rows_map.unset(id);

            if (row != null) {
                list_box.remove(row);
            }
            if (compact_row != null) {
                compact_list_box.remove(compact_row);
            }
        }

        private void on_external_note_updated(string id) {
            var note = repository.load_note(id);
            if (note == null) return;

            if (rows_map.has_key(note.id)) {
                update_note(note);
            } else {
                insert_note(note);
            }

            if (selected_id == id) {
                note_selected(id);
            }
        }

        private void on_external_note_deleted(string id) {
            if (selected_id == id) {
                select_note(null);
            }
            remove_note(id);
        }
    }
}
