namespace Knotes {

    public const uint DEFAULT_AUTOSAVE_DELAY_MS = 500;

    public delegate void SaveDelegate();

    public interface AutosaveScheduler : GLib.Object {
        public abstract void schedule(uint delay_ms = DEFAULT_AUTOSAVE_DELAY_MS);
        public abstract void cancel();
        public abstract void flush();
    }

    public interface AutosaveFactory : GLib.Object {
        public abstract AutosaveScheduler create(owned SaveDelegate save_delegate);
    }
}
