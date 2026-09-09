//
//  UploadVariant.swift
//  Brackets
//

import Foundation

/// Sizes CarrierWave stores for each uploaded photo, side by side in the same
/// folder: `small_<file>` (70pt square), `big_<file>` (500pt square) and the
/// untouched original (800pt square).
///
/// The API always hands back the `big_` path. That is the right size for every
/// list, grid and avatar in the app — a 500pt image is already oversampled at the
/// largest of them — but the athlete profile draws its hero full-width, roughly
/// 1130pt on a 3x screen, where 500pt is visibly soft. Only that one view asks
/// for `.original`; everything else stays on what the API sent.
enum UploadVariant {
    /// The path exactly as the API returned it.
    case asSent
    /// The full-resolution upload the versioned files were derived from.
    case original

    private static let versionPrefixes = ["big_", "small_", "thumb_"]

    /// Rewrites an upload path to this variant. Paths that carry no recognised
    /// version prefix are returned untouched, so a differently-stored image can
    /// never resolve to a URL that does not exist.
    func path(_ path: String) -> String {
        guard case .original = self else { return path }

        let file: Substring
        let folder: Substring
        if let slash = path.lastIndex(of: "/") {
            folder = path[...slash]
            file = path[path.index(after: slash)...]
        } else {
            folder = ""
            file = path[...]
        }

        guard let prefix = Self.versionPrefixes.first(where: { file.hasPrefix($0) }) else {
            return path
        }
        return String(folder) + String(file.dropFirst(prefix.count))
    }
}
