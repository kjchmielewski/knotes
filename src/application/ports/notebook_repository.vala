namespace Knotes {

    public abstract class NotebookRepository : GLib.Object {
        public signal void note_updated(string id);
        public signal void note_deleted(string id);

        public abstract GLib.List<Note> list_notes();
        public abstract Note? load_note(string id);
        public abstract void save_note(Note note) throws GLib.Error;
        public abstract void delete_note(string id) throws GLib.Error;
        public abstract GLib.List<Folder> list_folders();
        public abstract void save_folders(GLib.List<Folder> folders) throws GLib.Error;
    }
}
