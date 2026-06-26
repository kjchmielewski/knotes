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

    [GtkTemplate(ui = "/com/knotes/app/note_list_box.ui")]
    public class NoteListBox : Gtk.Box {
        [GtkChild]
        private unowned Gtk.ListBox list_box;
        [GtkChild]
        private unowned Gtk.Entry search_entry;
        private NoteRepository repository;
        private HashMap<string, Note> notes_map;
        private HashMap<string, NoteRow> rows_map;
        private string? selected_id = null;

        public signal void note_selected(string? id);

        public NoteListBox(NoteRepository repository) {
            Object();
            this.repository = repository;
            this.notes_map = new HashMap<string, Note>();
            this.rows_map = new HashMap<string, NoteRow>();
            load_notes();
            connect_signals();
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
         * Creates a new note and adds it to the list.
         */
        public void create_note(Note note) {
            notes_map[note.id] = note;
            add_note_row(note);

            var row = rows_map[note.id];
            if (row != null) {
                list_box.select_row(row);
            }

            selected_id = note.id;
            note_selected(note.id);
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
        }

        /**
         * Removes the note with the given ID.
         */
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

            if (rows_map.has_key(id)) {
                update_note(note);
            } else {
                notes_map[id] = note;
                add_note_row(note);
            }

            if (selected_id == id) {
                note_selected(id);
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
