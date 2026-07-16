@testable import Rogers_Event_Assignment
import Testing

struct LoadStateTests {
    @Test func currentValueReturnsMostRecentKnownValue() {
        #expect(LoadState<Int>.idle.currentValue == nil)
        #expect(LoadState<Int>.loading(previous: 5).currentValue == 5)
        #expect(LoadState<Int>.loading(previous: nil).currentValue == nil)
        #expect(LoadState<Int>.loaded(7).currentValue == 7)
        #expect(LoadState<Int>.failed(.network, previous: 3).currentValue == 3)
        #expect(LoadState<Int>.failed(.network, previous: nil).currentValue == nil)
    }

    @Test func isLoadingOnlyTrueForLoadingCase() {
        #expect(LoadState<Int>.loading(previous: nil).isLoading)
        #expect(!LoadState<Int>.loaded(1).isLoading)
        #expect(!LoadState<Int>.idle.isLoading)
        #expect(!LoadState<Int>.failed(.network, previous: nil).isLoading)
    }

    @Test func equatableDistinguishesPreviousValuesAndErrors() {
        #expect(LoadState<Int>.loading(previous: 1) != LoadState<Int>.loading(previous: 2))
        #expect(LoadState<Int>.failed(.network, previous: 1) == LoadState<Int>.failed(.network, previous: 1))
        #expect(LoadState<Int>.failed(.network, previous: 1) != LoadState<Int>.failed(.unauthorized, previous: 1))
    }
}
