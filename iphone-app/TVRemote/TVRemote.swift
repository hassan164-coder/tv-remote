import Foundation
import UIKit

/// Talks to a Samsung Tizen TV (2016+) over its secure WebSocket remote API:
/// wss://<tv-ip>:8002/api/v2/channels/samsung.remote.control
///
/// Safari refuses the TV's self-signed certificate, but an app may decide to trust it.
/// We trust it ONLY for the exact IP address the user typed in (see TVSessionDelegate).
@MainActor
final class TVRemote: ObservableObject {

    enum Status: Equatable {
        case idle
        case connecting
        case waitingForAllow
        case connected
        case failed(String)
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var log: [String] = []
    @Published var ip: String {
        didSet { UserDefaults.standard.set(ip, forKey: "tv_ip") }
    }

    private var token: String? {
        get { UserDefaults.standard.string(forKey: "tv_token") }
        set { UserDefaults.standard.set(newValue, forKey: "tv_token") }
    }

    private var session: URLSession?
    private var socket: URLSessionWebSocketTask?
    /// Increases on every new connection, so messages from old sockets are ignored.
    private var attempt = 0
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private static let clientName = Data("iPhone Remote".utf8).base64EncodedString()

    init() {
        ip = UserDefaults.standard.string(forKey: "tv_ip") ?? ""
    }

    var isBusy: Bool { status == .connecting || status == .waitingForAllow }

    // MARK: - Connection

    func connect() {
        let host = ip.trimmingCharacters(in: .whitespaces)
        guard Self.isValidIP(host) else {
            status = .failed("Enter a valid IP address, like 192.168.0.193.")
            return
        }
        teardown()
        let id = attempt
        status = .connecting

        var parts = URLComponents()
        parts.scheme = "wss"
        parts.host = host
        parts.port = 8002
        parts.path = "/api/v2/channels/samsung.remote.control"
        var query = [URLQueryItem(name: "name", value: Self.clientName)]
        if let token, !token.isEmpty { query.append(URLQueryItem(name: "token", value: token)) }
        parts.queryItems = query
        guard let url = parts.url else {
            status = .failed("Couldn't build the TV address.")
            return
        }

        let delegate = TVSessionDelegate(trustedHost: host) { [weak self] in
            Task { @MainActor in self?.socketOpened(id) }
        }
        let config = URLSessionConfiguration.ephemeral
        config.tlsMinimumSupportedProtocolVersion = .TLSv10   // TVs can run old TLS
        config.waitsForConnectivity = false
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        let socket = session.webSocketTask(with: url)
        self.session = session
        self.socket = socket

        addLog("Connecting to \(host)…")
        socket.resume()
        listen(socket, id)

        // If the socket hasn't even opened after 8 s, the TV can't be reached.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard let self, self.attempt == id, self.status == .connecting else { return }
            self.fail("Can't reach the TV. Check the IP address and that your iPhone and TV are on the same Wi‑Fi.")
        }
    }

    /// Reconnect when the app comes back to the foreground.
    func reconnectIfNeeded() {
        guard !ip.isEmpty else { return }
        switch status {
        case .idle, .failed: connect()
        default: break
        }
    }

    func forgetPairing() {
        token = nil
        addLog("Pairing forgotten. Connect again and press Allow on the TV.")
    }

