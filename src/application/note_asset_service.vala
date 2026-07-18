namespace Knotes {

    public class NoteAssetService : GLib.Object {
        private NoteAssetRepository repository;
        private NotebookWorkspace workspace;

        public NoteAssetService(NoteAssetRepository repository, NotebookWorkspace workspace) {
            this.repository = repository;
            this.workspace = workspace;
        }

        public AssetImportResult import_image_file(string note_id, GLib.File source_file) {
            if (workspace.find_note(note_id) == null) {
                return new AssetImportResult(AssetImportStatus.NOTE_NOT_FOUND);
            }

            try {
                return AssetImportResult.imported(repository.import_image_file(note_id, source_file));
            } catch (GLib.Error error) {
                return import_failure(note_id, error);
            }
        }

        public AssetImportResult import_png_bytes(string note_id, GLib.Bytes bytes) {
            if (workspace.find_note(note_id) == null) {
                return new AssetImportResult(AssetImportStatus.NOTE_NOT_FOUND);
            }

            try {
                return AssetImportResult.imported(
                    repository.import_image_bytes(note_id, "pasted.png", bytes)
                );
            } catch (GLib.Error error) {
                return import_failure(note_id, error);
            }
        }

        public AssetContent? load_asset(string note_id, string relative_path) {
            if (workspace.find_note(note_id) == null) {
                return null;
            }

            try {
                return repository.load_asset(note_id, relative_path);
            } catch (GLib.Error error) {
                warning(
                    "Failed to load asset '%s' for note '%s': %s",
                    relative_path,
                    note_id,
                    error.message
                );
                return null;
            }
        }

        private AssetImportResult import_failure(string note_id, GLib.Error error) {
            if (error is AssetStorageError.UNSUPPORTED_TYPE) {
                return new AssetImportResult(AssetImportStatus.UNSUPPORTED_TYPE);
            }
            if (error is AssetStorageError.INVALID_SOURCE) {
                return new AssetImportResult(AssetImportStatus.INVALID_SOURCE);
            }
            if (error is AssetStorageError.NOT_FOUND) {
                return new AssetImportResult(AssetImportStatus.NOTE_NOT_FOUND);
            }

            warning("Failed to import image for note '%s': %s", note_id, error.message);
            return new AssetImportResult(AssetImportStatus.STORAGE_ERROR);
        }
    }
}
