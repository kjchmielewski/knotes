namespace Knotes.Tests {

    private Note create_note(string id, string folder_id = "") {
        var timestamp = new DateTime.from_unix_utc(10);
        return new Note(id, id, "", timestamp, timestamp, folder_id);
    }

    private NotebookCatalog create_catalog() {
        var catalog = new NotebookCatalog();
        var folders = new GLib.List<Folder>();
        folders.append(new Folder("parent", "Parent"));
        folders.append(new Folder("child", "Child", "parent"));
        catalog.replace_folders(folders);
        var notes = new GLib.List<Note>();
        notes.append(create_note("root-note"));
        notes.append(create_note("child-note", "child"));
        catalog.replace_notes(notes);
        return catalog;
    }

    private void test_note_selection_selects_its_folder() {
        var model = new SidebarSelectionModel(create_catalog());
        model.select_note("child-note");
        assert(model.selected_note_id == "child-note");
        assert(model.selected_folder_id == "child");
    }

    private void test_incompatible_folder_clears_note() {
        var model = new SidebarSelectionModel(create_catalog());
        model.select_note("child-note");
        model.select_folder("parent");
        assert(model.selected_note_id == null);
        assert(model.selected_folder_id == "parent");
    }

    private void test_missing_folder_normalizes_to_root() {
        var model = new SidebarSelectionModel(create_catalog());
        model.select_folder("missing");
        assert(model.selected_folder_id == null);
    }

    private void test_removing_selected_note_clears_note_selection() {
        var model = new SidebarSelectionModel(create_catalog());
        model.select_note("child-note");
        model.remove_note("child-note");
        assert(model.selected_note_id == null);
        assert(model.selected_folder_id == "child");
    }

    private void test_reconcile_selected_note_updates_folder() {
        var catalog = create_catalog();
        var model = new SidebarSelectionModel(catalog);
        model.select_note("child-note");
        catalog.find_note("child-note").folder_id = "parent";
        model.reconcile_note("child-note");
        assert(model.selected_note_id == "child-note");
        assert(model.selected_folder_id == "parent");
    }

    private void test_selected_note_with_missing_folder_uses_root() {
        var catalog = create_catalog();
        var notes = new GLib.List<Note>();
        notes.append(create_note("orphaned-note", "missing"));
        catalog.replace_notes(notes);
        var model = new SidebarSelectionModel(catalog);
        model.select_note("orphaned-note");
        assert(model.selected_note_id == "orphaned-note");
        assert(model.selected_folder_id == null);
    }

    private void test_view_reconciliation_preserves_selection() {
        var model = new SidebarSelectionModel(create_catalog());
        model.select_note("child-note");
        model.reconcile_note("child-note");
        assert(model.selected_note_id == "child-note");
        assert(model.selected_folder_id == "child");
    }

    private void test_selection_publishes_independent_changes() {
        var model = new SidebarSelectionModel(create_catalog());
        var note_changes = 0;
        var folder_changes = 0;
        model.note_selection_changed.connect(() => note_changes++);
        model.folder_selection_changed.connect(() => folder_changes++);

        model.select_note("child-note");
        assert(note_changes == 1);
        assert(folder_changes == 1);

        model.select_folder("parent");
        assert(note_changes == 2);
        assert(folder_changes == 2);
    }

    private void test_drag_items_round_trip() {
        var note = SidebarDragItem.parse(SidebarDragItem.note("note-id").serialize());
        var folder = SidebarDragItem.parse(SidebarDragItem.folder("folder-id").serialize());
        assert(note != null && note.item_type == SidebarDragItemType.NOTE && note.id == "note-id");
        assert(folder != null && folder.item_type == SidebarDragItemType.FOLDER && folder.id == "folder-id");
    }

    private void test_drag_items_reject_invalid_payloads() {
        assert(SidebarDragItem.parse("") == null);
        assert(SidebarDragItem.parse("note:") == null);
        assert(SidebarDragItem.parse("folder:") == null);
        assert(SidebarDragItem.parse("unknown:id") == null);
        assert(SidebarDragItem.parse("note:id:extra") == null);
        assert(SidebarDragItem.parse("note: ") == null);
        assert(SidebarDragItem.parse("folder:id\n") == null);
    }

    private void test_drag_items_validate_destinations() {
        var catalog = create_catalog();
        assert(SidebarDragItem.note("root-note").can_drop(catalog, "parent"));
        assert(!SidebarDragItem.note("root-note").can_drop(catalog, null));
        assert(!SidebarDragItem.folder("parent").can_drop(catalog, "child"));
        assert(!SidebarDragItem.folder("child").can_drop(catalog, "parent"));
        assert(SidebarDragItem.folder("child").can_drop(catalog, null));
        assert(!SidebarDragItem.folder("child").can_drop(catalog, "missing"));
    }

    public static int main(string[] args) {
        Test.init(ref args);
        Test.add_func("/sidebar-selection/select-note-folder", test_note_selection_selects_its_folder);
        Test.add_func("/sidebar-selection/incompatible-folder", test_incompatible_folder_clears_note);
        Test.add_func("/sidebar-selection/missing-folder", test_missing_folder_normalizes_to_root);
        Test.add_func("/sidebar-selection/remove-note", test_removing_selected_note_clears_note_selection);
        Test.add_func("/sidebar-selection/reconcile-note", test_reconcile_selected_note_updates_folder);
        Test.add_func(
            "/sidebar-selection/missing-note-folder",
            test_selected_note_with_missing_folder_uses_root
        );
        Test.add_func(
            "/sidebar-selection/view-reconciliation",
            test_view_reconciliation_preserves_selection
        );
        Test.add_func(
            "/sidebar-selection/independent-signals",
            test_selection_publishes_independent_changes
        );
        Test.add_func("/sidebar-drag-item/round-trip", test_drag_items_round_trip);
        Test.add_func("/sidebar-drag-item/invalid-payloads", test_drag_items_reject_invalid_payloads);
        Test.add_func("/sidebar-drag-item/destinations", test_drag_items_validate_destinations);
        return Test.run();
    }
}
