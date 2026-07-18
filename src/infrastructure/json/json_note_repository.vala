namespace Knotes {

    public class JsonNoteRepository : GLib.Object, NoteRepository {
        private const uint OWN_CHANGE_IGNORE_TIMEOUT_MS = 1000;

        private JsonStorageLayout layout;
        private JsonNoteAssetStorage asset_storage;
        private GLib.FileMonitor? monitor;
        private Gee.HashSet<string> own_updated_note_ids = new Gee.HashSet<string>();
        private Gee.HashSet<string> own_deleted_note_ids = new Gee.HashSet<string>();

        public JsonNoteRepository(JsonStorageLayout layout, JsonNoteAssetStorage asset_storage) {
            this.layout = layout;
            this.asset_storage = asset_storage;
            setup_monitor();
        }

        public GLib.List<Note> list_notes() {
            var notes = new GLib.List<Note>();
            try {
                var enumerator = layout.notes_directory_file.enumerate_children(
                    FileAttribute.STANDARD_NAME,
                    FileQueryInfoFlags.NONE
                );
                FileInfo info;
                while ((info = enumerator.next_file()) != null) {
                    var filename = info.get_name();
                    if (!filename.has_suffix(".json")) {
                        continue;
                    }
                    var note = load_note(filename.substring(0, filename.length - 5));
                    if (note != null) {
                        notes.append(note);
                    }
                }
            } catch (GLib.Error error) {
                warning("Failed to list notes: %s", error.message);
            }
            return notes;
        }

        public Note? load_note(string id) {
            var path = layout.note_path(id);
            var file = GLib.File.new_for_path(path);
            try {
                if (!file.query_exists()) {
                    return null;
                }
                var parser = new Json.Parser();
                parser.load_from_file(path);
                return NoteJsonMapper.from_json(parser.get_root().get_object());
            } catch (GLib.Error error) {
                warning("Failed to load note '%s': %s", id, error.message);
                return null;
            }
        }

        public void save_note(Note note) throws GLib.Error {
            var root = new Json.Node(Json.NodeType.OBJECT);
            root.set_object(NoteJsonMapper.to_json(note));
            var generator = new Json.Generator();
            generator.set_root(root);
            generator.pretty = true;
            mark_own_change(own_updated_note_ids, note.id);
            generator.to_file(layout.note_path(note.id));
            asset_storage.stage_orphaned_assets(note);
        }

        public void delete_note(string id) throws GLib.Error {
            var file = GLib.File.new_for_path(layout.note_path(id));
            if (file.query_exists()) {
                mark_own_change(own_deleted_note_ids, id);
                file.delete();
            }
            asset_storage.remove_assets(id);
        }

        private void setup_monitor() {
            try {
                monitor = layout.notes_directory_file.monitor_directory(FileMonitorFlags.NONE);
                monitor.changed.connect(on_directory_changed);
            } catch (GLib.Error error) {
                warning("Failed to monitor notes directory: %s", error.message);
            }
        }

        private void mark_own_change(Gee.HashSet<string> note_ids, string id) {
            note_ids.add(id);
            Timeout.add(OWN_CHANGE_IGNORE_TIMEOUT_MS, () => {
                note_ids.remove(id);
                return false;
            });
        }

        private void on_directory_changed(
            GLib.File file,
            GLib.File? other_file,
            GLib.FileMonitorEvent event_type
        ) {
            var filename = file.get_basename();
            if (filename == null || !filename.has_suffix(".json")) {
                return;
            }

            var id = filename.substring(0, filename.length - 5);
            switch (event_type) {
                case FileMonitorEvent.CREATED:
                case FileMonitorEvent.CHANGED:
                    if (!own_updated_note_ids.contains(id)) {
                        note_updated(id);
                    }
                    break;
                case FileMonitorEvent.DELETED:
                    if (!own_deleted_note_ids.contains(id)) {
                        note_deleted(id);
                    }
                    break;
                default:
                    break;
            }
        }
    }
}
