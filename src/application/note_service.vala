namespace Knotes {

    public class NoteService : GLib.Object {
        private NoteRepository repository;
        private NoteAssetRepository asset_repository;
        private NotebookWorkspace workspace;

        public NoteService(
            NoteRepository repository,
            NoteAssetRepository asset_repository,
            NotebookWorkspace workspace
        ) {
            this.repository = repository;
            this.asset_repository = asset_repository;
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

        public DuplicateNoteResult duplicate_note(string source_id, string duplicate_title) {
            var source = workspace.catalog.find_note(source_id);
            if (source == null) {
                return new DuplicateNoteResult(DuplicateNoteStatus.SOURCE_NOT_FOUND);
            }

            var duplicate = new Note.with_new_content(
                duplicate_title,
                source.content,
                source.folder_id
            );
            try {
                repository.save_note(duplicate);
                asset_repository.copy_referenced_assets(
                    source.id,
                    duplicate.id,
                    source.content
                );
                workspace.catalog.upsert_note(duplicate);
                return DuplicateNoteResult.duplicated(duplicate);
            } catch (GLib.Error error) {
                roll_back_duplicate(duplicate.id);
                warning(
                    "Failed to duplicate note '%s' as '%s': %s",
                    source.id,
                    duplicate.id,
                    error.message
                );
                return new DuplicateNoteResult(DuplicateNoteStatus.STORAGE_ERROR);
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

        private void roll_back_duplicate(string duplicate_id) {
            try {
                repository.delete_note(duplicate_id);
            } catch (GLib.Error error) {
                warning(
                    "Failed to roll back duplicated note '%s': %s",
                    duplicate_id,
                    error.message
                );
            }
        }
    }
}
