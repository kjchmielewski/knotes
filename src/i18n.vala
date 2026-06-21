namespace Knotes {
    public string _(string msgid) {
        return GLib.dgettext(GETTEXT_PACKAGE, msgid);
    }
}
