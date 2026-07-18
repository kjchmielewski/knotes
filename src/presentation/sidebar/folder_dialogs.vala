namespace Knotes {

    public class FolderDialogs : GLib.Object {
        public signal void folder_creation_requested(string name, string? parent_id);
        public signal void folder_deletion_requested(Folder folder);
        public signal void folder_rename_requested(string folder_id, string new_name);

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

        public void show_rename_folder(Gtk.Widget parent, Folder folder) {
            var dialog = new Adw.AlertDialog(
                _("Rename folder"),
                _("Enter a new name for the folder.")
            );
            dialog.add_response("cancel", _("Cancel"));
            dialog.add_response("rename", _("Rename"));
            dialog.close_response = "cancel";
            dialog.default_response = "rename";

            var entry = new Gtk.Entry();
            entry.text = folder.name;
            entry.activates_default = true;
            entry.changed.connect(() => {
                dialog.set_response_enabled("rename", entry.text.strip().length > 0);
            });
            dialog.set_extra_child(entry);
            dialog.choose.begin(parent, null, (object, result) => {
                if (dialog.choose.end(result) != "rename") {
                    return;
                }
                folder_rename_requested(folder.id, entry.text);
            });
            entry.grab_focus();
            entry.select_region(0, -1);
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

        public void show_rename_error(Gtk.Widget parent, RenameFolderResult result) {
            string message;
            switch (result) {
                case RenameFolderResult.INVALID_NAME:
                    message = _("Folder name cannot be empty.");
                    break;
                case RenameFolderResult.SOURCE_NOT_FOUND:
                    message = _("The folder no longer exists.");
                    break;
                case RenameFolderResult.STORAGE_ERROR:
                    message = _("The new name could not be saved. The previous name was restored.");
                    break;
                default:
                    message = _("The folder could not be renamed.");
                    break;
            }

            var dialog = new Adw.AlertDialog(_("Unable to rename folder"), message);
            dialog.add_response("close", _("Close"));
            dialog.close_response = "close";
            dialog.present(parent);
        }
    }
}
