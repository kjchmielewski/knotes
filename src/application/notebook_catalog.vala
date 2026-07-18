using Gee;

namespace Knotes {

    public class NotebookCatalog : GLib.Object {
        private HashMap<string, Note> notes_by_id;
        private HashMap<string, Folder> folders_by_id;

        public NotebookCatalog() {
            notes_by_id = new HashMap<string, Note>();
            folders_by_id = new HashMap<string, Folder>();
        }

        public void replace_notes(GLib.List<Note> notes) {
            notes_by_id.clear();
            foreach (var note in notes) {
                notes_by_id[note.id] = note;
            }
        }

        public void replace_folders(GLib.List<Folder> folders) {
            folders_by_id.clear();
            foreach (var folder in folders) {
                folders_by_id[folder.id] = folder;
            }
        }

        public Note? find_note(string id) {
            return notes_by_id[id];
        }

        public Folder? find_folder(string id) {
            return folders_by_id[id];
        }

        public bool contains_note(string id) {
            return notes_by_id.has_key(id);
        }

        public bool contains_folder(string id) {
            return folders_by_id.has_key(id);
        }

        public bool would_create_folder_cycle(string folder_id, string? destination_parent_id) {
            if (destination_parent_id == null) {
                return false;
            }

            var visited_folder_ids = new HashSet<string>();
            string? current_id = destination_parent_id;
            while (current_id != null) {
                if (current_id == folder_id || visited_folder_ids.contains(current_id)) {
                    return true;
                }
                visited_folder_ids.add(current_id);

                var current_folder = find_folder(current_id);
                if (current_folder == null) {
                    return false;
                }
                current_id = current_folder.parent_id;
            }
            return false;
        }

        public bool is_valid_folder_destination(string folder_id, string? destination_parent_id) {
            if (!contains_folder(folder_id)) {
                return false;
            }
            if (destination_parent_id != null && !contains_folder(destination_parent_id)) {
                return false;
            }
            return !would_create_folder_cycle(folder_id, destination_parent_id);
        }

        public void upsert_note(Note note) {
            notes_by_id[note.id] = note;
        }

        public void remove_note(string id) {
            notes_by_id.unset(id);
        }

        public void upsert_folder(Folder folder) {
            folders_by_id[folder.id] = folder;
        }

        public void remove_folder(string id) {
            folders_by_id.unset(id);
        }

        public ArrayList<Note> all_notes() {
            var notes = new ArrayList<Note>();
            notes.add_all(notes_by_id.values);
            return notes;
        }

        public ArrayList<Folder> all_folders() {
            var folders = new ArrayList<Folder>();
            folders.add_all(folders_by_id.values);
            return folders;
        }

        public ArrayList<Folder> folders_sorted_by_name() {
            var folders = all_folders();
            folders.sort((first, second) => first.name.collate(second.name));
            return folders;
        }

        public ArrayList<Note> notes_sorted_by_creation() {
            var notes = all_notes();
            notes.sort((first, second) => first.created_at.compare(second.created_at));
            return notes;
        }

        public ArrayList<Note> notes_for_folder(string folder_id) {
            var notes = new ArrayList<Note>();
            foreach (var note in notes_by_id.values) {
                if (note.folder_id == folder_id) {
                    notes.add(note);
                }
            }
            notes.sort((first, second) => first.created_at.compare(second.created_at));
            return notes;
        }

        public ArrayList<Folder> child_folders(string? parent_id) {
            var children = new ArrayList<Folder>();
            foreach (var candidate in folders_by_id.values) {
                var is_child = parent_id == null
                    ? candidate.parent_id == null || !folders_by_id.has_key(candidate.parent_id)
                    : candidate.parent_id == parent_id;
                if (is_child) {
                    children.add(candidate);
                }
            }
            children.sort((first, second) => first.name.collate(second.name));
            return children;
        }

        public bool folder_has_direct_notes(string folder_id) {
            foreach (var note in notes_by_id.values) {
                if (note.folder_id == folder_id) {
                    return true;
                }
            }
            return false;
        }

        public string? normalized_folder_id(Note note) {
            return note.folder_id.length > 0 && folders_by_id.has_key(note.folder_id)
                ? note.folder_id
                : null;
        }

        public bool note_matches_query(Note note, string query) {
            return note.title.down().contains(query) || note.content.down().contains(query);
        }

        public bool folder_contains_matching_note(string folder_id, string query) {
            return folder_contains_matching_note_recursive(
                folder_id,
                query,
                new HashSet<string>()
            );
        }

        private bool folder_contains_matching_note_recursive(
            string folder_id,
            string query,
            HashSet<string> visited_folder_ids
        ) {
            if (visited_folder_ids.contains(folder_id)) {
                return false;
            }
            visited_folder_ids.add(folder_id);

            foreach (var note in notes_by_id.values) {
                if (note.folder_id == folder_id && note_matches_query(note, query)) {
                    return true;
                }
            }
            foreach (var folder in child_folders(folder_id)) {
                if (folder_contains_matching_note_recursive(folder.id, query, visited_folder_ids)) {
                    return true;
                }
            }
            return false;
        }
    }
}
