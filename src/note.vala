namespace Knotes {

    public class Note : GLib.Object {
        public string id { get; construct set; }
        public string title { get; set; default = ""; }
        public string content { get; set; default = ""; }
        // An empty folder ID represents the top-level, unfiled notes.
        public string folder_id { get; set; default = ""; }
        public DateTime created_at { get; construct set; }
        public DateTime updated_at { get; set; }

        public Note(string id, string title, string content, DateTime created_at, DateTime updated_at,
                    string folder_id = "") {
            GLib.Object(
                id: id,
                title: title,
                content: content,
                folder_id: folder_id,
                created_at: created_at,
                updated_at: updated_at
            );
        }

        public Note.with_new_content(string title, string content, string folder_id = "") {
            var now = new DateTime.now_utc();
            GLib.Object(
                id: Uuid.string_random(),
                title: title,
                content: content,
                folder_id: folder_id,
                created_at: now,
                updated_at: now
            );
        }

        public string preview(int max_length = 80) {
            var stripped = content.replace("\n", " ");
            if (stripped.length <= max_length) {
                return stripped;
            }
            return stripped.substring(0, max_length) + "…";
        }

        public Json.Object to_json() {
            var obj = new Json.Object();
            obj.set_string_member("id", id);
            obj.set_string_member("title", title);
            obj.set_string_member("content", content);
            obj.set_string_member("folder_id", folder_id);
            obj.set_string_member("created_at", created_at.format_iso8601());
            obj.set_string_member("updated_at", updated_at.format_iso8601());
            return obj;
        }

        public static Note? from_json(Json.Object obj) {
            var id = obj.get_string_member("id");
            var title = obj.get_string_member("title");
            var content = obj.get_string_member("content");
            var folder_id = obj.has_member("folder_id") ? obj.get_string_member("folder_id") : "";
            var created_at = new DateTime.from_iso8601(obj.get_string_member("created_at"), null);
            var updated_at = new DateTime.from_iso8601(obj.get_string_member("updated_at"), null);

            if (id == null || title == null || content == null ||
                created_at == null || updated_at == null) {
                return null;
            }

            return new Note(id, title, content, created_at, updated_at, folder_id);
        }
    }
}
