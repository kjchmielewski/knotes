namespace Knotes {

    public class SidebarSelectionModel : GLib.Object {
        private NotebookCatalog catalog;

        public string? selected_note_id { get; private set; default = null; }
        public string? selected_folder_id { get; private set; default = null; }

        public signal void note_selection_changed(string? note_id);
        public signal void folder_selection_changed(string? folder_id);

        public SidebarSelectionModel(NotebookCatalog catalog) {
            this.catalog = catalog;
        }

        public void select_note(string? note_id) {
            var note = note_id != null ? catalog.find_note(note_id) : null;
            if (note_id != null && note == null) {
                set_note_id(null);
                return;
            }
            if (note != null) {
                set_folder_id(catalog.normalized_folder_id(note));
            }
            set_note_id(note_id);
        }

        public void select_folder(string? folder_id) {
            var normalized_folder_id = folder_id != null && catalog.contains_folder(folder_id)
                ? folder_id
                : null;
            set_folder_id(normalized_folder_id);

            if (selected_note_id == null) {
                return;
            }
            var note = catalog.find_note(selected_note_id);
            if (note == null || catalog.normalized_folder_id(note) != normalized_folder_id) {
                set_note_id(null);
            }
        }

        public void reconcile_note(string note_id) {
            if (selected_note_id != note_id) {
                return;
            }
            var note = catalog.find_note(note_id);
            if (note == null) {
                set_note_id(null);
                return;
            }
            set_folder_id(catalog.normalized_folder_id(note));
        }

        public void remove_note(string note_id) {
            if (selected_note_id == note_id) {
                set_note_id(null);
            }
        }

        public void clear() {
            set_folder_id(null);
            set_note_id(null);
        }

        private void set_note_id(string? note_id) {
            if (selected_note_id == note_id) {
                return;
            }
            selected_note_id = note_id;
            note_selection_changed(note_id);
        }

        private void set_folder_id(string? folder_id) {
            if (selected_folder_id == folder_id) {
                return;
            }
            selected_folder_id = folder_id;
            folder_selection_changed(folder_id);
        }
    }
}
