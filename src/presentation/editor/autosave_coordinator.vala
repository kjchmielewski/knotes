namespace Knotes {

    public delegate void SaveOperation();

    public class AutosaveCoordinator : GLib.Object {
        public const uint DEFAULT_DELAY_MS = 500;

        private uint timeout_id = 0;
        private SaveOperation save_operation;

        public AutosaveCoordinator(owned SaveOperation save_operation) {
            this.save_operation = (owned) save_operation;
        }

        public void schedule(uint delay_ms = DEFAULT_DELAY_MS) {
            cancel();
            timeout_id = Timeout.add(delay_ms, () => {
                timeout_id = 0;
                save_operation();
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
            save_operation();
        }
    }
}
