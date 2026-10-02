import AppKit

/// Dialogues d'installation / désinstallation des hooks : aperçu du diff, puis confirmation.
@MainActor
enum HooksInstallFlow {
    static func run(install: Bool) {
        // App sans Dock : il faut l'activer pour que la fenêtre passe au premier plan.
        NSApp.activate(ignoringOtherApps: true)
        do {
            let change = try HooksInstaller.plan(install: install)
            guard !change.isEmpty else {
                info(install ? "Hooks déjà installés" : "Aucun hook Noticode à retirer", details: nil)
                return
            }
            guard confirm(change, install: install) else { return }

            let backup = try HooksInstaller.apply(change)
            var details = "Relance tes sessions Claude Code en cours si les notifications n'apparaissent pas."
            if let backup { details = "Sauvegarde : \(backup.path)\n\n" + details }
            info(install ? "Hooks installés" : "Hooks retirés", details: details)
        } catch {
            info("Échec", details: error.localizedDescription)
        }
    }

    private static func confirm(_ change: HooksChange, install: Bool) -> Bool {
        let alert = NSAlert()
        alert.messageText = install ? "Installer les hooks Noticode ?" : "Retirer les hooks Noticode ?"
        alert.informativeText = """
            Modifications de ~/.claude/settings.json. Une sauvegarde datée est créée avant l'écriture ; \
            les autres hooks sont conservés (le fichier est réécrit avec ses clés triées) :
            """
        alert.accessoryView = diffView(change.diff)
        alert.addButton(withTitle: install ? "Installer" : "Retirer")
        alert.addButton(withTitle: "Annuler")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private static func info(_ title: String, details: String?) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = details ?? ""
        alert.runModal()
    }

    private static func diffView(_ diff: String) -> NSView {
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 560, height: 260))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        let textView = NSTextView(frame: scroll.bounds)
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.string = diff
        scroll.documentView = textView
        return scroll
    }
}
