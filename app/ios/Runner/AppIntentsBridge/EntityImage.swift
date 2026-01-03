// COPIED FROM ios-spm/AppIntentsBridge
// Local copy for Example App integration

import Foundation

/// Represents the source of an entity image for App Intents
public enum EntityImageSource: Equatable, Sendable {
    /// Image loaded from a remote URL
    case url(URL)
    /// Image loaded from an asset bundle
    case asset(String)
    /// Image using an SF Symbol
    case sfSymbol(String)
}
