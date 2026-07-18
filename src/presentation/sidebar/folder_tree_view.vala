using Gee;

namespace Knotes {

    public class FolderTreeView : Gtk.Box {
        private const string FOLDER_ICON_NAME = "folder-symbolic";
        private const int FOLDER_ICON_SIZE = 16;
        private const string SELECTED_FOLDER_CSS_CLASS = "selected-folder";
        private const string DROP_TARGET_CSS_CLASS = "move-drop-target";
        private const string NOTE_DRAG_PREFIX = "note:";
        private const string FOLDER_DRAG_PREFIX = "folder:";

        private NotebookCatalog catalog;
        private HashMap<string, NoteRow> note_rows;
        private HashMap<string, Gtk.Button> folder_buttons;
        private HashMap<string, Gtk.Widget> folder_widgets;
        private ArrayList<Gtk.ListBox> note_lists;
        private HashSet<string> expanded_folder_ids;
        private bool has_expansion_state = false;

        public signal void note_activated(string id);
        public signal void folder_activated(string id);
        public signal void note_move_dialog_requested(string id);
        public signal void folder_move_dialog_requested(string id);
        public signal void note_move_requested(string id, string? destination_folder_id);
        public signal void folder_move_requested(string id, string? destination_parent_id);

        public FolderTreeView(NotebookCatalog catalog) {
            Object(orientation: Gtk.Orientation.VERTICAL, spacing: 2);
            this.catalog = catalog;
            note_rows = new HashMap<string, NoteRow>();
            folder_buttons = new HashMap<string, Gtk.Button>();
            folder_widgets = new HashMap<string, Gtk.Widget>();
            note_lists = new ArrayList<Gtk.ListBox>();
            expanded_folder_ids = new HashSet<string>();
            rebuild();
        }

