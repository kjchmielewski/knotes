namespace Knotes {

    public class ApplicationFactory {
        private ApplicationFactory() {
        }

        public static ApplicationServices create_services() {
            var layout = new JsonStorageLayout();
            var asset_storage = new JsonNoteAssetStorage(layout);
            NoteRepository note_repository = new JsonNoteRepository(layout, asset_storage);
            FolderRepository folder_repository = new JsonFolderRepository(layout);
            NoteAssetRepository asset_repository = new JsonNoteAssetRepository(asset_storage);
            var workspace = new NotebookWorkspace(note_repository, folder_repository);
            var note_service = new NoteService(note_repository, asset_repository, workspace);
            return new ApplicationServices(
                workspace,
                note_service,
                new FolderService(folder_repository, note_repository, workspace),
                new NoteAssetService(asset_repository, workspace),
                new NoteEditingSession(note_service, new DefaultAutosaveFactory())
            );
        }
    }
}
