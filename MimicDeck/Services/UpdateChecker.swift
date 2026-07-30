// Asks the GitHub releases API whether a newer tag exists.
//
// This is the only thing in the app that touches the network, it is off with
// one switch in Settings, and it never downloads or installs anything. The
// most it does is open the releases page in the user's browser.
//
// The download URL is a compile-time constant rather than the `html_url` from
// the response, so a spoofed or hijacked API can't point the browser
// somewhere else.

import Foundation
import Observation
import os

@MainActor
@Observable
final class UpdateChecker {
    private static let log = Logger(subsystem: "KitsuneLab.AutoClicker", category: "Updates")

    static let enabledDefaultsKey = "checkForUpdates"
    private static let lastCheckDefaultsKey = "UpdateChecker.lastCheck"

    static let releasesPageURL = AppLinks.latestRelease
    private static let apiURL = AppLinks.latestReleaseAPI

    /// A release payload is a couple of kilobytes. Anything wildly bigger is
    /// not something we should be parsing.
    private static let maxResponseBytes = 1_000_000
    private static let checkInterval: TimeInterval = 60 * 60 * 24

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case updateAvailable(version: String)
        case failed(String)
    }

    private(set) var state: State = .idle

    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Self.enabledDefaultsKey) }
    }

    /// The version this build reports, e.g. "1.0.0".
    let currentVersion: String

    private var inFlight: Task<Void, Never>?

    init(currentVersion: String = Bundle.main.shortVersion) {
        self.currentVersion = currentVersion
        // On first launch there is no stored value and `bool(forKey:)` gives
        // false, so opt in explicitly instead.
        if UserDefaults.standard.object(forKey: Self.enabledDefaultsKey) == nil {
            self.isEnabled = true
            UserDefaults.standard.set(true, forKey: Self.enabledDefaultsKey)
        } else {
            self.isEnabled = UserDefaults.standard.bool(forKey: Self.enabledDefaultsKey)
        }
    }

    /// Background check on launch. Does nothing when switched off, and at most
    /// once a day otherwise.
    func checkIfDue() {
        guard isEnabled else { return }
        let last = UserDefaults.standard.object(forKey: Self.lastCheckDefaultsKey) as? Date
        if let last, Date().timeIntervalSince(last) < Self.checkInterval { return }
        check()
    }

    /// Explicit "Check now". Runs even if the daily check already happened.
    func check() {
        guard inFlight == nil else { return }
        state = .checking
        inFlight = Task { [weak self] in
            guard let self else { return }
            defer { self.inFlight = nil }
            do {
                let latest = try await Self.fetchLatestVersion()
                UserDefaults.standard.set(Date(), forKey: Self.lastCheckDefaultsKey)
                state = Self.isNewer(latest, than: currentVersion)
                    ? .updateAvailable(version: latest)
                    : .upToDate
                Self.log.info("Update check: latest \(latest, privacy: .public)")
            } catch is CancellationError {
                state = .idle
            } catch {
                Self.log.error("Update check failed: \(error.localizedDescription, privacy: .public)")
                state = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - Networking

    private struct Release: Decodable {
        let tagName: String
        enum CodingKeys: String, CodingKey { case tagName = "tag_name" }
    }

    private static func fetchLatestVersion() async throws -> String {
        var request = URLRequest(url: apiURL)
        request.timeoutInterval = 15
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("AutoClicker", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw UpdateError.badResponse(status: code)
        }
        guard data.count <= maxResponseBytes else { throw UpdateError.responseTooLarge }
        return try JSONDecoder().decode(Release.self, from: data).tagName
    }

    enum UpdateError: LocalizedError {
        case badResponse(status: Int)
        case responseTooLarge

        var errorDescription: String? {
            switch self {
            case .badResponse(let status) where status == 404:
                "No published release yet."
            case .badResponse(let status):
                "GitHub answered with status \(status)."
            case .responseTooLarge:
                "That response was far bigger than a release should be."
            }
        }
    }

    // MARK: - Version comparison

    /// Numeric compare on the dotted components, so 1.10.0 beats 1.9.0 the way
    /// a plain string compare would not. A leading "v" is tolerated because
    /// tags usually carry one. Anything unparseable counts as not newer.
    nonisolated static func isNewer(_ candidate: String, than current: String) -> Bool {
        let lhs = components(of: candidate)
        let rhs = components(of: current)
        guard !lhs.isEmpty, !rhs.isEmpty else { return false }

        for index in 0..<max(lhs.count, rhs.count) {
            let a = index < lhs.count ? lhs[index] : 0
            let b = index < rhs.count ? rhs[index] : 0
            if a != b { return a > b }
        }
        return false
    }

    private nonisolated static func components(of version: String) -> [Int] {
        version
            .trimmingCharacters(in: .whitespaces)
            .drop { $0 == "v" || $0 == "V" }
            .split(separator: ".")
            .map { part in Int(part.prefix { $0.isNumber }) ?? 0 }
    }
}

extension Bundle {
    var shortVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
    }
}
