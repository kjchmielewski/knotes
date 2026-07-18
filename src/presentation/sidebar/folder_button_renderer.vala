namespace Knotes {

    public class FolderButtonRenderer {
        private const string FOLDER_ICON_NAME = "folder-symbolic";
        private const int FOLDER_ICON_SIZE = 16;

        private FolderButtonRenderer() {
        }

        public static Gtk.Button create(string name) {
            var button = new Gtk.Button();
            configure(button, name);
            return button;
        }

        public static void configure(Gtk.Button button, string name) {
            var icon = new Gtk.Image.from_icon_name(FOLDER_ICON_NAME);
            icon.pixel_size = FOLDER_ICON_SIZE;

            var label = new Gtk.Label(name);
            label.halign = Gtk.Align.START;
            label.hexpand = true;
            label.ellipsize = Pango.EllipsizeMode.END;
            label.xalign = 0;

            var content = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
            content.append(icon);
            content.append(label);
            button.child = content;
            button.halign = Gtk.Align.FILL;
            button.hexpand = true;
            button.add_css_class("flat");
            button.add_css_class("folder-tree-row");
        }
    }
}
