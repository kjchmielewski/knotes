namespace Knotes {

    public class Folder : GLib.Object {
        public string id { get; construct set; }
        public string name { get; set; default = ""; }
        public string? parent_id { get; set; default = null; }

        public Folder(string id, string name, string? parent_id = null) {
            GLib.Object(id: id, name: name, parent_id: parent_id);
        }

        public Json.Object to_json() {
            var obj = new Json.Object();
            obj.set_string_member("id", id);
            obj.set_string_member("name", name);
            if (parent_id != null) {
                obj.set_string_member("parent_id", parent_id);
            }
            return obj;
        }

        public static Folder? from_json(Json.Object obj) {
            if (!obj.has_member("id") || !obj.has_member("name")) {
                return null;
            }

            var id = obj.get_string_member("id");
            var name = obj.get_string_member("name");
            string? parent_id = null;
            if (obj.has_member("parent_id") && !obj.get_null_member("parent_id")) {
                parent_id = obj.get_string_member("parent_id");
            }

            if (id == null || name == null || name.strip().length == 0) {
                return null;
            }
            return new Folder(id, name, parent_id);
        }
    }
}
