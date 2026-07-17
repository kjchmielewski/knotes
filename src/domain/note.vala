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
    }
}
