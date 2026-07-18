namespace Knotes {

    public class FolderDialogs : GLib.Object {
        public signal void folder_creation_requested(string name, string? parent_id);
        public signal void folder_deletion_requested(Folder folder);

        public void show_new_folder(Gtk.Widget parent, string? parent_id) {
            var dialog = new Adw.AlertDialog(
                _("New folder"),
                _("Enter a name for the new folder.")
            );
            dialog.add_response("cancel", _("Cancel"));
            dialog.add_response("create", _("Create"));
            dialog.close_response = "cancel";
            dialog.default_response = "create";

            var entry = new Gtk.Entry();
            entry.placeholder_text = _("Folder name");
            dialog.set_extra_child(entry);
            dialog.choose.begin(parent, null, (object, result) => {
                if (dialog.choose.end(result) != "create") {
                    return;
                }

                var name = entry.text.strip();
                if (name.length > 0) {
                    folder_creation_requested(name, parent_id);
                }
            });
        }

        public void show_delete_folder(Gtk.Widget parent, Folder folder) {
            var dialog = new Adw.AlertDialog(
                _("Delete folder?"),
                _("Notes and subfolders will be moved to the parent folder.")
            );
            dialog.add_response("cancel", _("Cancel"));
            dialog.add_response("delete", _("Delete"));
            dialog.close_response = "cancel";
            dialog.default_response = "cancel";
            dialog.set_response_appearance("delete", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.choose.begin(parent, null, (object, result) => {
                if (dialog.choose.end(result) == "delete") {
                    folder_deletion_requested(folder);
                }
            });
        }

        public void show_move_error(Gtk.Widget parent, MoveResult result) {
            string message;
            switch (result) {
                case MoveResult.SOURCE_NOT_FOUND:
                    message = _("The item no longer exists.");
                    break;
                case MoveResult.DESTINATION_NOT_FOUND:
                    message = _("The destination folder no longer exists.");
                    break;
                case MoveResult.CYCLE_DETECTED:
                    message = _("A folder cannot be moved into itself or one of its subfolders.");
                    break;
                case MoveResult.STORAGE_ERROR:
                    message = _("The change could not be saved. Your notes were left unchanged.");
                    break;
                default:
                    message = _("The item could not be moved.");
                    break;
            }

            var dialog = new Adw.AlertDialog(_("Unable to move item"), message);
            dialog.add_response("close", _("Close"));
            dialog.close_response = "close";
            dialog.present(parent);
        }
    }
}
