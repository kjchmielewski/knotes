namespace Knotes.Tests {

    private class InMemoryNotebookRepository : GLib.Object, NoteRepository, FolderRepository, NoteAssetRepository {
        private Gee.HashMap<string, Note> notes = new Gee.HashMap<string, Note>();
        private Gee.HashMap<string, Folder> folders = new Gee.HashMap<string, Folder>();

        public bool fail_note_saves { get; set; default = false; }
        public bool fail_folder_saves { get; set; default = false; }
        public GLib.Error? asset_error { get; set; default = null; }
        public int folder_save_count { get; private set; default = 0; }

        public void seed_note(Note note) {
            notes[note.id] = note;
        }

        public void seed_folder(Folder folder) {
            folders[folder.id] = folder;
        }

        public void replace_note_externally(Note note) {
            notes[note.id] = note;
            note_updated(note.id);
        }

        public void delete_note_externally(string id) {
            notes.unset(id);
            note_deleted(id);
        }

        public GLib.List<Note> list_notes() {
            var result = new GLib.List<Note>();
            foreach (var note in notes.values) {
                result.append(note);
            }
            return result;
        }

        public Note? load_note(string id) {
            return notes[id];
        }

        public void save_note(Note note) throws GLib.Error {
            if (fail_note_saves) {
                throw new GLib.IOError.FAILED("Simulated note save failure");
            }
            notes[note.id] = note;
        }

        public void delete_note(string id) throws GLib.Error {
            notes.unset(id);
        }

        public string import_image_file(string note_id, GLib.File source_file) throws GLib.Error {
            if (asset_error != null) {
                throw asset_error;
            }
            return "assets/image.png";
        }

        public string import_image_bytes(
            string note_id,
            string suggested_filename,
            GLib.Bytes bytes
        ) throws GLib.Error {
            if (asset_error != null) {
                throw asset_error;
            }
            return "assets/pasted.png";
        }

        public AssetContent? load_asset(string note_id, string relative_path) throws GLib.Error {
            return new AssetContent(new GLib.Bytes("image".data), "image/png");
        }

        public GLib.List<Folder> list_folders() {
            var result = new GLib.List<Folder>();
            foreach (var folder in folders.values) {
                result.append(folder);
            }
            return result;
        }

        public void save_folders(GLib.List<Folder> saved_folders) throws GLib.Error {
            folder_save_count++;
            if (fail_folder_saves) {
                throw new GLib.IOError.FAILED("Simulated folder save failure");
            }
            folders.clear();
            foreach (var folder in saved_folders) {
                folders[folder.id] = folder;
            }
        }
    }

    private class TestServices : GLib.Object {
        private NoteService notes;
        private FolderService folders;
        private NoteAssetService assets;
        public NotebookCatalog catalog { get; private set; }

        public TestServices(InMemoryNotebookRepository repository) {
            var workspace = new NotebookWorkspace(repository, repository);
            catalog = workspace.catalog;
            notes = new NoteService(repository, workspace);
            folders = new FolderService(repository, repository, workspace);
            assets = new NoteAssetService(repository, workspace);
        }

        public Note? find_note(string id) { return notes.find_note(id); }
        public bool delete_folder(string id) { return folders.delete_folder(id); }
        public RenameFolderResult rename_folder(string id, string name) {
            return folders.rename_folder(id, name);
        }
        public MoveResult move_note(string id, string? destination_id) {
            return notes.move_note(id, destination_id);
        }
        public MoveResult move_folder(string id, string? destination_id) {
            return folders.move_folder(id, destination_id);
        }
        public AssetImportResult import_image_file(string id, GLib.File file) {
            return assets.import_image_file(id, file);
        }
        public AssetImportResult import_png_bytes(string id, GLib.Bytes bytes) {
            return assets.import_png_bytes(id, bytes);
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

    private void test_workspace_loads_and_synchronizes_external_notes() {
        var repository = new InMemoryNotebookRepository();
        repository.seed_note(create_note("note", "Initial", "", "", 10));
        var workspace = new NotebookWorkspace(repository, repository);
        var updated_id = "";
        var deleted_id = "";
        workspace.external_note_updated.connect((id) => updated_id = id);
        workspace.external_note_deleted.connect((id) => deleted_id = id);

        assert(workspace.find_note("note").title == "Initial");
        repository.replace_note_externally(create_note("note", "External", "", "", 10));
        assert(workspace.find_note("note").title == "External");
        assert(updated_id == "note");

        repository.delete_note_externally("note");
        assert(workspace.find_note("note") == null);
        assert(deleted_id == "note");
    }

    private void test_autosave_coordinator_reschedules_cancels_and_flushes() {
        var save_count = 0;
        var coordinator = new AutosaveCoordinator(() => save_count++);

        coordinator.schedule(1);
        coordinator.schedule(1);
        while (save_count == 0) {
            MainContext.default().iteration(true);
        }
        assert(save_count == 1);

        coordinator.schedule(1000);
        coordinator.cancel();
        while (MainContext.default().iteration(false)) {
        }
        assert(save_count == 1);

        coordinator.schedule(1000);
        coordinator.flush();
        assert(save_count == 2);
    }

    private void test_delete_folder_moves_its_contents_to_parent() {
        var repository = new InMemoryNotebookRepository();
        repository.seed_folder(new Folder("parent", "Parent"));
        repository.seed_folder(new Folder("deleted", "Deleted", "parent"));
        repository.seed_folder(new Folder("child", "Child", "deleted"));
        repository.seed_note(create_note("note", "Note", "", "deleted", 10));
        var service = new TestServices(repository);

        assert(service.delete_folder("deleted"));

        var moved_note = service.find_note("note");
        var moved_child = service.catalog.find_folder("child");
        assert(moved_note != null && moved_note.folder_id == "parent");
        assert(moved_child != null && moved_child.parent_id == "parent");
        assert(service.catalog.find_folder("deleted") == null);
    }

    private void test_delete_folder_rolls_back_when_folder_save_fails() {
        var repository = new InMemoryNotebookRepository();
        repository.seed_folder(new Folder("deleted", "Deleted"));
        repository.seed_folder(new Folder("child", "Child", "deleted"));
        repository.seed_note(create_note("note", "Note", "", "deleted", 10));
        var service = new TestServices(repository);

        repository.fail_folder_saves = true;
        Test.expect_message(
            null,
            LogLevelFlags.LEVEL_WARNING,
            "*Failed to roll back folder metadata*"
        );
        Test.expect_message(
            null,
            LogLevelFlags.LEVEL_WARNING,
            "*Failed to persist folder deletion*"
        );
        assert(!service.delete_folder("deleted"));
        Test.assert_expected_messages();

        assert(service.catalog.find_folder("deleted") != null);
        assert(service.catalog.find_folder("child").parent_id == "deleted");
        assert(service.find_note("note").folder_id == "deleted");
    }

    private void test_rename_folder_normalizes_name_and_preserves_identity() {
        var repository = new InMemoryNotebookRepository();
        repository.seed_folder(new Folder("parent", "Parent"));
        repository.seed_folder(new Folder("folder", "Old name", "parent"));
        repository.seed_folder(new Folder("child", "Child", "folder"));
        repository.seed_note(create_note("note", "Note", "", "folder", 10));
        var service = new TestServices(repository);

        assert(service.rename_folder("folder", "  New name  ") == RenameFolderResult.RENAMED);

        var renamed_folder = service.catalog.find_folder("folder");
        assert(renamed_folder != null);
        assert(renamed_folder.id == "folder");
        assert(renamed_folder.name == "New name");
        assert(renamed_folder.parent_id == "parent");
        assert(service.catalog.find_folder("child").parent_id == "folder");
        assert(service.find_note("note").folder_id == "folder");
        assert(repository.folder_save_count == 1);
    }

    private void test_rename_folder_rejects_invalid_and_unchanged_names() {
        var repository = new InMemoryNotebookRepository();
        repository.seed_folder(new Folder("folder", "Name"));
        var service = new TestServices(repository);

        assert(service.rename_folder("missing", "New") == RenameFolderResult.SOURCE_NOT_FOUND);
        assert(service.rename_folder("folder", "   ") == RenameFolderResult.INVALID_NAME);
        assert(service.rename_folder("folder", " Name ") == RenameFolderResult.UNCHANGED);
        assert(service.catalog.find_folder("folder").name == "Name");
        assert(repository.folder_save_count == 0);
    }

    private void test_rename_folder_rolls_back_when_save_fails() {
        var repository = new InMemoryNotebookRepository();
        repository.seed_folder(new Folder("folder", "Old name"));
        var service = new TestServices(repository);

        repository.fail_folder_saves = true;
        Test.expect_message(null, LogLevelFlags.LEVEL_WARNING, "*Failed to rename folder*");
        assert(service.rename_folder("folder", "New name") == RenameFolderResult.STORAGE_ERROR);
        Test.assert_expected_messages();
        assert(service.catalog.find_folder("folder").name == "Old name");
        assert(repository.folder_save_count == 1);
    }

    private void test_move_note_between_folder_and_root() {
        var repository = new InMemoryNotebookRepository();
        repository.seed_folder(new Folder("target", "Target"));
        repository.seed_note(create_note("note", "Note", "", "", 10));
        var service = new TestServices(repository);

        assert(service.move_note("note", "target") == MoveResult.MOVED);
        assert(service.find_note("note").folder_id == "target");
        assert(service.move_note("note", "target") == MoveResult.UNCHANGED);
        assert(service.move_note("note", null) == MoveResult.MOVED);
        assert(service.find_note("note").folder_id == "");
    }

    private void test_move_note_validates_destination_and_rolls_back() {
        var repository = new InMemoryNotebookRepository();
        repository.seed_folder(new Folder("target", "Target"));
        repository.seed_note(create_note("note", "Note", "", "", 10));
        var service = new TestServices(repository);

        assert(service.move_note("missing", "target") == MoveResult.SOURCE_NOT_FOUND);
        assert(service.move_note("note", "missing") == MoveResult.DESTINATION_NOT_FOUND);

        repository.fail_note_saves = true;
        Test.expect_message(null, LogLevelFlags.LEVEL_WARNING, "*Failed to move note*");
        assert(service.move_note("note", "target") == MoveResult.STORAGE_ERROR);
        Test.assert_expected_messages();
        assert(service.find_note("note").folder_id == "");
    }

    private void test_move_folder_changes_parent_and_rejects_cycles() {
        var repository = new InMemoryNotebookRepository();
        repository.seed_folder(new Folder("first", "First"));
        repository.seed_folder(new Folder("second", "Second"));
        repository.seed_folder(new Folder("child", "Child", "first"));
        var service = new TestServices(repository);

        assert(service.move_folder("child", "second") == MoveResult.MOVED);
        assert(service.catalog.find_folder("child").parent_id == "second");
        assert(service.move_folder("second", "child") == MoveResult.CYCLE_DETECTED);
        assert(service.move_folder("second", "second") == MoveResult.CYCLE_DETECTED);
        assert(service.move_folder("child", null) == MoveResult.MOVED);
        assert(service.catalog.find_folder("child").parent_id == null);
    }

    private void test_move_folder_validates_destination_and_rolls_back() {
        var repository = new InMemoryNotebookRepository();
        repository.seed_folder(new Folder("source", "Source"));
        repository.seed_folder(new Folder("target", "Target"));
        var service = new TestServices(repository);

        assert(service.move_folder("missing", "target") == MoveResult.SOURCE_NOT_FOUND);
        assert(service.move_folder("source", "missing") == MoveResult.DESTINATION_NOT_FOUND);

        repository.fail_folder_saves = true;
        Test.expect_message(null, LogLevelFlags.LEVEL_WARNING, "*Failed to move folder*");
        assert(service.move_folder("source", "target") == MoveResult.STORAGE_ERROR);
        Test.assert_expected_messages();
        assert(service.catalog.find_folder("source").parent_id == null);
    }

    private void test_import_image_returns_path_and_validates_note() {
        var repository = new InMemoryNotebookRepository();
        repository.seed_note(create_note("note", "Note", "", "", 10));
        var service = new TestServices(repository);

        var missing_result = service.import_image_file(
            "missing",
            File.new_for_path("/does/not/matter.png")
        );
        assert(missing_result.status == AssetImportStatus.NOTE_NOT_FOUND);
        assert(missing_result.relative_path == null);

        var imported_result = service.import_image_file(
            "note",
            File.new_for_path("/does/not/matter.png")
        );
        assert(imported_result.status == AssetImportStatus.IMPORTED);
        assert(imported_result.relative_path == "assets/image.png");

        var pasted_result = service.import_png_bytes(
            "note",
            new GLib.Bytes("png".data)
        );
        assert(pasted_result.status == AssetImportStatus.IMPORTED);
        assert(pasted_result.relative_path == "assets/pasted.png");
    }

    private void test_import_image_maps_repository_failures() {
        var repository = new InMemoryNotebookRepository();
        repository.seed_note(create_note("note", "Note", "", "", 10));
        var service = new TestServices(repository);

        repository.asset_error = new AssetStorageError.UNSUPPORTED_TYPE("unsupported");
        assert(
            service.import_image_file("note", File.new_for_path("image.xyz")).status ==
            AssetImportStatus.UNSUPPORTED_TYPE
        );

        repository.asset_error = new AssetStorageError.INVALID_SOURCE("invalid");
        assert(
            service.import_png_bytes("note", new GLib.Bytes("png".data)).status ==
            AssetImportStatus.INVALID_SOURCE
        );

        repository.asset_error = new AssetStorageError.NOT_FOUND("missing");
        assert(
            service.import_png_bytes("note", new GLib.Bytes("png".data)).status ==
            AssetImportStatus.NOTE_NOT_FOUND
        );

        repository.asset_error = new GLib.IOError.FAILED("storage");
        Test.expect_message(null, LogLevelFlags.LEVEL_WARNING, "*Failed to import image*");
        assert(
            service.import_png_bytes("note", new GLib.Bytes("png".data)).status ==
            AssetImportStatus.STORAGE_ERROR
        );
        Test.assert_expected_messages();
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
            "/notebook-workspace/synchronizes-external-notes",
            test_workspace_loads_and_synchronizes_external_notes
        );
        Test.add_func(
            "/autosave-coordinator/scheduling",
            test_autosave_coordinator_reschedules_cancels_and_flushes
        );
        Test.add_func(
            "/folder-service/delete-folder-moves-contents-to-parent",
            test_delete_folder_moves_its_contents_to_parent
        );
        Test.add_func(
            "/folder-service/delete-folder-rolls-back-on-save-failure",
            test_delete_folder_rolls_back_when_folder_save_fails
        );
        Test.add_func(
            "/folder-service/rename-folder-normalizes-name-and-preserves-identity",
            test_rename_folder_normalizes_name_and_preserves_identity
        );
        Test.add_func(
            "/folder-service/rename-folder-rejects-invalid-and-unchanged-names",
            test_rename_folder_rejects_invalid_and_unchanged_names
        );
        Test.add_func(
            "/folder-service/rename-folder-rolls-back-on-save-failure",
            test_rename_folder_rolls_back_when_save_fails
        );
        Test.add_func(
            "/note-service/move-note-between-folder-and-root",
            test_move_note_between_folder_and_root
        );
        Test.add_func(
            "/note-service/move-note-validates-and-rolls-back",
            test_move_note_validates_destination_and_rolls_back
        );
        Test.add_func(
            "/folder-service/move-folder-changes-parent-and-rejects-cycles",
            test_move_folder_changes_parent_and_rejects_cycles
        );
        Test.add_func(
            "/folder-service/move-folder-validates-and-rolls-back",
            test_move_folder_validates_destination_and_rolls_back
        );
        Test.add_func(
            "/note-asset-service/import-image-returns-path-and-validates-note",
            test_import_image_returns_path_and_validates_note
        );
        Test.add_func(
            "/note-asset-service/import-image-maps-repository-failures",
            test_import_image_maps_repository_failures
        );
        return Test.run();
    }
}
