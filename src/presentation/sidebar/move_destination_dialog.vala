using Gee;

namespace Knotes {

    public class MoveDestinationDialog : GLib.Object {
        private delegate void DestinationAction();

        private NotebookCatalog catalog;

        public signal void note_destination_selected(string note_id, string? folder_id);
        public signal void folder_destination_selected(string folder_id, string? parent_id);

        public MoveDestinationDialog(NotebookCatalog catalog) {
            this.catalog = catalog;
        }

        public void show_for_note(Gtk.Widget parent, Note note) {
            var dialog = create_dialog(_("Move note"));
            var destinations = create_destination_box();
            var destination_count = 0;

            if (note.folder_id.length > 0) {
                add_destination_button(destinations, _("All notes"), () => {
                    dialog.close();
                    note_destination_selected(note.id, null);
                });
                destination_count++;
            }

            foreach (var folder in catalog.folders_sorted_by_name()) {
                if (folder.id == note.folder_id) {
                    continue;
                }
                add_destination_button(destinations, folder_path(folder), () => {
                    dialog.close();
                    note_destination_selected(note.id, folder.id);
                });
                destination_count++;
            }

            finish_dialog(dialog, destinations, destination_count, parent);
        }

        public void show_for_folder(Gtk.Widget parent, Folder folder) {
            var dialog = create_dialog(_("Move folder"));
            var destinations = create_destination_box();
            var destination_count = 0;

            if (folder.parent_id != null) {
                add_destination_button(destinations, _("Top level"), () => {
                    dialog.close();
                    folder_destination_selected(folder.id, null);
                });
                destination_count++;
            }

            foreach (var destination in catalog.folders_sorted_by_name()) {
                if (destination.id == folder.parent_id ||
                    !catalog.is_valid_folder_destination(folder.id, destination.id)) {
                    continue;
                }
                add_destination_button(destinations, folder_path(destination), () => {
                    dialog.close();
                    folder_destination_selected(folder.id, destination.id);
                });
                destination_count++;
            }

            finish_dialog(dialog, destinations, destination_count, parent);
        }

        private Adw.AlertDialog create_dialog(string heading) {
            var dialog = new Adw.AlertDialog(heading, _("Choose a destination."));
            dialog.add_response("cancel", _("Cancel"));
            dialog.close_response = "cancel";
            return dialog;
        }

        private Gtk.Box create_destination_box() {
            var destinations = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
            destinations.margin_top = 8;
            destinations.margin_bottom = 8;
            destinations.add_css_class("move-destination-list");
            return destinations;
        }

        private void add_destination_button(
            Gtk.Box destinations,
            string label,
            owned DestinationAction select_destination
        ) {
            var button = new Gtk.Button.with_label(label);
            button.halign = Gtk.Align.FILL;
            button.hexpand = true;
            button.clicked.connect(() => select_destination());
            destinations.append(button);
        }

        private void finish_dialog(
            Adw.AlertDialog dialog,
            Gtk.Box destinations,
            int destination_count,
            Gtk.Widget parent
        ) {
            Gtk.Widget content = destinations;
            if (destination_count == 0) {
                var message = new Gtk.Label(_("No other destinations are available."));
                message.wrap = true;
                message.margin_top = 12;
                message.margin_bottom = 12;
                content = message;
            }

            var scrolled_window = new Gtk.ScrolledWindow();
            scrolled_window.hscrollbar_policy = Gtk.PolicyType.NEVER;
            scrolled_window.max_content_height = 360;
            scrolled_window.propagate_natural_height = true;
            scrolled_window.child = content;
            dialog.set_extra_child(scrolled_window);
            dialog.present(parent);
        }

        private string folder_path(Folder folder) {
            var components = new ArrayList<string>();
            var visited_folder_ids = new HashSet<string>();
            Folder? current_folder = folder;

            while (current_folder != null && !visited_folder_ids.contains(current_folder.id)) {
                visited_folder_ids.add(current_folder.id);
                components.insert(0, current_folder.name);
                current_folder = current_folder.parent_id != null
                    ? catalog.find_folder(current_folder.parent_id)
                    : null;
            }

            var path = new StringBuilder();
            foreach (var component in components) {
                if (path.len > 0) {
                    path.append(" / ");
                }
                path.append(component);
            }
            return path.str;
        }
    }
}
