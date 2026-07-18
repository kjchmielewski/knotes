namespace Knotes {

    public interface NoteRepository : GLib.Object {
        public signal void note_updated(string id);
        public signal void note_deleted(string id);

        public abstract GLib.List<Note> list_notes();
        public abstract Note? load_note(string id);
        public abstract void save_note(Note note) throws GLib.Error;
        public abstract void delete_note(string id) throws GLib.Error;
    }
}
