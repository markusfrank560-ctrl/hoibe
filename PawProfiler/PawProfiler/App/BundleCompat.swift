#if !SWIFT_PACKAGE
import Foundation

// When building via Xcode project (not SPM), Bundle.module doesn't exist.
// Provide a fallback that points to the main bundle where resources are copied.
private class BundleFinder {}

extension Foundation.Bundle {
    static var module: Bundle {
        Bundle(for: BundleFinder.self)
    }
}
#endif
