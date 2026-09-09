import SwiftUI
import UIKit

/// Downloads a team's logo once, extracts its dominant color, and memoizes the
/// result for the process lifetime. Never re-samples per render.
@MainActor
@Observable
final class TeamColorStore {
    static let shared = TeamColorStore()

    private var cache: [Int: HSLColor?] = [:]
    private var inflight: [Int: Task<HSLColor?, Never>] = [:]

    /// Returns the extracted color for a team, or nil if there is no logo or
    /// nothing survives extraction. Concurrent calls for the same id coalesce.
    func color(forTeamId id: Int?, logoURL: String?) async -> HSLColor? {
        guard let id else { return nil }
        if let cached = cache[id] { return cached }
        if let task = inflight[id] { return await task.value }

        let task = Task<HSLColor?, Never> { [logoURL] in
            guard let logoURL, let url = URL(string: logoURL) else { return nil }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else { return nil }
                return TeamColorExtractor.extractDominant(image)
            } catch {
                return nil
            }
        }
        inflight[id] = task
        let result = await task.value
        cache[id] = result
        inflight[id] = nil
        return result
    }
}
