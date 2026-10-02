import SwiftUI

/// Onglet « Aide » des Réglages : ce que veut dire chaque notch, comment le fermer, état des hooks, dépannage.
struct HelpView: View {
    @Binding var hooksInstalled: Bool

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Noticode \(short) (\(build))"
    }

    var body: some View {
        Form {
            Section("Ce que montre le notch") {
                row(NotchPreview(kind: .finished, title: "Terminé"),
                    "Claude a fini de répondre.")
                row(NotchPreview(kind: .question, title: "Question"),
                    "Claude te pose une question.")
                row(NotchPreview(kind: .question, title: "Autorisation"),
                    "Claude demande la permission d'utiliser un outil (la commande s'affiche dessous).")
                row(NotchPreview(kind: .question, title: "En attente"),
                    "Rappel : Claude attend ta réponse depuis un moment.")
                row(NotchPreview(kind: .error, title: "Erreur"),
                    "La réponse a échoué (limite atteinte, erreur réseau…).")
                row(NotchPreview(kind: .finished, title: "Terminé", isAuto: true),
                    "Session en mode auto : « Terminé », « Erreur » et le rappel s'affichent en petit, son plus discret.")
            }

            Section("Fermer une notification") {
                Text("Glisse vers le haut sur le notch : deux doigts sur le trackpad, ou clic maintenu puis vers le haut. Sinon il se ferme seul (durée réglable dans l'onglet Réglages).")
            }

            Section {
                HStack {
                    if hooksInstalled {
                        Label("Hooks installés", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Hooks non installés : Noticode ne reçoit rien.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Installer…") {
                            HooksInstallFlow.run(install: true)
                            hooksInstalled = HooksInstaller.isInstalled
                        }
                    }
                }
            } header: {
                Text("Hooks Claude Code")
            } footer: {
                Text("Les hooks (dans ~/.claude/settings.json) préviennent Noticode de ce que fait Claude Code. Pour les retirer : menu de Noticode dans la barre des menus.")
                    .foregroundStyle(.secondary)
            }

            Section {
                tip("Aucune notification ?",
                    "Vérifie que Noticode tourne (icône dans la barre des menus) et que les hooks sont installés, puis relance les sessions Claude Code déjà ouvertes.")
                tip("Pas de son ?",
                    "Vérifie « Couper le son » dans le menu et le volume dans l'onglet Réglages.")
                tip("Pas de rappel « En attente » ?",
                    "Claude Code ne l'envoie que si tu sembles loin du terminal depuis environ une minute.")
            } header: {
                Text("Dépannage")
            } footer: {
                VStack(spacing: 2) {
                    Text(version)
                    Text("© 2026 Raphaël Descamps. Logiciel libre sous licence GNU AGPL v3, sans aucune garantie.")
                    Link("Code source", destination: URL(string: "https://github.com/Raaaphhh/Noticode")!)
                }
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .formStyle(.grouped)
    }

    private func row(_ preview: NotchPreview, _ text: String) -> some View {
        HStack(spacing: 12) {
            preview
            Text(text)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func tip(_ question: String, _ answer: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(question).fontWeight(.medium)
            Text(answer)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Petite image fixe d'un notch, pour la légende (Notiboy = icône de l'app, sans animation).
private struct NotchPreview: View {
    let kind: NoticeKind
    let title: String
    var isAuto = false

    private var haloColor: Color { isAuto ? NoticeKind.autoModeColor : kind.color }

    var body: some View {
        HStack(spacing: 5) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 18, height: 18)
                .background(
                    Circle().fill(RadialGradient(colors: [haloColor.opacity(0.6), .clear],
                                                 center: .center, startRadius: 0, endRadius: 13))
                )
            Image(systemName: kind.symbol)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(kind.color)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 6)
            if isAuto {
                AutoBadge(fontSize: 8)
            } else {
                HStack(spacing: 3) {
                    Image(systemName: "folder.fill")
                    Text("demo")
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .frame(width: 190, height: 28)
        .background(NotchShape(topRadius: 6, bottomRadius: 10).fill(.black))
        .overlay {
            if isAuto {
                NotchShape(topRadius: 6, bottomRadius: 10, closesTop: false)
                    .stroke(NoticeKind.autoModeColor.opacity(0.7), lineWidth: 1)
            }
        }
    }
}
