namespace Knotes {

    public class FolderService : GLib.Object {
        private FolderRepository folder_repository;
        private NoteRepository note_repository;
        private NotebookWorkspace workspace;

        public FolderService(
            FolderRepository folder_repository,
            NoteRepository note_repository,
            NotebookWorkspace workspace
        ) {
            this.folder_repository = folder_repository;
            this.note_repository = note_repository;
            this.workspace = workspace;
        }

        public Folder? create_folder(string name, string? parent_id) {
            var normalized_name = name.strip();
            if (normalized_name.length == 0) {
                return null;
            }

            var folder = new Folder(Uuid.string_random(), normalized_name, parent_id);
            workspace.catalog.upsert_folder(folder);
            try {
                persist_folders();
                return folder;
            } catch (GLib.Error error) {
                workspace.catalog.remove_folder(folder.id);
                warning("Failed to create folder '%s': %s", folder.id, error.message);
                return null;
            }
        }

        public RenameFolderResult rename_folder(string folder_id, string new_name) {
            var folder = workspace.catalog.find_folder(folder_id);
            if (folder == null) {
                return RenameFolderResult.SOURCE_NOT_FOUND;
            }

            var normalized_name = new_name.strip();
            if (normalized_name.length == 0) {
                return RenameFolderResult.INVALID_NAME;
            }
            if (folder.name == normalized_name) {
                return RenameFolderResult.UNCHANGED;
            }

            var previous_name = folder.name;
            folder.name = normalized_name;
            try {
                persist_folders();
                return RenameFolderResult.RENAMED;
            } catch (GLib.Error error) {
                folder.name = previous_name;
                warning("Failed to rename folder '%s': %s", folder.id, error.message);
                return RenameFolderResult.STORAGE_ERROR;
            }
        }

        public MoveResult move_folder(string folder_id, string? destination_parent_id) {
            var folder = workspace.catalog.find_folder(folder_id);
            if (folder == null) {
                return MoveResult.SOURCE_NOT_FOUND;
            }
            if (destination_parent_id != null && !workspace.catalog.contains_folder(destination_parent_id)) {
                return MoveResult.DESTINATION_NOT_FOUND;
            }
            if (workspace.catalog.would_create_folder_cycle(folder_id, destination_parent_id)) {
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
            var folder = workspace.catalog.find_folder(id);
            if (folder == null) {
                return false;
            }

            string? parent_id = folder.parent_id != null && workspace.catalog.contains_folder(folder.parent_id)
                ? folder.parent_id
                : null;
            var moved_notes = move_notes_to_parent(folder, parent_id);
            if (moved_notes == null) {
                return false;
            }

            var moved_children = reparent_children(folder.id, parent_id);
            workspace.catalog.remove_folder(folder.id);
            try {
                persist_folders();
                return true;
            } catch (GLib.Error error) {
                workspace.catalog.upsert_folder(folder);
                restore_children(moved_children, folder.id);
                restore_moved_notes(moved_notes, folder.id);
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

        private Gee.HashMap<Note, DateTime>? move_notes_to_parent(Folder folder, string? parent_id) {
            var moved_notes = new Gee.HashMap<Note, DateTime>();
            var destination_id = parent_id ?? "";
            foreach (var note in workspace.catalog.all_notes()) {
                if (note.folder_id != folder.id) {
                    continue;
                }

                var previous_updated_at = note.updated_at;
                note.folder_id = destination_id;
                note.updated_at = new DateTime.now_utc();
                try {
                    note_repository.save_note(note);
                    moved_notes[note] = previous_updated_at;
                } catch (GLib.Error error) {
                    note.folder_id = folder.id;
                    note.updated_at = previous_updated_at;
                    restore_moved_notes(moved_notes, folder.id);
                    warning("Failed to move note '%s' while deleting folder: %s", note.id, error.message);
                    return null;
                }
            }
            return moved_notes;
        }

        private Gee.ArrayList<Folder> reparent_children(string folder_id, string? parent_id) {
            var moved_children = new Gee.ArrayList<Folder>();
            foreach (var child in workspace.catalog.all_folders()) {
                if (child.parent_id == folder_id) {
                    child.parent_id = parent_id;
                    moved_children.add(child);
                }
            }
            return moved_children;
        }

        private void restore_children(Gee.List<Folder> children, string parent_id) {
            foreach (var child in children) {
                child.parent_id = parent_id;
            }
        }

        private void restore_moved_notes(Gee.Map<Note, DateTime> moved_notes, string folder_id) {
            foreach (var entry in moved_notes.entries) {
                var note = entry.key;
                note.folder_id = folder_id;
                note.updated_at = entry.value;
                try {
                    note_repository.save_note(note);
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
            foreach (var folder in workspace.catalog.all_folders()) {
                folders.append(folder);
            }
            folder_repository.save_folders(folders);
        }
    }
}
