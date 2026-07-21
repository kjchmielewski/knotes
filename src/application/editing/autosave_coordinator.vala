namespace Knotes {

    public class AutosaveCoordinator : GLib.Object, AutosaveScheduler {
        public const uint DEFAULT_DELAY_MS = DEFAULT_AUTOSAVE_DELAY_MS;

        private uint timeout_id = 0;
        private SaveDelegate save_delegate;

        public AutosaveCoordinator(owned SaveDelegate save_delegate) {
            this.save_delegate = (owned) save_delegate;
        }

        public void schedule(uint delay_ms = DEFAULT_DELAY_MS) {
            cancel();
            timeout_id = Timeout.add(delay_ms, () => {
                timeout_id = 0;
                save_delegate();
                return false;
            });
        }

        public void cancel() {
            if (timeout_id == 0) {
                return;
            }
            Source.remove(timeout_id);
            timeout_id = 0;
        }

        public void flush() {
            if (timeout_id == 0) {
                return;
            }
            cancel();
            save_delegate();
        }
    }
}
