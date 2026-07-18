namespace Knotes {

    public enum SidebarDragItemType {
        NOTE,
        FOLDER
    }

    public class SidebarDragItem : GLib.Object {
        private const string NOTE_PREFIX = "note:";
        private const string FOLDER_PREFIX = "folder:";

        public SidebarDragItemType item_type { get; construct; }
        public string id { get; construct; }

        private SidebarDragItem(SidebarDragItemType item_type, string id) {
            Object(item_type: item_type, id: id);
        }

        public static SidebarDragItem note(string id) {
            return new SidebarDragItem(SidebarDragItemType.NOTE, id);
        }

        public static SidebarDragItem folder(string id) {
            return new SidebarDragItem(SidebarDragItemType.FOLDER, id);
        }

        public static SidebarDragItem? parse(string payload) {
            if (payload.has_prefix(NOTE_PREFIX)) {
                return from_payload(SidebarDragItemType.NOTE, payload, NOTE_PREFIX);
            }
            if (payload.has_prefix(FOLDER_PREFIX)) {
                return from_payload(SidebarDragItemType.FOLDER, payload, FOLDER_PREFIX);
            }
            return null;
        }

        public string serialize() {
            var prefix = item_type == SidebarDragItemType.NOTE ? NOTE_PREFIX : FOLDER_PREFIX;
            return prefix + id;
        }

        public bool can_drop(NotebookCatalog catalog, string? destination_folder_id) {
            if (destination_folder_id != null && !catalog.contains_folder(destination_folder_id)) {
                return false;
            }
            if (item_type == SidebarDragItemType.NOTE) {
                var note = catalog.find_note(id);
                return note != null && note.folder_id != (destination_folder_id ?? "");
            }

            var folder = catalog.find_folder(id);
            return folder != null &&
                folder.parent_id != destination_folder_id &&
                catalog.is_valid_folder_destination(id, destination_folder_id);
        }

        private static SidebarDragItem? from_payload(
            SidebarDragItemType item_type,
            string payload,
            string prefix
        ) {
            var id = payload.substring(prefix.length);
            if (id.length == 0 || id != id.strip() || id.contains(":")) {
                return null;
            }
            return new SidebarDragItem(item_type, id);
        }
    }
}
