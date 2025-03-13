import Foundation

print("Mac Volume Mixer Audio Service Starting")

// Create and start the server
let server = AudioServer()

do {
    try server.start()
    print("Server started successfully")
    
    // Keep the application running
    RunLoop.main.run()
} catch {
    print("Failed to start server: \(error)")
    exit(1)
}