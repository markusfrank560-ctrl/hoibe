import Foundation

// When building with Xcode native target (not SPM), Bundle.module doesn't exist.
// This extension provides compatibility so PromptEngine.swift works in both contexts.
#if !SWIFT_PACKAGE
private class BundleFinder {}

extension Bundle {
    static var module: Bundle {
        Bundle(for: BundleFinder.self)
    }
}
#endif
