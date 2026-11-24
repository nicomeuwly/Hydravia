import Testing
@testable import HydraviaCore

@Suite("BlockSelectionSize")
struct BlockSelectionSizeTests {
    @Test func everythingAsCategoriesFits() {
        // "All apps & categories": about a dozen category tokens.
        let size = BlockSelectionSize(apps: 0, categories: 13, webDomains: 0)
        #expect(size.isEnforceable)
        #expect(size.overflow == nil)
        #expect(!size.isEmpty)
    }

    @Test func fiftyAppsIsTheLastPickThatFits() {
        #expect(BlockSelectionSize(apps: 50, categories: 0, webDomains: 0).isEnforceable)
        #expect(BlockSelectionSize(apps: 50, categories: 50, webDomains: 50).isEnforceable)
        #expect(BlockSelectionSize(apps: 51, categories: 0, webDomains: 0).overflow == .apps)
    }

    @Test func categoriesSplitIntoAppsOverflow() {
        // One app unchecked inside a selected category: the rest of it
        // comes back as single apps.
        let size = BlockSelectionSize(apps: 94, categories: 11, webDomains: 0)
        #expect(!size.isEnforceable)
        #expect(size.overflow == .apps)
    }

    @Test func tooManyWebsitesOrCategoriesOverflowToo() {
        #expect(BlockSelectionSize(apps: 3, categories: 0, webDomains: 51).overflow == .webDomains)
        #expect(BlockSelectionSize(apps: 0, categories: 51, webDomains: 0).overflow == .categories)
        // Apps are reported first: they are what the picker inflates.
        #expect(BlockSelectionSize(apps: 60, categories: 0, webDomains: 60).overflow == .apps)
    }

    @Test func anEmptyPickIsEmptyAndFits() {
        let size = BlockSelectionSize(apps: 0, categories: 0, webDomains: 0)
        #expect(size.isEmpty)
        #expect(size.isEnforceable)
    }
}
