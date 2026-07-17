namespace Knotes {

    public class FolderJsonMapper {
        private FolderJsonMapper() {
        }

        public static Json.Object to_json(Folder folder) {
            var object = new Json.Object();
            object.set_string_member("id", folder.id);
            object.set_string_member("name", folder.name);
            if (folder.parent_id != null) {
                object.set_string_member("parent_id", folder.parent_id);
            }
            return object;
        }

        public static Folder? from_json(Json.Object object) {
            if (!object.has_member("id") || !object.has_member("name")) {
                return null;
            }

            var id = object.get_string_member("id");
            var name = object.get_string_member("name");
            string? parent_id = null;
            if (object.has_member("parent_id") && !object.get_null_member("parent_id")) {
                parent_id = object.get_string_member("parent_id");
            }

            if (id == null || name == null || name.strip().length == 0) {
                return null;
            }
            return new Folder(id, name, parent_id);
        }
    }
}
