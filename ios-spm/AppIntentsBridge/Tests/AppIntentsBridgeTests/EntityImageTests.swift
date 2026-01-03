import Testing
import Foundation
@testable import AppIntentsBridge

@Suite("EntityImageSource Tests")
struct EntityImageTests {

    @Test("URL image source stores correct URL")
    func urlImageSource() {
        let url = URL(string: "https://example.com/image.png")!
        let source = EntityImageSource.url(url)

        if case .url(let storedURL) = source {
            #expect(storedURL == url)
        } else {
            Issue.record("Expected URL source")
        }
    }

    @Test("Asset image source stores correct asset name")
    func assetImageSource() {
        let assetName = "my_image"
        let source = EntityImageSource.asset(assetName)

        if case .asset(let storedName) = source {
            #expect(storedName == assetName)
        } else {
            Issue.record("Expected asset source")
        }
    }

    @Test("SF Symbol image source stores correct symbol name")
    func sfSymbolImageSource() {
        let symbolName = "star.fill"
        let source = EntityImageSource.sfSymbol(symbolName)

        if case .sfSymbol(let storedName) = source {
            #expect(storedName == symbolName)
        } else {
            Issue.record("Expected SF Symbol source")
        }
    }

    @Test("EntityImageSource equality for URL")
    func urlEquality() {
        let url = URL(string: "https://example.com/test.png")!
        let source1 = EntityImageSource.url(url)
        let source2 = EntityImageSource.url(url)
        #expect(source1 == source2)
    }

    @Test("EntityImageSource equality for asset")
    func assetEquality() {
        let source1 = EntityImageSource.asset("test_asset")
        let source2 = EntityImageSource.asset("test_asset")
        #expect(source1 == source2)
    }

    @Test("EntityImageSource equality for SF Symbol")
    func sfSymbolEquality() {
        let source1 = EntityImageSource.sfSymbol("star")
        let source2 = EntityImageSource.sfSymbol("star")
        #expect(source1 == source2)
    }

    @Test("EntityImageSource inequality between different types")
    func differentTypesInequality() {
        let url = URL(string: "https://example.com/star.png")!
        let urlSource = EntityImageSource.url(url)
        let assetSource = EntityImageSource.asset("star")
        let symbolSource = EntityImageSource.sfSymbol("star")

        #expect(urlSource != assetSource)
        #expect(assetSource != symbolSource)
        #expect(urlSource != symbolSource)
    }
}
