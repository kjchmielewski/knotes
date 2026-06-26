namespace Knotes {

    public class NoteRepository : GLib.Object {
        private const uint OWN_CHANGE_IGNORE_TIMEOUT_MS = 1000;

        private string notes_dir;
        private FileMonitor monitor;
        private File notes_dir_file;
        private Gee.HashSet<string> own_updated_note_ids;
        private Gee.HashSet<string> own_deleted_note_ids;

        public signal void note_created(string id);
        public signal void note_updated(string id);
        public signal void note_deleted(string id);

        public NoteRepository() {
            notes_dir = Path.build_path(
                "/",
                Environment.get_user_data_dir(),
                "knotes",
                "notes"
            );
            notes_dir_file = File.new_for_path(notes_dir);
            own_updated_note_ids = new Gee.HashSet<string>();
            own_deleted_note_ids = new Gee.HashSet<string>();
            ensure_directory();
            setup_monitor();
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

        public List<Note> list_all() {
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

        public Note? load_note(string id) {
            var path = file_path_for_id(id);
            var file = File.new_for_path(path);
            try {
                if (!file.query_exists()) return null;
                var parser = new Json.Parser();
                parser.load_from_file(path);
                var obj = parser.get_root().get_object();
                return Note.from_json(obj);
            } catch (GLib.Error e) {
                warning("Failed to load note '%s': %s", id, e.message);
                return null;
            }
        }

        public void save_note(Note note) {
            var generator = new Json.Generator();
            var root = new Json.Node(Json.NodeType.OBJECT);
            root.set_object(note.to_json());
            generator.set_root(root);
            generator.pretty = true;
            try {
                mark_own_update(note.id);
                generator.to_file(file_path_for_id(note.id));
            } catch (GLib.Error e) {
                warning("Failed to save note '%s': %s", note.id, e.message);
            }
        }

        public void delete_note(string id) {
            var file = File.new_for_path(file_path_for_id(id));
            try {
                if (file.query_exists()) {
                    mark_own_delete(id);
                    file.delete();
                }
            } catch (GLib.Error e) {
                warning("Failed to delete note '%s': %s", id, e.message);
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
