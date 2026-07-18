namespace Knotes {

    public class JsonNotebookRepository : NotebookRepository {
        private const uint OWN_CHANGE_IGNORE_TIMEOUT_MS = 1000;

        private string notes_dir;
        private string folders_path;
        private FileMonitor monitor;
        private File notes_dir_file;
        private Gee.HashSet<string> own_updated_note_ids;
        private Gee.HashSet<string> own_deleted_note_ids;

        public JsonNotebookRepository() {
            notes_dir = Path.build_path(
                "/",
                Environment.get_user_data_dir(),
                "knotes",
                "notes"
            );
            notes_dir_file = File.new_for_path(notes_dir);
            folders_path = Path.build_filename(Path.get_dirname(notes_dir), "folders.json");
            own_updated_note_ids = new Gee.HashSet<string>();
            own_deleted_note_ids = new Gee.HashSet<string>();
            ensure_directory();
            setup_monitor();
        }

        public override List<Folder> list_folders() {
            var folders = new List<Folder>();
            var file = File.new_for_path(folders_path);
            if (!file.query_exists()) {
                return folders;
            }

            try {
                var parser = new Json.Parser();
                parser.load_from_file(folders_path);
                var array = parser.get_root().get_array();
                foreach (var element in array.get_elements()) {
                    var folder = FolderJsonMapper.from_json(element.get_object());
                    if (folder != null) {
                        folders.append(folder);
                    }
                }
            } catch (GLib.Error e) {
                warning("Failed to load folders: %s", e.message);
            }
            return folders;
        }

        public override void save_folders(List<Folder> folders) throws GLib.Error {
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
            generator.to_file(folders_path);
        }

        private void ensure_directory() {
            try {
                if (!notes_dir_file.query_exists()) {
                    notes_dir_file.make_directory_with_parents();
                }
            } catch (GLib.Error e) {
                warning("Failed to create notes directory: %s", e.message);
            }
        }

        private void setup_monitor() {
            try {
                monitor = notes_dir_file.monitor_directory(FileMonitorFlags.NONE);
                monitor.changed.connect(on_directory_changed);
            } catch (GLib.Error e) {
                warning("Failed to monitor notes directory: %s", e.message);
            }
        }

        private string file_path_for_id(string id) {
            return Path.build_filename(notes_dir, id + ".json");
        }

        public override List<Note> list_notes() {
            var notes = new List<Note>();
            try {
                var enumerator = notes_dir_file.enumerate_children(
                    FileAttribute.STANDARD_NAME,
                    FileQueryInfoFlags.NONE
                );
                FileInfo info;
                while ((info = enumerator.next_file()) != null) {
                    var name = info.get_name();
                    if (!name.has_suffix(".json")) continue;
                    var id = name.substring(0, name.length - 5);
                    var note = load_note(id);
                    if (note != null) {
                        notes.append(note);
                    }
                }
            } catch (GLib.Error e) {
                warning("Failed to list notes: %s", e.message);
            }
            return notes;
        }

        public override Note? load_note(string id) {
            var path = file_path_for_id(id);
            var file = File.new_for_path(path);
            try {
                if (!file.query_exists()) return null;
                var parser = new Json.Parser();
                parser.load_from_file(path);
                var obj = parser.get_root().get_object();
                return NoteJsonMapper.from_json(obj);
            } catch (GLib.Error e) {
                warning("Failed to load note '%s': %s", id, e.message);
                return null;
            }
        }

        public override void save_note(Note note) throws GLib.Error {
            var generator = new Json.Generator();
            var root = new Json.Node(Json.NodeType.OBJECT);
            root.set_object(NoteJsonMapper.to_json(note));
            generator.set_root(root);
            generator.pretty = true;
            mark_own_update(note.id);
            generator.to_file(file_path_for_id(note.id));
        }

        public override void delete_note(string id) throws GLib.Error {
            var file = File.new_for_path(file_path_for_id(id));
            if (file.query_exists()) {
                mark_own_delete(id);
                file.delete();
            }
        }

        private void mark_own_update(string id) {
            mark_own_change(own_updated_note_ids, id);
        }

        private void mark_own_delete(string id) {
            mark_own_change(own_deleted_note_ids, id);
        }

        private void mark_own_change(Gee.HashSet<string> note_ids, string id) {
            note_ids.add(id);
            Timeout.add(OWN_CHANGE_IGNORE_TIMEOUT_MS, () => {
                note_ids.remove(id);
                return false;
            });
        }

        private bool is_own_update(string id) {
            return own_updated_note_ids.contains(id);
        }

        private bool is_own_delete(string id) {
            return own_deleted_note_ids.contains(id);
        }

        private void on_directory_changed(File file, File? other_file, FileMonitorEvent event_type) {
            string? name = file.get_basename();
            if (name == null || !name.has_suffix(".json")) return;

            var id = name.substring(0, name.length - 5);
            switch (event_type) {
                case FileMonitorEvent.CREATED:
                case FileMonitorEvent.CHANGED:
                    if (!is_own_update(id)) {
                        note_updated(id);
                    }
                    break;
                case FileMonitorEvent.DELETED:
                    if (!is_own_delete(id)) {
                        note_deleted(id);
                    }
                    break;
                default:
                    break;
            }
        }
    }
}
