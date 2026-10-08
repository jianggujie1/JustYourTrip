import SwiftUI
import SwiftData

@main
struct JustYourTripApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TripPlan.self,
            TripDay.self,
            RouteNode.self,
            ChecklistItem.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onAppear {
                    // 首次启动时若数据库为空，自动预置精选上海示范路线
                    seedSampleDataIfNeeded()
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    @MainActor
    private func seedSampleDataIfNeeded() {
        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<TripPlan>()
        do {
            let count = try context.fetchCount(descriptor)
            if count == 0 {
                _ = MockData.createSampleTrip(in: context)
            }
        } catch {
            // Ignore error
        }
    }
}
