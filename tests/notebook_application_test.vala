namespace Knotes.Tests {

    private class InMemoryNotebookRepository : NotebookRepository {
        private Gee.HashMap<string, Note> notes = new Gee.HashMap<string, Note>();
        private Gee.HashMap<string, Folder> folders = new Gee.HashMap<string, Folder>();

        public void seed_note(Note note) {
            notes[note.id] = note;
        }

        public void seed_folder(Folder folder) {
            folders[folder.id] = folder;
        }

        public override GLib.List<Note> list_notes() {
            var result = new GLib.List<Note>();
            foreach (var note in notes.values) {
                result.append(note);
            }
            return result;
        }

        public override Note? load_note(string id) {
            return notes[id];
        }

        public override void save_note(Note note) {
            notes[note.id] = note;
        }

        public override void delete_note(string id) {
            notes.unset(id);
        }

        public override GLib.List<Folder> list_folders() {
            var result = new GLib.List<Folder>();
            foreach (var folder in folders.values) {
                result.append(folder);
            }
            return result;
        }

        public override void save_folders(GLib.List<Folder> saved_folders) {
            folders.clear();
            foreach (var folder in saved_folders) {
                folders[folder.id] = folder;
            }
        }
    }

    private Note create_note(
        string id,
        string title,
        string content,
        string folder_id,
        int64 created_at
    ) {
        var timestamp = new DateTime.from_unix_utc(created_at);
        return new Note(id, title, content, timestamp, timestamp, folder_id);
    }

    private void test_notes_are_sorted_by_creation_time() {
        var catalog = new NotebookCatalog();
        var notes = new GLib.List<Note>();
        notes.append(create_note("newer", "Newer", "", "", 20));
        notes.append(create_note("older", "Older", "", "", 10));
        catalog.replace_notes(notes);

        var sorted_notes = catalog.notes_sorted_by_creation();

        assert(sorted_notes.size == 2);
        assert(sorted_notes[0].id == "older");
        assert(sorted_notes[1].id == "newer");
    }

    private void test_orphaned_folder_is_treated_as_root() {
        var catalog = new NotebookCatalog();
        var folders = new GLib.List<Folder>();
        folders.append(new Folder("orphan", "Orphan", "missing-parent"));
        catalog.replace_folders(folders);

        var root_folders = catalog.child_folders(null);

        assert(root_folders.size == 1);
        assert(root_folders[0].id == "orphan");
    }

    private void test_parent_matches_note_in_nested_folder() {
        var catalog = new NotebookCatalog();
        var folders = new GLib.List<Folder>();
        folders.append(new Folder("parent", "Parent"));
        folders.append(new Folder("child", "Child", "parent"));
        catalog.replace_folders(folders);

        var notes = new GLib.List<Note>();
        notes.append(create_note("note", "Result", "search target", "child", 10));
        catalog.replace_notes(notes);

        assert(catalog.folder_contains_matching_note("parent", "target"));
        assert(!catalog.folder_contains_matching_note("parent", "absent"));
    }

    private void test_folder_search_handles_cycles() {
        var catalog = new NotebookCatalog();
        var folders = new GLib.List<Folder>();
        folders.append(new Folder("first", "First", "second"));
        folders.append(new Folder("second", "Second", "first"));
        catalog.replace_folders(folders);
        catalog.replace_notes(new GLib.List<Note>());

        assert(!catalog.folder_contains_matching_note("first", "anything"));
    }

    private void test_delete_folder_moves_its_contents_to_parent() {
        var repository = new InMemoryNotebookRepository();
        repository.seed_folder(new Folder("parent", "Parent"));
        repository.seed_folder(new Folder("deleted", "Deleted", "parent"));
        repository.seed_folder(new Folder("child", "Child", "deleted"));
        repository.seed_note(create_note("note", "Note", "", "deleted", 10));
        var service = new NotebookService(repository);

        assert(service.delete_folder("deleted"));

        var moved_note = service.find_note("note");
        var moved_child = service.catalog.find_folder("child");
        assert(moved_note != null && moved_note.folder_id == "parent");
        assert(moved_child != null && moved_child.parent_id == "parent");
        assert(service.catalog.find_folder("deleted") == null);
    }

    public static int main(string[] args) {
        Test.init(ref args);
        Test.add_func(
            "/notebook-catalog/sorts-notes-by-creation-time",
            test_notes_are_sorted_by_creation_time
        );
        Test.add_func(
            "/notebook-catalog/treats-orphaned-folder-as-root",
            test_orphaned_folder_is_treated_as_root
        );
        Test.add_func(
            "/notebook-catalog/matches-note-in-nested-folder",
            test_parent_matches_note_in_nested_folder
        );
        Test.add_func(
            "/notebook-catalog/handles-folder-cycles",
            test_folder_search_handles_cycles
        );
        Test.add_func(
            "/notebook-service/delete-folder-moves-contents-to-parent",
            test_delete_folder_moves_its_contents_to_parent
        );
        return Test.run();
    }
}
