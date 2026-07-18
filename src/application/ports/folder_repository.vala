namespace Knotes {

    public interface FolderRepository : GLib.Object {
        public abstract GLib.List<Folder> list_folders();
        public abstract void save_folders(GLib.List<Folder> folders) throws GLib.Error;
    }
}
