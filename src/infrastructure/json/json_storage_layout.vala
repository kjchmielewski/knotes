namespace Knotes {

    public class JsonStorageLayout : GLib.Object {
        private const string ASSETS_DIRECTORY_NAME = "assets";
        private const string ORPHANED_ASSETS_FILENAME = ".orphaned-assets.json";

        public string notes_directory { get; private set; }
        public string folders_path { get; private set; }
        public GLib.File notes_directory_file { get; private set; }

        public JsonStorageLayout(string? custom_notes_directory = null) {
            notes_directory = custom_notes_directory ?? Path.build_path(
                "/",
                Environment.get_user_data_dir(),
                "knotes",
                "notes"
            );
            folders_path = Path.build_filename(Path.get_dirname(notes_directory), "folders.json");
            notes_directory_file = GLib.File.new_for_path(notes_directory);
            ensure_notes_directory();
        }

        public string note_path(string note_id) {
            return Path.build_filename(notes_directory, note_id + ".json");
        }

        public string note_asset_root_path(string note_id) {
            return Path.build_filename(notes_directory, note_id);
        }

        public string assets_directory_path(string note_id) {
            return Path.build_filename(note_asset_root_path(note_id), ASSETS_DIRECTORY_NAME);
        }

        public string orphaned_assets_path(string note_id) {
            return Path.build_filename(note_asset_root_path(note_id), ORPHANED_ASSETS_FILENAME);
        }

        private void ensure_notes_directory() {
            try {
                if (!notes_directory_file.query_exists()) {
                    notes_directory_file.make_directory_with_parents();
                }
            } catch (GLib.Error error) {
                warning("Failed to create notes directory: %s", error.message);
            }
        }
    }
}
