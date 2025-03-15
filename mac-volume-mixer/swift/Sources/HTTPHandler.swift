import Foundation
import NIO
import NIOHTTP1

private class HTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let controller: AudioController
    private var requestBody: ByteBuffer?
    private var currentRequest: HTTPRequestHead?

    init(controller: AudioController) {
        self.controller = controller
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = self.unwrapInboundIn(data)

        switch reqPart {
        case .head(let request):
            currentRequest = request
            requestBody = (request.method == .POST) ? context.channel.allocator.buffer(capacity: 0) : nil

        case .body(var buffer):
            requestBody?.writeBuffer(&buffer)

        case .end:
            guard let request = currentRequest else {
                sendResponse(context: context, status: .internalServerError)
                return
            }

            Task {
                switch request.uri {
                case "/apps" where request.method == .GET:
                    await handleGetApps(context: context)
                case "/volume" where request.method == .POST:
                    if let body = requestBody {
                        await handleSetVolume(context: context, body: body)
                    } else {
                        sendResponse(context: context, status: .badRequest)
                    }
                case "/devices" where request.method == .GET:
                    await handleGetDevices(context: context)
                default:
                    sendResponse(context: context, status: .notFound)
                }
            }
        }
    }

    private func handleGetApps(context: ChannelHandlerContext) async {
        do {
            let apps = try await controller.getAudioApps()
            sendJSONResponse(context: context, status: .ok, data: apps)
        } catch {
            sendResponse(context: context, status: .internalServerError, body: "Error: \(error)")
        }
    }

    private func handleGetDevices(context: ChannelHandlerContext) async {
        do {
            let devices = await controller.listAudioDevices()
            sendJSONResponse(context: context, status: .ok, data: devices)
        } catch {
            sendResponse(context: context, status: .internalServerError, body: "Error: \(error)")
        }
    }

    private func handleSetVolume(context: ChannelHandlerContext, body: ByteBuffer) async {
        struct VolumeRequest: Codable {
            let pid: Int
            let volume: Float
        }

        do {
            var buffer = body
            if let byteArray = buffer.readBytes(length: buffer.readableBytes) {
                let data = Data(byteArray)
                let request = try JSONDecoder().decode(VolumeRequest.self, from: data)
                let success = try await controller.setAppVolume(pid: request.pid, volume: request.volume)

                success ? sendResponse(context: context, status: .ok) : sendResponse(context: context, status: .internalServerError, body: "Failed to set volume")
            } else {
                sendResponse(context: context, status: .badRequest, body: "Invalid request body")
            }
        } catch {
            sendResponse(context: context, status: .badRequest, body: "Error: \(error)")
        }
    }

    private func sendJSONResponse<T: Encodable>(context: ChannelHandlerContext, status: HTTPResponseStatus, data: T) {
        do {
            let jsonData = try JSONEncoder().encode(data)
            var buffer = context.channel.allocator.buffer(capacity: jsonData.count)
            buffer.writeBytes(jsonData)

            var headers = HTTPHeaders()
            headers.add(name: "Content-Type", value: "application/json")
            headers.add(name: "Content-Length", value: "\(buffer.readableBytes)")

            let responseHead = HTTPResponseHead(version: .http1_1, status: status, headers: headers)
            context.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)
            context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
        } catch {
            sendResponse(context: context, status: .internalServerError, body: "JSON encoding error: \(error)")
        }
    }

    private func sendResponse(context: ChannelHandlerContext, status: HTTPResponseStatus, body: String? = nil) {
        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "text/plain")
        let responseHead = HTTPResponseHead(version: .http1_1, status: status, headers: headers)

        context.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)

        if let body = body {
            var buffer = context.channel.allocator.buffer(capacity: body.utf8.count)
            buffer.writeString(body)
            context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        }

        context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
    }
}