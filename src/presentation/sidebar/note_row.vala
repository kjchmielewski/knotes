namespace Knotes {

    [GtkTemplate(ui = "/com/knotes/app/note_row.ui")]
    public class NoteRow : Gtk.ListBoxRow {
        [GtkChild]
        private unowned Gtk.Label title_label;
        [GtkChild]
        private unowned Gtk.Label preview_label;

        public string note_id { get; construct; }
        public string folder_id { get; private set; default = ""; }

        public NoteRow(Note note) {
            Object(note_id: note.id);
            update(note);
        }

        public void update(Note note) {
            folder_id = note.folder_id;
            title_label.label = note.title;
            preview_label.label = note.preview(60);
        }
    }
}
