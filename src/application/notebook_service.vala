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

        public Note? create_note(string title, string content, string folder_id = "") {
            var note = new Note.with_new_content(title, content, folder_id);
            try {
                repository.save_note(note);
                catalog.upsert_note(note);
                return note;
            } catch (GLib.Error error) {
                warning("Failed to create note '%s': %s", note.id, error.message);
                return null;
            }
        }

        public bool save_note(Note note) {
            try {
                repository.save_note(note);
                catalog.upsert_note(note);
                return true;
            } catch (GLib.Error error) {
                warning("Failed to save note '%s': %s", note.id, error.message);
                return false;
            }
        }

        public bool delete_note(string id) {
            try {
                repository.delete_note(id);
                catalog.remove_note(id);
                return true;
            } catch (GLib.Error error) {
                warning("Failed to delete note '%s': %s", id, error.message);
                return false;
            }
        }

        public Folder? create_folder(string name, string? parent_id) {
            var normalized_name = name.strip();
            if (normalized_name.length == 0) {
                return null;
            }

            var folder = new Folder(Uuid.string_random(), normalized_name, parent_id);
            catalog.upsert_folder(folder);
            try {
                persist_folders();
                return folder;
            } catch (GLib.Error error) {
                catalog.remove_folder(folder.id);
                warning("Failed to create folder '%s': %s", folder.id, error.message);
                return null;
            }
        }

        public MoveResult move_note(string note_id, string? destination_folder_id) {
            var note = catalog.find_note(note_id);
            if (note == null) {
                return MoveResult.SOURCE_NOT_FOUND;
            }
            if (destination_folder_id != null && !catalog.contains_folder(destination_folder_id)) {
                return MoveResult.DESTINATION_NOT_FOUND;
            }

            var normalized_destination_id = destination_folder_id ?? "";
            if (note.folder_id == normalized_destination_id) {
                return MoveResult.UNCHANGED;
            }

            var previous_folder_id = note.folder_id;
            var previous_updated_at = note.updated_at;
            note.folder_id = normalized_destination_id;
            note.updated_at = new DateTime.now_utc();
            try {
                repository.save_note(note);
                catalog.upsert_note(note);
                return MoveResult.MOVED;
            } catch (GLib.Error error) {
                note.folder_id = previous_folder_id;
                note.updated_at = previous_updated_at;
                warning("Failed to move note '%s': %s", note.id, error.message);
                return MoveResult.STORAGE_ERROR;
            }
        }

        public MoveResult move_folder(string folder_id, string? destination_parent_id) {
            var folder = catalog.find_folder(folder_id);
            if (folder == null) {
                return MoveResult.SOURCE_NOT_FOUND;
            }
            if (destination_parent_id != null && !catalog.contains_folder(destination_parent_id)) {
                return MoveResult.DESTINATION_NOT_FOUND;
            }
            if (catalog.would_create_folder_cycle(folder_id, destination_parent_id)) {
                return MoveResult.CYCLE_DETECTED;
            }
            if (folder.parent_id == destination_parent_id) {
                return MoveResult.UNCHANGED;
            }

            var previous_parent_id = folder.parent_id;
            folder.parent_id = destination_parent_id;
            try {
                persist_folders();
                return MoveResult.MOVED;
            } catch (GLib.Error error) {
                folder.parent_id = previous_parent_id;
                warning("Failed to move folder '%s': %s", folder.id, error.message);
                return MoveResult.STORAGE_ERROR;
            }
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
            var moved_notes = new Gee.ArrayList<Note>();
            var previous_note_update_times = new Gee.HashMap<string, DateTime>();

            foreach (var note in catalog.all_notes()) {
                if (note.folder_id != folder.id) {
                    continue;
                }
                var previous_updated_at = note.updated_at;
                note.folder_id = note_folder_id;
                note.updated_at = new DateTime.now_utc();
                try {
                    repository.save_note(note);
                    moved_notes.add(note);
                    previous_note_update_times[note.id] = previous_updated_at;
                } catch (GLib.Error error) {
                    note.folder_id = folder.id;
                    note.updated_at = previous_updated_at;
                    restore_moved_notes(
                        moved_notes,
                        previous_note_update_times,
                        folder.id
                    );
                    warning("Failed to move note '%s' while deleting folder: %s", note.id, error.message);
                    return false;
                }
            }

            var moved_children = new Gee.ArrayList<Folder>();
            foreach (var child in catalog.all_folders()) {
                if (child.parent_id == folder.id) {
                    child.parent_id = parent_id;
                    moved_children.add(child);
                }
            }

            catalog.remove_folder(folder.id);
            try {
                persist_folders();
                return true;
            } catch (GLib.Error error) {
                catalog.upsert_folder(folder);
                foreach (var child in moved_children) {
                    child.parent_id = folder.id;
                }
                restore_moved_notes(moved_notes, previous_note_update_times, folder.id);
                try {
                    persist_folders();
                } catch (GLib.Error rollback_error) {
                    warning(
                        "Failed to roll back folder metadata after deleting '%s': %s",
                        folder.id,
                        rollback_error.message
                    );
                }
                warning("Failed to persist folder deletion '%s': %s", folder.id, error.message);
                return false;
            }
        }

        private void restore_moved_notes(
            Gee.ArrayList<Note> moved_notes,
            Gee.HashMap<string, DateTime> previous_update_times,
            string folder_id
        ) {
            foreach (var note in moved_notes) {
                note.folder_id = folder_id;
                note.updated_at = previous_update_times[note.id];
                try {
                    repository.save_note(note);
                } catch (GLib.Error error) {
                    warning(
                        "Failed to roll back note '%s' after folder deletion: %s",
                        note.id,
                        error.message
                    );
                }
            }
        }

        private void persist_folders() throws GLib.Error {
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
