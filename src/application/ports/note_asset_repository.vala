namespace Knotes {

    public interface NoteAssetRepository : GLib.Object {
        public abstract string import_image_file(
            string note_id,
            GLib.File source_file
        ) throws GLib.Error;
        public abstract string import_image_bytes(
            string note_id,
            string suggested_filename,
            GLib.Bytes bytes
        ) throws GLib.Error;
        public abstract AssetContent? load_asset(
            string note_id,
            string relative_path
        ) throws GLib.Error;
    }
}
