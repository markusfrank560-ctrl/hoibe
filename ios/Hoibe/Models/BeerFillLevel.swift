import Foundation

/// Fill level of a beer container as assessed by the VLM.
enum BeerFillLevel: String, Codable, Equatable, Sendable, CaseIterable {
    case full
    case mostlyFull = "mostly_full"
    case half
    case mostlyEmpty = "mostly_empty"
    case empty
    case unknown
}
