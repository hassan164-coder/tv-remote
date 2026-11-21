import SwiftUI

// MARK: - Colors

extension Color {
    static let remoteBackground = Color(red: 0.05, green: 0.06, blue: 0.07)
    static let remoteButton = Color(red: 0.12, green: 0.14, blue: 0.17)
    static let remotePanel = Color(red: 0.08, green: 0.09, blue: 0.11)
    static let remotePower = Color(red: 0.23, green: 0.08, blue: 0.09)
}

// MARK: - Main screen

struct ContentView: View {
    @StateObject private var tv = TVRemote()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSetup = false
    @State private var tab: Panel = .media
    @State private var typedText = ""

    enum Panel: String, CaseIterable, Identifiable {
        case media = "Media", numbers = "123", apps = "Apps", type = "Type"
        var id: Self { self }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                topRow
                DPad(tv: tv)
                navigationRow
                rockers
                Picker("Panel", selection: $tab) {
                    ForEach(Panel.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                panel
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color.remoteBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSetup) { SetupView(tv: tv) }
        .onAppear {
            if tv.ip.isEmpty { showSetup = true } else { tv.reconnectIfNeeded() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { tv.reconnectIfNeeded() }
        }
        .onChange(of: tv.status) { _, status in
            if status == .connected { showSetup = false }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Button { showSetup = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(Color.remoteButton, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .foregroundStyle(.primary)
        }
        .padding(.top, 8)
    }

    private var statusColor: Color {
        switch tv.status {
        case .connected: .green
        case .connecting, .waitingForAllow: .orange
        default: .red
        }
    }

    private var statusText: String {
        switch tv.status {
        case .idle: "Not connected"
        case .connecting: "Connecting to \(tv.ip)…"
        case .waitingForAllow: "Press Allow on your TV"
        case .connected: "Connected · \(tv.ip)"
        case .failed: "Not connected — tap ⚙︎"
        }
    }

    // MARK: Rows

    private var topRow: some View {
        HStack(spacing: 10) {
            KeyButton(action: { tv.press("KEY_POWER") }) {
                Pill(tint: .remotePower) {
                    Image(systemName: "power").font(.title3.weight(.semibold)).foregroundStyle(Color(red: 1, green: 0.55, blue: 0.55))
                }
            }
            key("KEY_SOURCE", "SOURCE")
            key("KEY_MENU", "MENU")
            key("KEY_INFO", "INFO")
        }
    }

    private var navigationRow: some View {
        HStack(spacing: 10) {
            key("KEY_RETURN", systemImage: "arrow.uturn.backward")
            key("KEY_HOME", systemImage: "house")
            key("KEY_EXIT", "EXIT")
        }
    }

    private var rockers: some View {
        HStack(spacing: 12) {
            Rocker(tv: tv, title: "VOL", upKey: "KEY_VOLUP", downKey: "KEY_VOLDOWN",
                   upImage: "plus", downImage: "minus")
            VStack(spacing: 10) {
                KeyButton(action: { tv.press("KEY_MUTE") }) {
                    Pill(height: 64) { Label("Mute", systemImage: "speaker.slash") }
                }
                KeyButton(action: { tv.press("KEY_GUIDE") }) {
                    Pill(height: 64) { Label("Guide", systemImage: "list.bullet.rectangle") }
                }
            }
            Rocker(tv: tv, title: "CH", upKey: "KEY_CHUP", downKey: "KEY_CHDOWN",
                   upImage: "chevron.up", downImage: "chevron.down")
        }
    }

    // MARK: Bottom panels

    @ViewBuilder
    private var panel: some View {
        VStack(spacing: 10) {
            switch tab {
            case .media:
                HStack(spacing: 10) {
                    key("KEY_REWIND", systemImage: "backward.fill", repeats: true)
                    key("KEY_PLAY", systemImage: "play.fill")
                    key("KEY_PAUSE", systemImage: "pause.fill")
                    key("KEY_FF", systemImage: "forward.fill", repeats: true)
                }
                HStack(spacing: 10) {
                    key("KEY_STOP", "STOP")
                    key("KEY_PRECH", "PREV CH")
                    key("KEY_TOOLS", "TOOLS")
                }
            case .numbers:
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(1...9, id: \.self) { n in key("KEY_\(n)", "\(n)", font: .title3) }
                    key("KEY_PRECH", "PRE-CH")
                    key("KEY_0", "0", font: .title3)
                    key("KEY_ENTER", "ENTER")
                }
            case .apps:
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(TVApp.all) { app in
                        KeyButton(action: { tv.launchApp(app.id) }) {
                            Pill(height: 56) { Text(app.name).foregroundStyle(app.color) }
                        }
                    }
                }
                Text("Only apps already installed on the TV will open.")
                    .font(.caption).foregroundStyle(.secondary)
            case .type:
                HStack(spacing: 8) {
                    TextField("Type text for the TV…", text: $typedText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.send)
                        .onSubmit(sendTypedText)
                        .padding(12)
                        .background(Color.remoteBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Button("Send", action: sendTypedText)
                        .fontWeight(.bold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(.white)
                }
                Text("Open a search box on the TV first (for example in YouTube), then send text from here.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.remotePanel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func sendTypedText() {
        guard !typedText.isEmpty else { return }
        tv.sendText(typedText)
        typedText = ""
    }

    // MARK: Small builders

    private func key(_ code: String, _ title: String, font: Font = .system(size: 13, weight: .semibold),
                     repeats: Bool = false) -> some View {
        KeyButton(repeats: repeats, action: { tv.press(code) }) {
            Pill { Text(title).font(font) }
        }
    }

    private func key(_ code: String, systemImage: String, repeats: Bool = false) -> some View {
        KeyButton(repeats: repeats, action: { tv.press(code) }) {
            Pill { Image(systemName: systemImage).font(.title3) }
        }
    }
}

// MARK: - D-pad

struct DPad: View {
    let tv: TVRemote
    private let size: CGFloat = 270

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(red: 0.14, green: 0.16, blue: 0.19), Color(red: 0.09, green: 0.1, blue: 0.13)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(Circle().stroke(Color.white.opacity(0.06), lineWidth: 1))

            arrow("chevron.up", key: "KEY_UP").offset(y: -size * 0.36)
            arrow("chevron.down", key: "KEY_DOWN").offset(y: size * 0.36)
            arrow("chevron.left", key: "KEY_LEFT").offset(x: -size * 0.36)
            arrow("chevron.right", key: "KEY_RIGHT").offset(x: size * 0.36)

            KeyButton(action: { tv.press("KEY_ENTER") }) {
                Text("OK")
                    .font(.headline)
                    .frame(width: size * 0.38, height: size * 0.38)
                    .background(Circle().fill(Color.remoteButton).shadow(color: .black.opacity(0.5), radius: 8, y: 4))
                    .contentShape(Circle())
            }
        }
        .frame(width: size, height: size)
        .padding(.vertical, 4)
    }

    private func arrow(_ systemImage: String, key: String) -> some View {
        KeyButton(repeats: true, action: { tv.press(key) }) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: size * 0.28, height: size * 0.28)
                .contentShape(Rectangle())
        }
    }
}

// MARK: - Volume / channel rocker

struct Rocker: View {
    let tv: TVRemote
    let title: String
    let upKey: String
    let downKey: String
    let upImage: String
    let downImage: String

    var body: some View {
        VStack(spacing: 0) {
            KeyButton(repeats: true, action: { tv.press(upKey) }) {
                Image(systemName: upImage).font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 58).contentShape(Rectangle())
            }
            Text(title).font(.caption2.weight(.bold)).foregroundStyle(.secondary).padding(.vertical, 2)
            KeyButton(repeats: true, action: { tv.press(downKey) }) {
                Image(systemName: downImage).font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 58).contentShape(Rectangle())
            }
        }
        .frame(width: 76)
        .background(Color.remoteButton, in: Capsule())
    }
}

// MARK: - Button building blocks

/// A rounded button face.
struct Pill<Content: View>: View {
    var height: CGFloat = 52
    var tint: Color = .remoteButton
    @ViewBuilder var content: Content

