namespace Knotes {

    public class CompactNoteRow : Gtk.ListBoxRow {
        private const string DRAG_PAYLOAD_PREFIX = "note:";
        private Gtk.Label avatar_label;

        public string note_id { get; construct; }

        public signal void move_requested(string id);

        public CompactNoteRow(Note note) {
            Object(note_id: note.id);

            avatar_label = new Gtk.Label(avatar_text_for_title(note.title));
            avatar_label.add_css_class("compact-note-avatar");
            avatar_label.halign = Gtk.Align.CENTER;
            avatar_label.valign = Gtk.Align.CENTER;

            var row_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            row_box.halign = Gtk.Align.CENTER;
            row_box.append(avatar_label);
            child = row_box;

            update(note);
            configure_move_interactions();
        }

        public void update(Note note) {
            avatar_label.label = avatar_text_for_title(note.title);
            tooltip_text = note.title;
        }

        private static string avatar_text_for_title(string title) {
            var trimmed_title = title.strip();
            if (trimmed_title.length == 0) {
                return "?";
            }

            var avatar_text = new StringBuilder();
            var cursor = trimmed_title;
            for (var index = 0; index < 2 && cursor.length > 0; index++) {
                var character = cursor.get_char(0);
                avatar_text.append_unichar(character.toupper());
                cursor = cursor.next_char();
            }

            return avatar_text.str;
        }

        private void configure_move_interactions() {
            focusable = true;

            var secondary_click = new Gtk.GestureClick();
            secondary_click.button = Gdk.BUTTON_SECONDARY;
            secondary_click.pressed.connect(() => move_requested(note_id));
            add_controller(secondary_click);

            var key_controller = new Gtk.EventControllerKey();
            key_controller.key_pressed.connect((keyval, keycode, state) => {
                var context_menu_key = keyval == Gdk.Key.Menu;
                var shift_f10 = keyval == Gdk.Key.F10 &&
                    (state & Gdk.ModifierType.SHIFT_MASK) != 0;
                if (!context_menu_key && !shift_f10) {
                    return false;
                }
                move_requested(note_id);
                return true;
            });
            add_controller(key_controller);

            var drag_source = new Gtk.DragSource();
            drag_source.actions = Gdk.DragAction.MOVE;
            drag_source.prepare.connect(() => create_drag_content(DRAG_PAYLOAD_PREFIX + note_id));
            add_controller(drag_source);
        }

        private Gdk.ContentProvider create_drag_content(string payload) {
            var value = Value(typeof(string));
            value.set_string(payload);
            return new Gdk.ContentProvider.for_value(value);
        }
    }
}
