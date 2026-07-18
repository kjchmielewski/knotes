namespace Knotes {

    public enum MoveResult {
        MOVED,
        UNCHANGED,
        SOURCE_NOT_FOUND,
        DESTINATION_NOT_FOUND,
        CYCLE_DETECTED,
        STORAGE_ERROR
    }
}
