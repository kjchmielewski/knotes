namespace Knotes {

    [GtkTemplate(ui = "/com/knotes/app/note_row.ui")]
    public class NoteRow : Gtk.ListBoxRow {
        private const string DRAG_PAYLOAD_PREFIX = "note:";

        [GtkChild]
        private unowned Gtk.Label title_label;
        [GtkChild]
        private unowned Gtk.Label preview_label;

        public string note_id { get; construct; }
        public string folder_id { get; private set; default = ""; }

        public signal void move_requested(string id);

        public NoteRow(Note note) {
            Object(note_id: note.id);
            update(note);
            configure_move_interactions();
        }

        public void update(Note note) {
            folder_id = note.folder_id;
            title_label.label = note.title;
            preview_label.label = note.preview(60);
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
