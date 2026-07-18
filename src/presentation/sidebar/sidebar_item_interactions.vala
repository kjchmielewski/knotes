namespace Knotes {

    public class SidebarItemInteractions : GLib.Object {
        private Gtk.Widget widget;
        private SidebarDragItem item;

        public signal void move_requested(SidebarDragItem item);

        public SidebarItemInteractions(Gtk.Widget widget, SidebarDragItem item) {
            this.widget = widget;
            this.item = item;
            configure_context_request();
            configure_drag_source();
        }

        private void configure_context_request() {
            widget.focusable = true;

            var secondary_click = new Gtk.GestureClick();
            secondary_click.button = Gdk.BUTTON_SECONDARY;
            secondary_click.pressed.connect(() => move_requested(item));
            widget.add_controller(secondary_click);

            var key_controller = new Gtk.EventControllerKey();
            key_controller.key_pressed.connect((keyval, keycode, state) => {
                var context_menu_key = keyval == Gdk.Key.Menu;
                var shift_f10 = keyval == Gdk.Key.F10 &&
                    (state & Gdk.ModifierType.SHIFT_MASK) != 0;
                if (!context_menu_key && !shift_f10) {
                    return false;
                }
                move_requested(item);
                return true;
            });
            widget.add_controller(key_controller);
        }

        private void configure_drag_source() {
            var drag_source = new Gtk.DragSource();
            drag_source.actions = Gdk.DragAction.MOVE;
            drag_source.prepare.connect(() => {
                var value = Value(typeof(string));
                value.set_string(item.serialize());
                return new Gdk.ContentProvider.for_value(value);
            });
            widget.add_controller(drag_source);
        }
    }
}
