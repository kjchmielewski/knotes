namespace Knotes {

    public class JsonNoteAssetRepository : GLib.Object, NoteAssetRepository {
        private JsonNoteAssetStorage storage;

        public JsonNoteAssetRepository(JsonNoteAssetStorage storage) {
            this.storage = storage;
        }

        public string import_image_file(string note_id, GLib.File source_file) throws GLib.Error {
            return storage.import_image_file(note_id, source_file);
        }

        public string import_image_bytes(
            string note_id,
            string suggested_filename,
            GLib.Bytes bytes
        ) throws GLib.Error {
            return storage.import_image_bytes(note_id, suggested_filename, bytes);
        }

        public AssetContent? load_asset(string note_id, string relative_path) throws GLib.Error {
            return storage.load_asset(note_id, relative_path);
        }

        public void copy_referenced_assets(
            string source_note_id,
            string destination_note_id,
            string content
        ) throws GLib.Error {
            storage.copy_referenced_assets(source_note_id, destination_note_id, content);
        }
    }
}
