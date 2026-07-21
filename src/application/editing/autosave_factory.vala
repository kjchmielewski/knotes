namespace Knotes {

    public class DefaultAutosaveFactory : GLib.Object, AutosaveFactory {
        public AutosaveScheduler create(owned SaveDelegate save_delegate) {
            return new AutosaveCoordinator((owned) save_delegate);
        }
    }
}