    var body: some View {
        content
            .font(.system(size: 13, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: height)
            .background(tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
    }
}

/// Tap = one key press. With `repeats`, holding the button keeps sending the key.
struct KeyButton<Label: View>: View {
    var repeats = false
    let action: @MainActor () -> Void
    @ViewBuilder var label: Label
    @State private var holdState = HoldState()

    var body: some View {
        Button {
            if holdState.didRepeat {
                holdState.didRepeat = false   // the hold already sent the key
            } else {
                action()
            }
        } label: {
            label
        }
        .buttonStyle(KeyPressStyle(repeats: repeats, holdState: holdState, action: action))
        .foregroundStyle(.primary)
    }
}

@MainActor
final class HoldState {
    var task: Task<Void, Never>?
    var didRepeat = false
}

struct KeyPressStyle: ButtonStyle {
    let repeats: Bool
    let holdState: HoldState
    let action: @MainActor () -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? 0.12 : 0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                holdState.task?.cancel()
                holdState.task = nil
                guard repeats, pressed else { return }
                holdState.didRepeat = false
                let state = holdState
                let send = action
                state.task = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(450))
                    while !Task.isCancelled {
                        state.didRepeat = true
                        send()
                        try? await Task.sleep(for: .milliseconds(150))
                    }
                }
            }
    }
}

