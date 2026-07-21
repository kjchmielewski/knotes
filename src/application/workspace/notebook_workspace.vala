namespace Knotes {

    public class NotebookWorkspace : GLib.Object {
        private NoteRepository note_repository;

        public NotebookCatalog catalog { get; private set; }

        public signal void external_note_updated(string id);
        public signal void external_note_deleted(string id);

        public NotebookWorkspace(
            NoteRepository note_repository,
            FolderRepository folder_repository
        ) {
            this.note_repository = note_repository;
            catalog = new NotebookCatalog();
            catalog.replace_folders(folder_repository.list_folders());
            catalog.replace_notes(note_repository.list_notes());

            note_repository.note_updated.connect(on_note_updated);
            note_repository.note_deleted.connect(on_note_deleted);
        }

        public Note? find_note(string id) {
            return catalog.find_note(id);
        }

        private void on_note_updated(string id) {
            var note = note_repository.load_note(id);
            if (note == null) {
                return;
            }

            catalog.upsert_note(note);
            external_note_updated(id);
        }

        private void on_note_deleted(string id) {
            catalog.remove_note(id);
            external_note_deleted(id);
        }
    }
}
