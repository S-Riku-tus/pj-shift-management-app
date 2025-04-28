import SwiftUI

@main
struct ShiftManagementAppApp: App {
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

// Core Data用のPersistenceController
struct PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init() {
        container = NSPersistentContainer(name: "ShiftManagementApp")
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Dataストアのロードに失敗: \(error.localizedDescription)")
            }
        }
    }
}