// MARK: - TV apps

struct TVApp: Identifiable {
    let id: String
    let name: String
    let color: Color

    static let all: [TVApp] = [
        TVApp(id: "3201907018807", name: "Netflix", color: Color(red: 1, green: 0.35, blue: 0.37)),
        TVApp(id: "111299001912", name: "YouTube", color: Color(red: 1, green: 0.42, blue: 0.42)),
        TVApp(id: "3201910019365", name: "Prime Video", color: Color(red: 0.35, green: 0.7, blue: 1)),
        TVApp(id: "3201901017640", name: "Disney+", color: Color(red: 0.48, green: 0.65, blue: 1)),
        TVApp(id: "3201606009684", name: "Spotify", color: Color(red: 0.29, green: 0.87, blue: 0.5)),
        TVApp(id: "3201807016597", name: "Apple TV", color: .white),
    ]
}

// MARK: - Setup screen

struct SetupView: View {
    @ObservedObject var tv: TVRemote
    @Environment(\.dismiss) private var dismiss
    @State private var ipText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("192.168.0.193", text: $ipText)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: ipText) { _, value in
                            // Swedish keyboards may give "," instead of "."
                            let fixed = value.replacingOccurrences(of: ",", with: ".")
                                .replacingOccurrences(of: " ", with: "")
                            if fixed != value { ipText = fixed }
                        }
                } header: {
                    Text("TV IP address")
                } footer: {
                    Text("On the TV: Settings → General → Network → Network Status → IP Settings.")
                }

                Section {
                    Button {
                        tv.ip = ipText.trimmingCharacters(in: .whitespaces)
                        tv.connect()
                    } label: {
                        HStack {
                            Text("Connect").fontWeight(.semibold)
                            Spacer()
                            if tv.isBusy { ProgressView() }
                        }
                    }
                    .disabled(tv.isBusy)

                    statusRow
                } footer: {
                    Text("iPhone and TV must be on the same Wi‑Fi, and the TV must be on. The first time, your iPhone asks to find devices on your local network: tap Allow. Then press Allow on the TV with the normal remote.")
                }

                Section("Troubleshooting") {
                    Button("Forget pairing", role: .destructive) { tv.forgetPairing() }
                    if !tv.log.isEmpty {
                        Text(tv.log.joined(separator: "\n"))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Connect to TV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { ipText = tv.ip }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var statusRow: some View {
        switch tv.status {
        case .idle:
            EmptyView()
        case .connecting:
            Text("Connecting…").foregroundStyle(.secondary)
        case .waitingForAllow:
            Label("Look at your TV and press Allow", systemImage: "tv").foregroundStyle(.orange)
        case .connected:
            Label("Connected", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
        }
    }
}

#Preview {
    ContentView()
}
