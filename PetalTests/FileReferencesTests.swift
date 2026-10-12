import XCTest
@testable import PetalCore

final class FileReferencesTests: XCTestCase {
    func testFindsBareAbsolutePathsIncludingInCode() {
        let text = "I saved it to /home/aadhil/reports/q3.pdf. Chart: `/tmp/chart.png` and ~/out/data.csv, done."
        XCTAssertEqual(FileReferences.extract(from: text).map(\.path), ["/home/aadhil/reports/q3.pdf", "/tmp/chart.png", "~/out/data.csv"])
    }

    func testIgnoresURLsRelativePathsAndRoutes() {
        let text = "See https://example.com/files/a.pdf, file:///tmp/x.pdf, out/a.pdf, ./b.txt, /api/files/download and /v1.2"
        XCTAssertTrue(FileReferences.extract(from: text).isEmpty)
    }

    func testMediaDirectivesAreFoundOnceAndHiddenFromText() {
        let text = "Here is your report.\nMEDIA:/tmp/report.xlsx\nAlso /tmp/report.xlsx"
        XCTAssertEqual(FileReferences.extract(from: text).map(\.path), ["/tmp/report.xlsx"])
        XCTAssertEqual(FileReferences.stripMediaDirectives(text), "Here is your report.\nAlso /tmp/report.xlsx")
        XCTAssertEqual(FileReferences.stripMediaDirectives("Open MEDIA:/tmp/a.pdf. Then"), "Open. Then")
    }

    func testMultiPartExtensionsAndBoldPaths() {
        XCTAssertEqual(FileReferences.extract(from: "**/tmp/archive.tar.gz** is ready").map(\.path), ["/tmp/archive.tar.gz"])
    }

    func testKindAndName() {
        let reference = FileReference(path: "/srv/out/Slides.PPTX")
        XCTAssertEqual(reference.name, "Slides.PPTX")
        XCTAssertEqual(reference.kind, .presentation)
        XCTAssertEqual(FileReference(path: "/tmp/a.heic").kind, .image)
    }

    func testCapsTheNumberOfFiles() {
        let text = (1...20).map { "/tmp/f\($0).txt" }.joined(separator: " ")
        XCTAssertEqual(FileReferences.extract(from: text).count, FileReferences.maximumCount)
    }
}