        public void rebuild() {
            if (folder_widgets.size > 0) {
                capture_expansion_state();
                has_expansion_state = true;
            }
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

        public void expand_path(string? folder_id) {
            var visited_folder_ids = new HashSet<string>();
            string? current_id = folder_id;
            while (current_id != null && !visited_folder_ids.contains(current_id)) {
                visited_folder_ids.add(current_id);
                expanded_folder_ids.add(current_id);

                var widget = folder_widgets[current_id] as Gtk.Expander;
                if (widget != null) {
                    widget.expanded = true;
                }

                var folder = catalog.find_folder(current_id);
                current_id = folder != null ? folder.parent_id : null;
            }
            has_expansion_state = true;
        }

        public void configure_drop_destination(Gtk.Widget widget, string? destination_folder_id) {
            var drop_target = new Gtk.DropTarget(typeof(string), Gdk.DragAction.MOVE);
            drop_target.preload = true;
            drop_target.enter.connect(() => {
                if (!can_accept_current_drop(drop_target, destination_folder_id)) {
                    return (Gdk.DragAction) 0;
                }
                widget.add_css_class(DROP_TARGET_CSS_CLASS);
                return Gdk.DragAction.MOVE;
            });
            drop_target.motion.connect(() => {
                return can_accept_current_drop(drop_target, destination_folder_id)
                    ? Gdk.DragAction.MOVE
                    : (Gdk.DragAction) 0;
            });
            drop_target.leave.connect(() => widget.remove_css_class(DROP_TARGET_CSS_CLASS));
            drop_target.drop.connect((value, x, y) => {
                widget.remove_css_class(DROP_TARGET_CSS_CLASS);
                var payload = value.get_string();
                if (payload == null || !can_accept_payload(payload, destination_folder_id)) {
                    return false;
                }
                dispatch_drop(payload, destination_folder_id);
                return true;
            });
            widget.add_controller(drop_target);
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

        private void capture_expansion_state() {
            expanded_folder_ids.clear();
            foreach (var entry in folder_widgets.entries) {
                var expander = entry.value as Gtk.Expander;
                if (expander != null && expander.expanded) {
                    expanded_folder_ids.add(entry.key);
                }
            }
        }

        private void append_folder(Folder folder, Gtk.Box parent) {
            var children = catalog.child_folders(folder.id);
            var has_contents = children.size > 0 || catalog.folder_has_direct_notes(folder.id);

            var folder_button = create_folder_button(folder);
            folder_buttons[folder.id] = folder_button;
            folder_button.clicked.connect(() => folder_activated(folder.id));
            configure_folder_interactions(folder_button, folder);
            configure_drop_destination(folder_button, folder.id);

            var expander = new Gtk.Expander(null);
            expander.expanded = has_expansion_state
                ? expanded_folder_ids.contains(folder.id)
                : has_contents;
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
            expander.notify["expanded"].connect(() => {
                if (expander.expanded) {
                    expanded_folder_ids.add(folder.id);
                } else {
                    expanded_folder_ids.remove(folder.id);
                }
                has_expansion_state = true;
            });
            folder_widgets[folder.id] = expander;
            parent.append(expander);
        }

        private void configure_folder_interactions(Gtk.Button button, Folder folder) {
            var secondary_click = new Gtk.GestureClick();
            secondary_click.button = Gdk.BUTTON_SECONDARY;
            secondary_click.pressed.connect(() => folder_move_dialog_requested(folder.id));
            button.add_controller(secondary_click);

            var key_controller = new Gtk.EventControllerKey();
            key_controller.key_pressed.connect((keyval, keycode, state) => {
                var context_menu_key = keyval == Gdk.Key.Menu;
                var shift_f10 = keyval == Gdk.Key.F10 &&
                    (state & Gdk.ModifierType.SHIFT_MASK) != 0;
                if (!context_menu_key && !shift_f10) {
                    return false;
                }
                folder_move_dialog_requested(folder.id);
                return true;
            });
            button.add_controller(key_controller);

            var drag_source = new Gtk.DragSource();
            drag_source.actions = Gdk.DragAction.MOVE;
            drag_source.prepare.connect(() => create_drag_content(FOLDER_DRAG_PREFIX + folder.id));
            button.add_controller(drag_source);
        }

        private Gdk.ContentProvider create_drag_content(string payload) {
            var value = Value(typeof(string));
            value.set_string(payload);
            return new Gdk.ContentProvider.for_value(value);
        }

        private bool can_accept_current_drop(
            Gtk.DropTarget drop_target,
            string? destination_folder_id
        ) {
            unowned Value? value = drop_target.get_value();
            if (value == null) {
                return false;
            }
            var payload = value.get_string();
            return payload != null && can_accept_payload(payload, destination_folder_id);
        }

        private bool can_accept_payload(string payload, string? destination_folder_id) {
            if (payload.has_prefix(NOTE_DRAG_PREFIX)) {
                var note_id = payload.substring(NOTE_DRAG_PREFIX.length);
                var note = catalog.find_note(note_id);
                if (note == null ||
                    (destination_folder_id != null && !catalog.contains_folder(destination_folder_id))) {
                    return false;
                }
                return note.folder_id != (destination_folder_id ?? "");
            }

            if (payload.has_prefix(FOLDER_DRAG_PREFIX)) {
                var folder_id = payload.substring(FOLDER_DRAG_PREFIX.length);
                var folder = catalog.find_folder(folder_id);
                return folder != null &&
                    folder.parent_id != destination_folder_id &&
                    catalog.is_valid_folder_destination(folder_id, destination_folder_id);
            }
            return false;
        }

        private void dispatch_drop(string payload, string? destination_folder_id) {
            if (payload.has_prefix(NOTE_DRAG_PREFIX)) {
                note_move_requested(
                    payload.substring(NOTE_DRAG_PREFIX.length),
                    destination_folder_id
                );
            } else if (payload.has_prefix(FOLDER_DRAG_PREFIX)) {
                folder_move_requested(
                    payload.substring(FOLDER_DRAG_PREFIX.length),
                    destination_folder_id
                );
            }
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
                row.move_requested.connect((id) => note_move_dialog_requested(id));
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
