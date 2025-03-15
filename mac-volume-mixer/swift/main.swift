import Foundation

print("Mac Volume Mixer Audio Service Starting")

// Define an actor to encapsulate the AudioServer logic
actor AudioServer {
    func start() async throws {
        // Simulate server startup logic
        print("Starting server...")
        try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate work
        print("Server startup logic completed")
    }
}

// Create and start the server
let server = AudioServer()

Task {
    do {
        // Access the actor's method using 'await'
        try await server.start()
        print("Server started successfully")
    } catch {
        print("Failed to start server: \(error)")
        exit(1)
    }
}

// Keep the application running
RunLoop.main.run()
