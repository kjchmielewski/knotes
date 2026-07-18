namespace Knotes {

    public enum DuplicateNoteStatus {
        DUPLICATED,
        SOURCE_NOT_FOUND,
        STORAGE_ERROR
    }

    public class DuplicateNoteResult : GLib.Object {
        public DuplicateNoteStatus status { get; construct; }
        public Note? note { get; construct; }

        public DuplicateNoteResult(DuplicateNoteStatus status, Note? note = null) {
            Object(status: status, note: note);
        }

        public static DuplicateNoteResult duplicated(Note note) {
            return new DuplicateNoteResult(DuplicateNoteStatus.DUPLICATED, note);
        }
    }
}
