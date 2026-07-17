namespace Knotes {

    public class ApplicationFactory {
        private ApplicationFactory() {
        }

        public static NotebookService create_notebook_service() {
            NotebookRepository repository = new JsonNotebookRepository();
            return new NotebookService(repository);
        }
    }
}
