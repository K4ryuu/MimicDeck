// Every outbound URL the app knows about, in one place. Hardcoded on purpose:
// nothing here is ever built from a network response, so a spoofed API can't
// send the browser somewhere else.

import Foundation

nonisolated enum AppLinks {
    static let author = "K4ryuu"
    static let repositorySlug = "K4ryuu/MimicDeck"

    static let authorPage = URL(string: "https://github.com/\(author)")!
    static let repository = URL(string: "https://github.com/\(repositorySlug)")!
    static let latestRelease = URL(string: "https://github.com/\(repositorySlug)/releases/latest")!
    static let latestReleaseAPI = URL(string: "https://api.github.com/repos/\(repositorySlug)/releases/latest")!
}
