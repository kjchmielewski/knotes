namespace Knotes {

    public class ApplicationServices : GLib.Object {
        public NotebookWorkspace workspace { get; construct; }
        public NoteService notes { get; construct; }
        public FolderService folders { get; construct; }
        public NoteAssetService assets { get; construct; }
        public NoteEditingSession note_editing_session { get; construct; }

        public ApplicationServices(
            NotebookWorkspace workspace,
            NoteService notes,
            FolderService folders,
            NoteAssetService assets,
            NoteEditingSession note_editing_session
        ) {
            Object(
                workspace: workspace,
                notes: notes,
                folders: folders,
                assets: assets,
                note_editing_session: note_editing_session
            );
        }
    }
}
