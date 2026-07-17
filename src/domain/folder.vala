namespace Knotes {

    public class Folder : GLib.Object {
        public string id { get; construct set; }
        public string name { get; set; default = ""; }
        public string? parent_id { get; set; default = null; }

        public Folder(string id, string name, string? parent_id = null) {
            GLib.Object(id: id, name: name, parent_id: parent_id);
        }
    }
}
