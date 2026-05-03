import Foundation
import Testing
@testable import Hoibe

@Suite("AnalysisResult JSON Parsing")
struct ResultParsingTests {

    @Test("Decode positive fixture JSON")
    func decodePositiveFixture() throws {
        let json = """
        {
            "first_sip_detected": true,
            "confidence": 0.95,
            "reason_short": "Glass tilted with lip contact and motion detected.",
            "face_visible": true,
            "drinking_object_visible": true,
            "mouth_contact_likely": true,
            "beer_likely": "true",
            "beer_fill_level": "full",
            "model_name": "qwen3-vl:4b",
            "analysis_version": "v3",
            "analyzed_at": "2026-05-03T12:00:00Z",
            "source_video": "positive_first-sip_001.mp4"
        }
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(AnalysisResult.self, from: json)
        #expect(result.firstSipDetected == true)
        #expect(result.confidence == 0.95)
        #expect(result.beerFillLevel == .full)
    }

    @Test("Decode negative fixture JSON")
    func decodeNegativeFixture() throws {
        let json = """
        {
            "first_sip_detected": false,
            "confidence": 0.10,
            "reason_short": "No drinking motion detected.",
            "face_visible": true,
            "drinking_object_visible": true,
            "mouth_contact_likely": false,
            "beer_likely": "true",
            "beer_fill_level": "full",
            "model_name": "qwen3-vl:4b",
            "analysis_version": "v3",
            "analyzed_at": null,
            "source_video": null
        }
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(AnalysisResult.self, from: json)
        #expect(result.firstSipDetected == false)
        #expect(result.confidence <= 0.3)
    }

    @Test("BeerFillLevel decoding")
    func decodeFillLevels() throws {
        let cases: [(String, BeerFillLevel)] = [
            ("\"full\"", .full),
            ("\"mostly_full\"", .mostlyFull),
            ("\"half\"", .half),
            ("\"mostly_empty\"", .mostlyEmpty),
            ("\"empty\"", .empty),
            ("\"unknown\"", .unknown),
        ]
        for (json, expected) in cases {
            let decoded = try JSONDecoder().decode(BeerFillLevel.self, from: json.data(using: .utf8)!)
            #expect(decoded == expected)
        }
    }
}
