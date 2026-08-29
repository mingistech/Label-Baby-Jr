#if os(macOS)
import AppKit
import Combine
import Foundation

@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published private(set) var isChecking = false

    private let latestReleaseURL = URL(string: "https://api.github.com/repos/mingistech/Label-Baby-Jr/releases/latest")!
    private let automaticCheckInterval: TimeInterval = 14 * 24 * 60 * 60
    private let lastAutomaticCheckDateKey = "lastAutomaticUpdateCheckDate"

    private init() {}

    func checkForUpdates() async {
        await performCheck(showFeedback: true)
    }

    func checkForUpdatesIfDue() async {
        guard !isChecking,
              isAutomaticCheckDue else {
            return
        }

        await performCheck(showFeedback: false)
    }

    private var isAutomaticCheckDue: Bool {
        guard let lastCheckDate = UserDefaults.standard.object(forKey: lastAutomaticCheckDateKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastCheckDate) >= automaticCheckInterval
    }

    private func performCheck(showFeedback: Bool) async {
        guard !isChecking else { return }

        isChecking = true
        defer { isChecking = false }

        do {
            let release = try await fetchLatestRelease()
            let installedVersion = try AppVersion.current
            let releaseVersion = try AppVersion(release.tagName)
            UserDefaults.standard.set(Date(), forKey: lastAutomaticCheckDateKey)

            if releaseVersion > installedVersion {
                showUpdateAvailable(release: release, version: releaseVersion.description)
            } else if showFeedback {
                showUpToDate(installedVersion: installedVersion.description)
            }
        } catch UpdateCheckError.noPublishedRelease {
            guard showFeedback else { return }
            showAlert(
                title: "No Updates Published Yet",
                message: "There are no published releases for Label Baby Jr on GitHub."
            )
        } catch UpdateCheckError.invalidReleaseVersion(let tag) {
            guard showFeedback else { return }
            showAlert(
                title: "Couldn’t Check for Updates",
                message: "The latest GitHub release tag \"\(tag)\" is not a supported version number. Use tags such as v1.3.0."
            )
        } catch {
            guard showFeedback else { return }
            showAlert(
                title: "Couldn’t Check for Updates",
                message: "Label Baby Jr couldn’t contact GitHub. Check your internet connection and try again."
            )
        }
    }

    private func fetchLatestRelease() async throws -> GitHubRelease {
        var request = URLRequest(url: latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Label-Baby-Jr", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UpdateCheckError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            throw UpdateCheckError.noPublishedRelease
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw UpdateCheckError.invalidResponse
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        guard release.htmlURL.scheme == "https", release.htmlURL.host == "github.com" else {
            throw UpdateCheckError.invalidResponse
        }
        return release
    }

    private func showUpdateAvailable(release: GitHubRelease, version: String) {
        let alert = NSAlert()
        alert.messageText = "Version \(version) Is Available"
        alert.informativeText = "You’re using version \(AppVersion.currentVersionString). Open the GitHub release page to download the update."
        alert.addButton(withTitle: "View Release")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(release.htmlURL)
        }
    }

    private func showUpToDate(installedVersion: String) {
        showAlert(
            title: "You’re Up to Date",
            message: "Label Baby Jr \(installedVersion) is the latest published version."
        )
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: URL

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}

private enum UpdateCheckError: Error {
    case invalidReleaseVersion(String)
    case invalidResponse
    case noPublishedRelease
}

private struct AppVersion: Comparable, CustomStringConvertible {
    let components: [Int]

    static var current: AppVersion {
        get throws {
            try AppVersion(currentVersionString)
        }
    }

    static var currentVersionString: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    init(_ string: String) throws {
        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let versionString = trimmedString.hasPrefix("v") || trimmedString.hasPrefix("V")
            ? String(trimmedString.dropFirst())
            : trimmedString
        let parts = versionString.split(separator: ".", omittingEmptySubsequences: false)

        guard !parts.isEmpty,
              parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) else {
            throw UpdateCheckError.invalidReleaseVersion(string)
        }

        let parsedComponents = parts.compactMap { Int($0) }
        guard parsedComponents.count == parts.count else {
            throw UpdateCheckError.invalidReleaseVersion(string)
        }

        components = parsedComponents
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let componentCount = max(lhs.components.count, rhs.components.count)
        for index in 0..<componentCount {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }

    var description: String {
        components.map(String.init).joined(separator: ".")
    }
}
#endif
