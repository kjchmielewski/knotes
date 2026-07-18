namespace Knotes.Tests {

    private class JsonRepositoryFixture : GLib.Object {
        private JsonNoteRepository note_repository;
        private JsonNoteAssetRepository asset_repository;

        public JsonRepositoryFixture(string notes_directory) {
            var layout = new JsonStorageLayout(notes_directory);
            var asset_storage = new JsonNoteAssetStorage(layout);
            note_repository = new JsonNoteRepository(layout, asset_storage);
            asset_repository = new JsonNoteAssetRepository(asset_storage);
        }

        public void save_note(Note note) throws GLib.Error {
            note_repository.save_note(note);
        }

        public void delete_note(string id) throws GLib.Error {
            note_repository.delete_note(id);
        }

        public Note? load_note(string id) {
            return note_repository.load_note(id);
        }

        public GLib.List<Note> list_notes() {
            return note_repository.list_notes();
        }

        public string import_image_file(string note_id, GLib.File source) throws GLib.Error {
            return asset_repository.import_image_file(note_id, source);
        }

        public string import_image_bytes(
            string note_id,
            string filename,
            GLib.Bytes bytes
        ) throws GLib.Error {
            return asset_repository.import_image_bytes(note_id, filename, bytes);
        }

        public AssetContent? load_asset(string note_id, string path) throws GLib.Error {
            return asset_repository.load_asset(note_id, path);
        }
    }

    private GLib.Bytes png_bytes() {
        var encoded = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=";
        return new GLib.Bytes(Base64.decode(encoded));
    }

    private Note new_note(string id, string content = "") {
        var now = new DateTime.now_utc();
        return new Note(id, "Images", content, now, now);
    }

    private string temporary_notes_directory() throws GLib.Error {
        var root = DirUtils.make_tmp("knotes-assets-test-XXXXXX");
        return Path.build_filename(root, "notes");
    }

    private void delete_recursively(GLib.File file) throws GLib.Error {
        if (!file.query_exists()) {
            return;
        }
        var info = file.query_info(FileAttribute.STANDARD_TYPE, FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
        if (info.get_file_type() == FileType.DIRECTORY) {
            var enumerator = file.enumerate_children(
                FileAttribute.STANDARD_NAME,
                FileQueryInfoFlags.NOFOLLOW_SYMLINKS
            );
            FileInfo child_info;
            while ((child_info = enumerator.next_file()) != null) {
                delete_recursively(file.get_child(child_info.get_name()));
            }
        }
        file.delete();
    }

    private void cleanup(GLib.File root) {
        try {
            delete_recursively(root);
        } catch (GLib.Error error) {
            warning("Failed to clean test directory: %s", error.message);
        }
    }

    private void imports_images_with_safe_unique_names() throws GLib.Error {
        var notes_directory = temporary_notes_directory();
        var root = File.new_for_path(Path.get_dirname(notes_directory));
        try {
            var repository = new JsonRepositoryFixture(notes_directory);
            var note = new_note(Uuid.string_random());
            repository.save_note(note);

            var source_directory = File.new_for_path(Path.build_filename(root.get_path(), "source"));
            source_directory.make_directory_with_parents();
            var source = source_directory.get_child("Diagram File.PNG");
            var source_bytes = png_bytes();
            unowned uint8[] png_data = source_bytes.get_data();
            string? etag;
            source.replace_contents(
                png_data,
                null,
                false,
                FileCreateFlags.REPLACE_DESTINATION,
                out etag
            );

            assert(repository.import_image_file(note.id, source) == "assets/diagram-file.png");
            assert(repository.import_image_file(note.id, source) == "assets/diagram-file-2.png");
            assert(repository.import_image_bytes(note.id, "pasted.png", png_bytes()) == "assets/pasted.png");

            var loaded = repository.load_asset(note.id, "assets/diagram-file.png");
            assert(loaded != null);
            assert(loaded.content_type == "image/png");
            assert(loaded.bytes.compare(png_bytes()) == 0);
            assert(repository.list_notes().length() == 1);
        } finally {
            cleanup(root);
        }
    }

    private void rejects_invalid_asset_inputs_and_paths() throws GLib.Error {
        var notes_directory = temporary_notes_directory();
        var root = File.new_for_path(Path.get_dirname(notes_directory));
        try {
            var repository = new JsonRepositoryFixture(notes_directory);
            var note = new_note(Uuid.string_random());
            repository.save_note(note);

            try {
                repository.import_image_bytes(note.id, "image.txt", png_bytes());
                assert_not_reached();
            } catch (AssetStorageError error) {
                assert(error is AssetStorageError.UNSUPPORTED_TYPE);
            }

            try {
                repository.import_image_bytes(note.id, "image.png", new GLib.Bytes("not png".data));
                assert_not_reached();
            } catch (AssetStorageError error) {
                assert(error is AssetStorageError.INVALID_SOURCE);
            }

            try {
                repository.load_asset(note.id, "assets/../secret.png");
                assert_not_reached();
            } catch (AssetStorageError error) {
                assert(error is AssetStorageError.INVALID_SOURCE);
            }
        } finally {
            cleanup(root);
        }
    }

    private void prunes_assets_only_after_a_later_session() throws GLib.Error {
        var notes_directory = temporary_notes_directory();
        var root = File.new_for_path(Path.get_dirname(notes_directory));
        try {
            var note_id = Uuid.string_random();
            var repository = new JsonRepositoryFixture(notes_directory);
            var note = new_note(note_id);
            repository.save_note(note);
            var relative_path = repository.import_image_bytes(note.id, "pasted.png", png_bytes());

            note.content = "![Image](%s)".printf(relative_path);
            repository.save_note(note);
            note.content = "";
            repository.save_note(note);

            var asset_path = Path.build_filename(notes_directory, note.id, "assets", "pasted.png");
            assert(File.new_for_path(asset_path).query_exists());

            var reopened_repository = new JsonRepositoryFixture(notes_directory);
            assert(reopened_repository.load_asset(note.id, relative_path) == null);
            assert(reopened_repository.load_note(note.id) != null);
        } finally {
            cleanup(root);
        }
    }

    private void deleting_note_removes_its_assets() throws GLib.Error {
        var notes_directory = temporary_notes_directory();
        var root = File.new_for_path(Path.get_dirname(notes_directory));
        try {
            var repository = new JsonRepositoryFixture(notes_directory);
            var note = new_note(Uuid.string_random());
            repository.save_note(note);
            repository.import_image_bytes(note.id, "pasted.png", png_bytes());

            var asset_root = File.new_for_path(Path.build_filename(notes_directory, note.id));
            assert(asset_root.query_exists());
            repository.delete_note(note.id);
            assert(!asset_root.query_exists());
            assert(repository.load_note(note.id) == null);
        } finally {
            cleanup(root);
        }
    }

    private bool wait_for_value(string expected, ref string actual) {
        var deadline = GLib.get_monotonic_time() + (2 * TimeSpan.SECOND);
        while (actual != expected && GLib.get_monotonic_time() < deadline) {
            MainContext.default().iteration(false);
            Thread.usleep(1000);
        }
        return actual == expected;
    }

    private void monitor_reports_external_note_changes() throws GLib.Error {
        var notes_directory = temporary_notes_directory();
        var root = File.new_for_path(Path.get_dirname(notes_directory));
        try {
            var layout = new JsonStorageLayout(notes_directory);
            var storage = new JsonNoteAssetStorage(layout);
            var repository = new JsonNoteRepository(layout, storage);
            var updated_id = "";
            var deleted_id = "";
            repository.note_updated.connect((id) => updated_id = id);
            repository.note_deleted.connect((id) => deleted_id = id);

            var note = new_note(Uuid.string_random());
            var root_node = new Json.Node(Json.NodeType.OBJECT);
            root_node.set_object(NoteJsonMapper.to_json(note));
            var generator = new Json.Generator();
            generator.set_root(root_node);
            generator.to_file(layout.note_path(note.id));
            assert(wait_for_value(note.id, ref updated_id));

            File.new_for_path(layout.note_path(note.id)).delete();
            assert(wait_for_value(note.id, ref deleted_id));
        } finally {
            cleanup(root);
        }
    }

    private void folders_round_trip_in_sibling_json_file() throws GLib.Error {
        var notes_directory = temporary_notes_directory();
        var root = File.new_for_path(Path.get_dirname(notes_directory));
        try {
            var layout = new JsonStorageLayout(notes_directory);
            var repository = new JsonFolderRepository(layout);
            var folders = new GLib.List<Folder>();
            folders.append(new Folder("parent", "Parent"));
            folders.append(new Folder("child", "Child", "parent"));

            repository.save_folders(folders);

            assert(File.new_for_path(layout.folders_path).query_exists());
            var loaded = repository.list_folders();
            assert(loaded.length() == 2);
            assert(loaded.nth_data(0).id == "parent");
            assert(loaded.nth_data(1).parent_id == "parent");
        } finally {
            cleanup(root);
        }
    }

    private delegate void ThrowingTest() throws GLib.Error;

    private void run_throwing_test(ThrowingTest test) {
        try {
            test();
        } catch (GLib.Error error) {
            critical("Unexpected test error: %s", error.message);
            assert_not_reached();
        }
    }

    private void test_imports_images_with_safe_unique_names() {
        run_throwing_test(imports_images_with_safe_unique_names);
    }

    private void test_rejects_invalid_asset_inputs_and_paths() {
        run_throwing_test(rejects_invalid_asset_inputs_and_paths);
    }

    private void test_prunes_assets_only_after_a_later_session() {
        run_throwing_test(prunes_assets_only_after_a_later_session);
    }

    private void test_deleting_note_removes_its_assets() {
        run_throwing_test(deleting_note_removes_its_assets);
    }

    private void test_monitor_reports_external_note_changes() {
        run_throwing_test(monitor_reports_external_note_changes);
    }

    private void test_folders_round_trip_in_sibling_json_file() {
        run_throwing_test(folders_round_trip_in_sibling_json_file);
    }

    public static int main(string[] args) {
        Test.init(ref args);
        Test.add_func(
            "/json-notebook-repository/imports-images-with-safe-unique-names",
            test_imports_images_with_safe_unique_names
        );
        Test.add_func(
            "/json-notebook-repository/rejects-invalid-asset-inputs-and-paths",
            test_rejects_invalid_asset_inputs_and_paths
        );
        Test.add_func(
            "/json-notebook-repository/prunes-assets-after-later-session",
            test_prunes_assets_only_after_a_later_session
        );
        Test.add_func(
            "/json-notebook-repository/deleting-note-removes-assets",
            test_deleting_note_removes_its_assets
        );
        Test.add_func(
            "/json-note-repository/monitor-reports-external-changes",
            test_monitor_reports_external_note_changes
        );
        Test.add_func(
            "/json-folder-repository/round-trip",
            test_folders_round_trip_in_sibling_json_file
        );
        return Test.run();
    }
}
