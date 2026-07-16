import Foundation
import SwiftData

enum ModelContainerFactory {
    static func make(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([PersistedEvent.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
