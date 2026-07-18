namespace Knotes {

    public class NoteService : GLib.Object {
        private NoteRepository repository;
        private NotebookWorkspace workspace;

        public NoteService(NoteRepository repository, NotebookWorkspace workspace) {
            this.repository = repository;
            this.workspace = workspace;
        }

        public Note? find_note(string id) {
            return workspace.find_note(id);
        }

        public Note? create_note(string title, string content, string folder_id = "") {
            var note = new Note.with_new_content(title, content, folder_id);
            try {
                repository.save_note(note);
                workspace.catalog.upsert_note(note);
                return note;
            } catch (GLib.Error error) {
                warning("Failed to create note '%s': %s", note.id, error.message);
                return null;
            }
        }

        public bool save_note(Note note) {
            try {
                repository.save_note(note);
                workspace.catalog.upsert_note(note);
                return true;
            } catch (GLib.Error error) {
                warning("Failed to save note '%s': %s", note.id, error.message);
                return false;
            }
        }

        public bool delete_note(string id) {
            try {
                repository.delete_note(id);
                workspace.catalog.remove_note(id);
                return true;
            } catch (GLib.Error error) {
                warning("Failed to delete note '%s': %s", id, error.message);
                return false;
            }
        }

        public MoveResult move_note(string note_id, string? destination_folder_id) {
            var note = workspace.catalog.find_note(note_id);
            if (note == null) {
                return MoveResult.SOURCE_NOT_FOUND;
            }
            if (destination_folder_id != null && !workspace.catalog.contains_folder(destination_folder_id)) {
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
                workspace.catalog.upsert_note(note);
                return MoveResult.MOVED;
            } catch (GLib.Error error) {
                note.folder_id = previous_folder_id;
                note.updated_at = previous_updated_at;
                warning("Failed to move note '%s': %s", note.id, error.message);
                return MoveResult.STORAGE_ERROR;
            }
        }
    }
}