    private func socketOpened(_ id: Int) {
        guard attempt == id, status == .connecting else { return }
        addLog("Reached the TV. Waiting for Allow…")
        status = .waitingForAllow
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(35))
            guard let self, self.attempt == id, self.status == .waitingForAllow else { return }
            self.fail("No answer from the TV. Press Allow on the TV when it asks, then try again.")
        }
    }

    private func listen(_ socket: URLSessionWebSocketTask, _ id: Int) {
        Task { [weak self] in
            while true {
                do {
                    let message = try await socket.receive()
                    guard let self, self.attempt == id else { return }
                    if case .string(let text) = message { self.handle(text, id) }
                } catch {
                    guard let self, self.attempt == id else { return }
                    self.socketEnded(error)
                    return
                }
            }
        }
    }

    private func handle(_ text: String, _ id: Int) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = json["event"] as? String else { return }
        addLog("TV says: \(event)")

        switch event {
        case "ms.channel.connect":
            if let info = json["data"] as? [String: Any], let newToken = info["token"] {
                token = "\(newToken)"
                addLog("Pairing saved — no need to press Allow next time.")
            }
            status = .connected
            keepAlive(id)
        case "ms.channel.unauthorized":
            fail("The TV refused. On the TV: Settings → General → External Device Manager → Device Connection Manager → Device List, allow “iPhone Remote”, then tap Forget pairing and Connect.")
        case "ms.channel.timeOut":
            fail("The TV's Allow prompt timed out. Tap Connect and press Allow on the TV.")
        default:
            break
        }
    }

    private func socketEnded(_ error: Error) {
        addLog("Connection ended: \(error.localizedDescription)")
        switch status {
        case .connected:
            fail("Lost connection to the TV.")
        case .connecting:
            fail("Couldn't connect. If your iPhone just asked about Local Network, tap Allow and Connect again. Otherwise check the IP address.")
        case .waitingForAllow:
            fail("The TV closed the connection. Try Connect again and press Allow on the TV.")
        default:
            teardown()
        }
    }

    /// Ping every 20 s so the connection doesn't go idle.
    private func keepAlive(_ id: Int) {
        Task { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(20))
                guard let self, self.attempt == id, self.status == .connected, let socket = self.socket else { return }
                socket.sendPing { _ in }
            }
        }
    }

    private func fail(_ message: String) {
        addLog(message)
        teardown()
        status = .failed(message)
    }

    private func teardown() {
        attempt += 1
        socket?.cancel(with: .goingAway, reason: nil)
        session?.invalidateAndCancel()
        socket = nil
        session = nil
    }

    // MARK: - Commands

    func press(_ key: String) {
        let ok = send([
            "method": "ms.remote.control",
            "params": ["Cmd": "Click", "DataOfCmd": key, "Option": "false", "TypeOfRemote": "SendRemoteKey"]
        ])
        if ok { haptic.impactOccurred() }
    }

    func launchApp(_ appId: String) {
        let ok = send([
            "method": "ms.channel.emit",
            "params": ["event": "ed.apps.launch", "to": "host", "data": ["appId": appId, "action_type": "DEEP_LINK"]]
        ])
        if ok { haptic.impactOccurred() }
    }

    /// Types text into a keyboard/search box that is open on the TV.
    func sendText(_ text: String) {
        let encoded = Data(text.utf8).base64EncodedString()
        let ok = send([
            "method": "ms.remote.control",
            "params": ["Cmd": encoded, "DataOfCmd": "base64", "TypeOfRemote": "SendInputString"]
        ])
        if ok { haptic.impactOccurred() }
    }

    @discardableResult
    private func send(_ payload: [String: Any]) -> Bool {
        guard status == .connected,
              let socket,
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else {
            if !isBusy { reconnectIfNeeded() }
            return false
        }
        socket.send(.string(text)) { [weak self] error in
            guard let error else { return }
            let message = error.localizedDescription
            Task { @MainActor in self?.addLog("Send failed: \(message)") }
        }
        return true
    }

    // MARK: - Helpers

    private func addLog(_ line: String) {
        let time = Date().formatted(date: .omitted, time: .standard)
        log.insert("[\(time)] \(line)", at: 0)
        if log.count > 40 { log.removeLast(log.count - 40) }
    }

    static func isValidIP(_ text: String) -> Bool {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let n = Int(part), (0...255).contains(n), part.count <= 3 else { return false }
            return true
        }
    }
}

/// Accepts the TV's self-signed certificate, but only for the one IP address the user entered.
/// Every other server still gets normal certificate checks.
final class TVSessionDelegate: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
    let trustedHost: String
    let onOpen: @Sendable () -> Void

    init(trustedHost: String, onOpen: @escaping @Sendable () -> Void) {
        self.trustedHost = trustedHost
        self.onOpen = onOpen
    }

    nonisolated func urlSession(_ session: URLSession,
                                didReceive challenge: URLAuthenticationChallenge) async
        -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        let space = challenge.protectionSpace
        guard space.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              space.host == trustedHost,
              let trust = space.serverTrust else {
            return (.performDefaultHandling, nil)
        }
        return (.useCredential, URLCredential(trust: trust))
    }

    nonisolated func urlSession(_ session: URLSession,
                                webSocketTask: URLSessionWebSocketTask,
                                didOpenWithProtocol protocol: String?) {
        onOpen()
    }
}
