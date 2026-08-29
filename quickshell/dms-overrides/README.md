# dms-shell overrides

Hand-patched copies of files from the `dms-shell` pacman package
(installed under `/usr/share/quickshell/dms/`), kept here because
package updates overwrite them with no warning.

Adds a "Notes" tab (a kanban board) to the DankDash popout. Files,
relative to `/usr/share/quickshell/dms/`:

- `Common/SettingsData.qml` — registers a `notes` entry in `_dashTabIds`/`_dashTabsDefault`
- `Modules/DankDash/DankDashPopout.qml` — wires up a `notes` tab (icon, loader, sizing) alongside the existing tabs
- `Modules/DankDash/NotesKanbanTab.qml` — new file, the tab's content component

`Modules/DankDash/KanbanBoard.qml` had a `.bak` sitting next to it too,
but it's byte-identical to the package original, so it's not included
here.

To reapply after a `dms-shell` update, diff the installed file against
its package original and re-patch, or just copy these over (as root)
and re-check they still apply cleanly against the new upstream version:

```sh
sudo cp quickshell/dms-overrides/Common/SettingsData.qml /usr/share/quickshell/dms/Common/SettingsData.qml
sudo cp quickshell/dms-overrides/Modules/DankDash/DankDashPopout.qml /usr/share/quickshell/dms/Modules/DankDash/DankDashPopout.qml
sudo cp quickshell/dms-overrides/Modules/DankDash/NotesKanbanTab.qml /usr/share/quickshell/dms/Modules/DankDash/NotesKanbanTab.qml
```
