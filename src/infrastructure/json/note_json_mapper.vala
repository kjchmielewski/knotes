namespace Knotes {

    public class NoteJsonMapper {
        private NoteJsonMapper() {
        }

        public static Json.Object to_json(Note note) {
            var object = new Json.Object();
            object.set_string_member("id", note.id);
            object.set_string_member("title", note.title);
            object.set_string_member("content", note.content);
            object.set_string_member("folder_id", note.folder_id);
            object.set_string_member("created_at", note.created_at.format_iso8601());
            object.set_string_member("updated_at", note.updated_at.format_iso8601());
            return object;
        }

        public static Note? from_json(Json.Object object) {
            var id = object.get_string_member("id");
            var title = object.get_string_member("title");
            var content = object.get_string_member("content");
            var folder_id = object.has_member("folder_id")
                ? object.get_string_member("folder_id")
                : "";
            var created_at = new DateTime.from_iso8601(
                object.get_string_member("created_at"),
                null
            );
            var updated_at = new DateTime.from_iso8601(
                object.get_string_member("updated_at"),
                null
            );

            if (id == null || title == null || content == null ||
                created_at == null || updated_at == null) {
                return null;
            }

            return new Note(id, title, content, created_at, updated_at, folder_id);
        }
    }
}
