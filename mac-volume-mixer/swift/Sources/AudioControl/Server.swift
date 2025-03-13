import Foundation
import NIO
import NIOHTTP1
import NIOExtras

class AudioServer {
    private let controller = AudioController()
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    private var channel: Channel?
    
    func start(host: String = "127.0.0.1", port: Int = 8080) throws {
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(HTTPHandler(controller: self.controller))
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
        
        channel = try bootstrap.bind(host: host, port: port).wait()
        
        if let localAddress = channel?.localAddress {
            print("Server started and listening on \(localAddress)")
        }
    }
    
    func stop() {
        do {
            try channel?.close().wait()
            try group.syncShutdownGracefully()
        } catch {
            print("Error shutting down server: \(error)")
        }
    }
}

// HTTP Request Handler
private class HTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    private let controller: AudioController
    private var requestBody: ByteBuffer?
    
    init(controller: AudioController) {
        self.controller = controller
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = self.unwrapInboundIn(data)
        
        switch reqPart {
        case .head(let request):
            // Process based on URL path
            switch request.uri {
            case "/apps":
                if request.method == .GET {
                    handleGetApps(context: context)
                } else {
                    sendResponse(context: context, status: .methodNotAllowed)
                }
                
            case "/volume":
                if request.method == .POST {
                    // Will accumulate body data
                    requestBody = context.channel.allocator.buffer(capacity: 0)
                } else {
                    sendResponse(context: context, status: .methodNotAllowed)
                }
                
            default:
                sendResponse(context: context, status: .notFound)
            }
            
        case .body(var buffer):
            if request.uri == "/volume" {
                if var body = requestBody {
                    body.writeBuffer(&buffer)
                    requestBody = body
                }
            }
            
        case .end:
            if request.uri == "/volume" {
                handleSetVolume(context: context, body: requestBody)
            }
        }
    }
    
    // Handle GET /apps
    private func handleGetApps(context: ChannelHandlerContext) {
        do {
            let apps = try controller.getAudioApps()
            let jsonData = try JSONEncoder().encode(apps)
            
            var buffer = context.channel.allocator.buffer(capacity: jsonData.count)
            buffer.writeBytes(jsonData)
            
            var headers = HTTPHeaders()
            headers.add(name: "Content-Type", value: "application/json")
            headers.add(name: "Content-Length", value: "\(buffer.readableBytes)")
            
            let responseHead = HTTPResponseHead(version: .http1_1, status: .ok, headers: headers)
            context.write(self.wrapOutboundOut(.head(responseHead))).cascadeFailure(to: context)
            context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer)))).cascadeFailure(to: context)
            context.writeAndFlush(self.wrapOutboundOut(.end(nil))).cascadeFailure(to: context)
        } catch {
            sendResponse(context: context, status: .internalServerError)
        }
    }
    
    // Handle POST /volume
    private func handleSetVolume(context: ChannelHandlerContext, body: ByteBuffer?) {
        guard let body = body else {
            sendResponse(context: context, status: .badRequest)
            return
        }
        
        do {
            // Parse request body
            let data = Data(buffer.readableBytesView)
            let request = try JSONDecoder().decode(VolumeRequest.self, from: data)
            
            // Set the volume
            try controller.setAppVolume(pid: request.pid, volume: request.volume)
            
            sendResponse(context: context, status: .ok)
        } catch {
            sendResponse(context: context, status: .badRequest)
        }
    }
    
    // Helper to send response
    private func sendResponse(context: ChannelHandlerContext, status: HTTPResponseStatus, body: String? = nil) {
        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "text/plain")
        
        if let body = body {
            headers.add(name: "Content-Length", value: "\(body.utf8.count)")
        } else {
            headers.add(name: "Content-Length", value: "0")
        }
        
        let responseHead = HTTPResponseHead(version: .http1_1, status: status, headers: headers)
        context.write(self.wrapOutboundOut(.head(responseHead))).cascadeFailure(to: context)
        
        if let body = body {
            var buffer = context.channel.allocator.buffer(capacity: body.utf8.count)
            buffer.writeString(body)
            context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer)))).cascadeFailure(to: context)
        }
        
        context.writeAndFlush(self.wrapOutboundOut(.end(nil))).cascadeFailure(to: context)
    }
}

// Request structure for volume change
struct VolumeRequest: Codable {
    let pid: Int
    let volume: Float
}