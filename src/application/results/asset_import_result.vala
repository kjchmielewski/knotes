namespace Knotes {

    public enum AssetImportStatus {
        IMPORTED,
        NOTE_NOT_FOUND,
        UNSUPPORTED_TYPE,
        INVALID_SOURCE,
        STORAGE_ERROR
    }

    public class AssetImportResult : GLib.Object {
        public AssetImportStatus status { get; construct; }
        public string? relative_path { get; construct; }

        public AssetImportResult(AssetImportStatus status, string? relative_path = null) {
            GLib.Object(status: status, relative_path: relative_path);
        }

        public static AssetImportResult imported(string relative_path) {
            return new AssetImportResult(AssetImportStatus.IMPORTED, relative_path);
        }
    }

    public class AssetContent : GLib.Object {
        public GLib.Bytes bytes { get; construct; }
        public string content_type { get; construct; }

        public AssetContent(GLib.Bytes bytes, string content_type) {
            GLib.Object(bytes: bytes, content_type: content_type);
        }
    }

    public errordomain AssetStorageError {
        UNSUPPORTED_TYPE,
        INVALID_SOURCE,
        NOT_FOUND
    }
}
