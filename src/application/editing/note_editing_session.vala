namespace Knotes {

    public class NoteEditingSession : GLib.Object {
        private NoteService note_service;
        private AutosaveScheduler autosave;

        public string? current_note_id { get; private set; default = null; }
        public string title { get; private set; default = ""; }
        public string content { get; private set; default = ""; }

        public bool has_selected_note {
            get { return current_note_id != null; }
        }

        public signal void note_changed(Note note);
        public signal void note_duplicated(Note note);
        public signal void note_deleted();

        public NoteEditingSession(NoteService note_service, AutosaveFactory autosave_factory) {
            this.note_service = note_service;
            autosave = autosave_factory.create(save_current_note);
        }

        public Note? select_note(string? id) {
            if (current_note_id != id) {
                autosave.flush();
            }
            if (id == null) {
                clear_selection();
                return null;
            }

            var note = note_service.find_note(id);
            if (note == null) {
                clear_selection();
                return null;
            }

            current_note_id = note.id;
            title = note.title;
            content = note.content;
            return note;
        }

        public void update_draft(string new_title, string new_content) {
            if (current_note_id == null) {
                return;
            }
            title = new_title;
            content = new_content;
            autosave.schedule();
        }

        public DuplicateNoteResult duplicate_current_note(string duplicate_title) {
            autosave.flush();
            if (current_note_id == null) {
                return new DuplicateNoteResult(DuplicateNoteStatus.SOURCE_NOT_FOUND);
            }

            var result = note_service.duplicate_note(current_note_id, duplicate_title);
            if (result.status == DuplicateNoteStatus.DUPLICATED && result.note != null) {
                note_duplicated(result.note);
            }
            return result;
        }

        public bool delete_current_note() {
            if (current_note_id == null || !note_service.delete_note(current_note_id)) {
                return false;
            }

            autosave.cancel();
            clear_selection();
            note_deleted();
            return true;
        }

        private void save_current_note() {
            if (current_note_id == null) {
                return;
            }
            var note = note_service.find_note(current_note_id);
            if (note == null || (note.title == title && note.content == content)) {
                return;
            }

            note.title = title;
            note.content = content;
            note.updated_at = new DateTime.now_utc();
            if (note_service.save_note(note)) {
                note_changed(note);
            }
        }

        private void clear_selection() {
            current_note_id = null;
            title = "";
            content = "";
        }
    }
}
