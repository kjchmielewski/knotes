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
            return new ApplicationServices(
                workspace,
                new NoteService(note_repository, asset_repository, workspace),
                new FolderService(folder_repository, note_repository, workspace),
                new NoteAssetService(asset_repository, workspace)
            );
        }
    }
}
