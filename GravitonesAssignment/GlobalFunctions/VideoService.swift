//
//  VideoService.swift
//  GravitonesAssignment
//

import Foundation

// Videos API. Goes through APIClient so it gets the auth header and
// refresh-on-401 handling for free.
struct VideoService {
    static let shared = VideoService()

    private let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func fetchVideos(page: Int, pageSize: Int) async throws -> VideoPage {
        let (data, http) = try await client.send(
            path: "/api/videos?page=\(page)&pageSize=\(pageSize)", method: "GET"
        )
        try Self.ensureSuccess(http, data)
        let result = try Self.decode(VideoPage.self, from: data)
        #if DEBUG
        print("📹 GET /api/videos page=\(result.page) pageSize=\(result.pageSize) "
              + "total=\(result.total) received=\(result.items.count) "
              + "titles=\(result.items.map(\.title))")
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let items = object["items"] as? [[String: Any]], let first = items.first {
            print("📹 video object fields: \(first.keys.sorted()) — no image/thumbnail field is provided")
        }
        #endif
        return result
    }

    func fetchVideo(id: String) async throws -> Video {
        let (data, http) = try await client.send(path: "/api/videos/\(id)", method: "GET")
        try Self.ensureSuccess(http, data)
        return try Self.decode(VideoEnvelope.self, from: data).video
    }

    private static func ensureSuccess(_ http: HTTPURLResponse, _ data: Data) throws {
        switch http.statusCode {
        case 200...299: return
        case 401:       throw APIError.unauthorized
        case 429:       throw APIError.rateLimited
        default:
            let message = (try? JSONDecoder().decode(APIErrorResponse.self, from: data))?.displayMessage
            throw APIError.server(status: http.statusCode, message: message)
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw APIError.decoding(error) }
    }
}
