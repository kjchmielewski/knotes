using Gee;

namespace Knotes {

    public class FolderTreeView : Gtk.Box {
        private const string FOLDER_ICON_NAME = "folder-symbolic";
        private const int FOLDER_ICON_SIZE = 16;
        private const string SELECTED_FOLDER_CSS_CLASS = "selected-folder";

        private NotebookCatalog catalog;
        private HashMap<string, NoteRow> note_rows;
        private HashMap<string, Gtk.Button> folder_buttons;
        private HashMap<string, Gtk.Widget> folder_widgets;
        private ArrayList<Gtk.ListBox> note_lists;

        public signal void note_activated(string id);
        public signal void folder_activated(string id);

        public FolderTreeView(NotebookCatalog catalog) {
            Object(orientation: Gtk.Orientation.VERTICAL, spacing: 2);
            this.catalog = catalog;
            note_rows = new HashMap<string, NoteRow>();
            folder_buttons = new HashMap<string, Gtk.Button>();
            folder_widgets = new HashMap<string, Gtk.Widget>();
            note_lists = new ArrayList<Gtk.ListBox>();
            rebuild();
        }

        public void rebuild() {
            remove_all_children();
            note_rows.clear();
            folder_buttons.clear();
            folder_widgets.clear();
            note_lists.clear();

            append_notes_for_folder("", this);
            foreach (var folder in catalog.child_folders(null)) {
                append_folder(folder, this);
            }
        }

        public bool contains_note(string id) {
            return note_rows.has_key(id);
        }

        public void update_note(Note note) {
            var row = note_rows[note.id];
            if (row == null) {
                return;
            }
            if (row.folder_id != note.folder_id) {
                rebuild();
                return;
            }
            row.update(note);
        }

        public void select_note(string? id) {
            var selected_row = id != null ? note_rows[id] : null;
            foreach (var note_list in note_lists) {
                note_list.select_row(
                    selected_row != null && selected_row.get_parent() == note_list
                        ? selected_row
                        : null
                );
            }
        }

        public void select_folder(string? id) {
            foreach (var entry in folder_buttons.entries) {
                entry.value.remove_css_class(SELECTED_FOLDER_CSS_CLASS);
            }
            if (id != null && folder_buttons.has_key(id)) {
                folder_buttons[id].add_css_class(SELECTED_FOLDER_CSS_CLASS);
            }
        }

        public void filter(string query) {
            foreach (var entry in note_rows.entries) {
                var note = catalog.find_note(entry.key);
                entry.value.visible = note != null &&
                    (query.length == 0 || catalog.note_matches_query(note, query));
            }
            foreach (var entry in folder_widgets.entries) {
                entry.value.visible = query.length == 0 ||
                    catalog.folder_contains_matching_note(entry.key, query);
            }
        }

        private void remove_all_children() {
            Gtk.Widget? current_child = get_first_child();
            while (current_child != null) {
                var next_child = current_child.get_next_sibling();
                remove(current_child);
                current_child = next_child;
            }
        }

        private void append_folder(Folder folder, Gtk.Box parent) {
            var children = catalog.child_folders(folder.id);
            var has_contents = children.size > 0 || catalog.folder_has_direct_notes(folder.id);

            var folder_button = create_folder_button(folder);
            folder_buttons[folder.id] = folder_button;
            folder_button.clicked.connect(() => folder_activated(folder.id));

            var expander = new Gtk.Expander(null);
            expander.expanded = has_contents;
            expander.label_widget = folder_button;
            expander.add_css_class("folder-expander");
            if (!has_contents) {
                expander.add_css_class("empty-folder-expander");
            }

            var child_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
            child_box.margin_start = 16;
            append_notes_for_folder(folder.id, child_box);
            foreach (var child in children) {
                append_folder(child, child_box);
            }
            expander.child = child_box;
            folder_widgets[folder.id] = expander;
            parent.append(expander);
        }

        private Gtk.Button create_folder_button(Folder folder) {
            var icon = new Gtk.Image.from_icon_name(FOLDER_ICON_NAME);
            icon.pixel_size = FOLDER_ICON_SIZE;

            var label = new Gtk.Label(folder.name);
            label.halign = Gtk.Align.START;
            label.hexpand = true;
            label.ellipsize = Pango.EllipsizeMode.END;
            label.xalign = 0;

            var content = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
            content.append(icon);
            content.append(label);

            var button = new Gtk.Button();
            button.child = content;
            button.halign = Gtk.Align.FILL;
            button.hexpand = true;
            button.add_css_class("flat");
            button.add_css_class("folder-tree-row");
            return button;
        }

        private void append_notes_for_folder(string folder_id, Gtk.Box parent) {
            var notes = catalog.notes_for_folder(folder_id);
            if (notes.size == 0) {
                return;
            }

            var note_list = new Gtk.ListBox();
            note_list.selection_mode = Gtk.SelectionMode.SINGLE;
            note_list.add_css_class("folder-note-list");
            note_list.row_activated.connect(on_row_activated);
            note_lists.add(note_list);
            foreach (var note in notes) {
                var row = new NoteRow(note);
                note_rows[note.id] = row;
                note_list.append(row);
            }
            parent.append(note_list);
        }

        private void on_row_activated(Gtk.ListBoxRow row) {
            var note_row = row as NoteRow;
            if (note_row != null) {
                note_activated(note_row.note_id);
            }
        }
    }
}
