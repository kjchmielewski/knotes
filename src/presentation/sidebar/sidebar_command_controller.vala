namespace Knotes {

    public class SidebarCommandController : GLib.Object {
        private NotebookCatalog catalog;
        private NoteService note_service;
        private FolderService folder_service;
        private FolderDialogs folder_dialogs;
        private MoveDestinationDialog move_destination_dialog;
        private weak Gtk.Widget? dialog_parent;

        public signal void content_changed();
        public signal void folder_selection_requested(string? folder_id);
        public signal void folder_expansion_requested(string? folder_id);
        public signal void note_moved(string note_id);

        public SidebarCommandController(
            NotebookCatalog catalog,
            NoteService note_service,
            FolderService folder_service
        ) {
            this.catalog = catalog;
            this.note_service = note_service;
            this.folder_service = folder_service;
            folder_dialogs = new FolderDialogs();
            move_destination_dialog = new MoveDestinationDialog(catalog);
            connect_signals();
        }

        public void show_new_folder(Gtk.Widget parent, string? parent_id) {
            dialog_parent = parent;
            folder_dialogs.show_new_folder(parent, parent_id);
        }

        public void show_delete_folder(Gtk.Widget parent, string? folder_id) {
            if (folder_id == null) {
                return;
            }
            var folder = catalog.find_folder(folder_id);
            if (folder == null) {
                folder_selection_requested(null);
                return;
            }
            dialog_parent = parent;
            folder_dialogs.show_delete_folder(parent, folder);
        }

        public void show_rename_folder(Gtk.Widget parent, string? folder_id) {
            if (folder_id == null) {
                return;
            }
            var folder = catalog.find_folder(folder_id);
            if (folder == null) {
                folder_selection_requested(null);
                return;
            }
            dialog_parent = parent;
            folder_dialogs.show_rename_folder(parent, folder);
        }

        public void show_move_dialog(Gtk.Widget parent, SidebarDragItem item) {
            dialog_parent = parent;
            if (item.item_type == SidebarDragItemType.NOTE) {
                var note = catalog.find_note(item.id);
                if (note == null) {
                    folder_dialogs.show_move_error(parent, MoveResult.SOURCE_NOT_FOUND);
                    return;
                }
                move_destination_dialog.show_for_note(parent, note);
                return;
            }

            var folder = catalog.find_folder(item.id);
            if (folder == null) {
                folder_dialogs.show_move_error(parent, MoveResult.SOURCE_NOT_FOUND);
                return;
            }
            move_destination_dialog.show_for_folder(parent, folder);
        }

        public void move_item(
            Gtk.Widget parent,
            SidebarDragItem item,
            string? destination_folder_id
        ) {
            dialog_parent = parent;
            if (item.item_type == SidebarDragItemType.NOTE) {
                move_note(item.id, destination_folder_id);
            } else {
                move_folder(item.id, destination_folder_id);
            }
        }

        private void connect_signals() {
            folder_dialogs.folder_creation_requested.connect(create_folder);
            folder_dialogs.folder_deletion_requested.connect(delete_folder);
            folder_dialogs.folder_rename_requested.connect(rename_folder);
            move_destination_dialog.note_destination_selected.connect((note_id, folder_id) => {
                move_note(note_id, folder_id);
            });
            move_destination_dialog.folder_destination_selected.connect((folder_id, parent_id) => {
                move_folder(folder_id, parent_id);
            });
        }

        private void create_folder(string name, string? parent_id) {
            var folder = folder_service.create_folder(name, parent_id);
            if (folder == null) {
                return;
            }
            content_changed();
            folder_selection_requested(folder.id);
        }

        private void delete_folder(Folder folder) {
            string? parent_id = folder.parent_id != null && catalog.contains_folder(folder.parent_id)
                ? folder.parent_id
                : null;
            if (!folder_service.delete_folder(folder.id)) {
                folder_selection_requested(null);
                return;
            }
            folder_selection_requested(parent_id);
            content_changed();
        }

        private void rename_folder(string folder_id, string new_name) {
            var result = folder_service.rename_folder(folder_id, new_name);
            if (result == RenameFolderResult.UNCHANGED) {
                return;
            }
            if (result != RenameFolderResult.RENAMED) {
                if (dialog_parent != null) {
                    folder_dialogs.show_rename_error(dialog_parent, result);
                }
                return;
            }
            content_changed();
        }

        private void move_note(string note_id, string? destination_folder_id) {
            var result = note_service.move_note(note_id, destination_folder_id);
            if (result == MoveResult.UNCHANGED) {
                return;
            }
            if (result != MoveResult.MOVED) {
                show_move_error(result);
                return;
            }
            note_moved(note_id);
            folder_expansion_requested(destination_folder_id);
            content_changed();
        }

        private void move_folder(string folder_id, string? destination_parent_id) {
            var result = folder_service.move_folder(folder_id, destination_parent_id);
            if (result == MoveResult.UNCHANGED) {
                return;
            }
            if (result != MoveResult.MOVED) {
                show_move_error(result);
                return;
            }
            folder_expansion_requested(destination_parent_id);
            content_changed();
        }

        private void show_move_error(MoveResult result) {
            if (dialog_parent != null) {
                folder_dialogs.show_move_error(dialog_parent, result);
            }
        }
    }
}
