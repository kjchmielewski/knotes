namespace Knotes {

    public class JsonFolderRepository : GLib.Object, FolderRepository {
        private JsonStorageLayout layout;

        public JsonFolderRepository(JsonStorageLayout layout) {
            this.layout = layout;
        }

        public GLib.List<Folder> list_folders() {
            var folders = new GLib.List<Folder>();
            var file = GLib.File.new_for_path(layout.folders_path);
            if (!file.query_exists()) {
                return folders;
            }

            try {
                var parser = new Json.Parser();
                parser.load_from_file(layout.folders_path);
                foreach (var element in parser.get_root().get_array().get_elements()) {
                    var folder = FolderJsonMapper.from_json(element.get_object());
                    if (folder != null) {
                        folders.append(folder);
                    }
                }
            } catch (GLib.Error error) {
                warning("Failed to load folders: %s", error.message);
            }
            return folders;
        }

        public void save_folders(GLib.List<Folder> folders) throws GLib.Error {
            var array = new Json.Array();
            foreach (var folder in folders) {
                var node = new Json.Node(Json.NodeType.OBJECT);
                node.set_object(FolderJsonMapper.to_json(folder));
                array.add_element(node);
            }

            var root = new Json.Node(Json.NodeType.ARRAY);
            root.set_array(array);
            var generator = new Json.Generator();
            generator.set_root(root);
            generator.pretty = true;
            generator.to_file(layout.folders_path);
        }
    }
}
