import SwiftUI

struct SettingsView: View {
    let sounds: SoundPlayer

    @AppStorage(Preferences.volumeKey) private var volume = Preferences.defaultVolume
    @AppStorage(Preferences.durationKey) private var duration = Preferences.defaultDuration
    @AppStorage(Preferences.layoutKey) private var layout = Preferences.defaultLayout
    @AppStorage(Preferences.launchOnSessionStartKey) private var launchOnSessionStart = false
    @State private var hooksInstalled = HooksInstaller.isInstalled

    var body: some View {
        TabView {
            settings.tabItem { Label("Réglages", systemImage: "gearshape") }
            HelpView(hooksInstalled: $hooksInstalled).tabItem { Label("Aide", systemImage: "questionmark.circle") }
        }
        // Les hooks ont pu être installés depuis le menu pendant que la fenêtre était ouverte.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            hooksInstalled = HooksInstaller.isInstalled
        }
        // Hauteur fixe : l'aide est plus longue que l'écran sur un petit Mac, elle défile.
        .frame(width: 520, height: 460)
    }

    private var settings: some View {
        Form {
            Section("Son") {
                LabeledContent("Volume") {
                    HStack {
                        Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                        // Aperçu du son quand on relâche le curseur.
                        Slider(value: $volume, in: 0...1) { editing in
                            if !editing { sounds.playPreview() }
                        }
                        Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Picker("Durée des notifications", selection: $duration) {
                    ForEach(DisplayDuration.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Taille", selection: $layout) {
                    ForEach(NotchLayout.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Affichage")
            } footer: {
                Text("Compacte : la commande ou la question tient sur une ligne, survole le notch pour la lire en entier (le temps s'arrête). Détaillée : jusqu'à 3 lignes d'office.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Ouvrir Noticode au démarrage d'une session Claude Code", isOn: $launchOnSessionStart)
                    .onChange(of: launchOnSessionStart) { _, enabled in
                        AppPaths.updateLaunchFile(enabled: enabled)
                    }
                if launchOnSessionStart && !hooksInstalled {
                    HStack {
                        Label("Les hooks doivent être (ré)installés pour que ce réglage fonctionne.",
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Installer…") {
                            HooksInstallFlow.run(install: true)
                            hooksInstalled = HooksInstaller.isInstalled
                        }
                    }
                }
            } header: {
                Text("Lancement")
            } footer: {
                Text("Si Noticode est fermé, il s'ouvre quand une session Claude Code démarre.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
