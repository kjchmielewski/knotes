namespace Knotes {

    public class NotebookService : GLib.Object {
        private NotebookRepository repository;

        public NotebookCatalog catalog { get; private set; }

        public signal void external_note_updated(string id);
        public signal void external_note_deleted(string id);

        public NotebookService(NotebookRepository repository) {
            this.repository = repository;
            catalog = new NotebookCatalog();
            catalog.replace_folders(repository.list_folders());
            catalog.replace_notes(repository.list_notes());

            repository.note_updated.connect(on_repository_note_updated);
            repository.note_deleted.connect(on_repository_note_deleted);
        }

        public Note? find_note(string id) {
            return catalog.find_note(id);
        }

        public Note create_note(string title, string content, string folder_id = "") {
            var note = new Note.with_new_content(title, content, folder_id);
            repository.save_note(note);
            catalog.upsert_note(note);
            return note;
        }

        public void save_note(Note note) {
            repository.save_note(note);
            catalog.upsert_note(note);
        }

        public void delete_note(string id) {
            repository.delete_note(id);
            catalog.remove_note(id);
        }

        public Folder? create_folder(string name, string? parent_id) {
            var normalized_name = name.strip();
            if (normalized_name.length == 0) {
                return null;
            }

            var folder = new Folder(Uuid.string_random(), normalized_name, parent_id);
            catalog.upsert_folder(folder);
            persist_folders();
            return folder;
        }

        public bool delete_folder(string id) {
            var folder = catalog.find_folder(id);
            if (folder == null) {
                return false;
            }

            string? parent_id = folder.parent_id != null && catalog.contains_folder(folder.parent_id)
                ? folder.parent_id
                : null;
            var note_folder_id = parent_id ?? "";

            foreach (var note in catalog.all_notes()) {
                if (note.folder_id != folder.id) {
                    continue;
                }
                note.folder_id = note_folder_id;
                note.updated_at = new DateTime.now_utc();
                repository.save_note(note);
            }

            foreach (var child in catalog.all_folders()) {
                if (child.parent_id == folder.id) {
                    child.parent_id = parent_id;
                }
            }

            catalog.remove_folder(folder.id);
            persist_folders();
            return true;
        }

        private void persist_folders() {
            var folders = new GLib.List<Folder>();
            foreach (var folder in catalog.all_folders()) {
                folders.append(folder);
            }
            repository.save_folders(folders);
        }

        private void on_repository_note_updated(string id) {
            var note = repository.load_note(id);
            if (note == null) {
                return;
            }

            catalog.upsert_note(note);
            external_note_updated(id);
        }

        private void on_repository_note_deleted(string id) {
            catalog.remove_note(id);
            external_note_deleted(id);
        }
    }
}
