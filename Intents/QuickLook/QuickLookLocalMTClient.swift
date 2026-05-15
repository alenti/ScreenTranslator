import Foundation

struct QuickLookMTRequest: Encodable {
    let sourceLang: String
    let targetLang: String
    let blocks: [QuickLookMTBlock]
}

struct QuickLookMTBlock: Codable, Equatable {
    let id: String
    let text: String
    let kind: String
}

struct QuickLookMTResponse: Decodable, Equatable {
    let provider: String
    let translations: [QuickLookMTTranslation]
    let totalLatencyMs: Int?
}

struct QuickLookMTTranslation: Decodable, Equatable {
    let id: String
    let sourceText: String
    let translatedText: String
    let latencyMs: Int?
}

struct QuickLookMTHealthResponse: Decodable, Equatable {
    let ok: Bool?
    let provider: String?
    let modelPath: String?
    let tokenizer: String?
    let device: String?
    let computeType: String?
    let error: String?
}

enum QuickLookLocalMTClientError: Error, LocalizedError, Equatable {
    case invalidResponse
    case httpStatus(Int)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Local MT server returned an invalid response."
        case .httpStatus(let statusCode):
            return "Local MT server returned HTTP \(statusCode)."
        case .emptyResponse:
            return "Local MT server returned no translations."
        }
    }
}

struct QuickLookLocalMTClient {
    private let baseURL: URL
    private let timeout: TimeInterval
    private let session: URLSession

    var baseURLString: String {
        baseURL.absoluteString
    }

    var endpointURLString: String {
        baseURL.appendingPathComponent("translateBlocks").absoluteString
    }

    init(
        baseURL: URL = QuickLookLocalMTConfig.baseURL,
        timeout: TimeInterval = QuickLookLocalMTConfig.requestTimeout,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.timeout = timeout
        self.session = session
    }

    func translateBlocks(
        _ blocks: [QuickLookMTBlock],
        sourceLanguage: String = "zh",
        targetLanguage: String = "en"
    ) async throws -> QuickLookMTResponse {
        guard blocks.isEmpty == false else {
            return QuickLookMTResponse(
                provider: "opus-mt-ct2",
                translations: [],
                totalLatencyMs: 0
            )
        }

        let endpoint = baseURL.appendingPathComponent("translateBlocks")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(
            QuickLookMTRequest(
                sourceLang: sourceLanguage,
                targetLang: targetLanguage,
                blocks: blocks
            )
        )

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuickLookLocalMTClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw QuickLookLocalMTClientError.httpStatus(httpResponse.statusCode)
        }

        let decodedResponse = try JSONDecoder().decode(
            QuickLookMTResponse.self,
            from: data
        )

        guard decodedResponse.translations.isEmpty == false else {
            throw QuickLookLocalMTClientError.emptyResponse
        }

        return decodedResponse
    }

    func checkHealth(
        timeout: TimeInterval = 5
    ) async throws -> QuickLookMTHealthResponse {
        let endpoint = baseURL.appendingPathComponent("health")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuickLookLocalMTClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw QuickLookLocalMTClientError.httpStatus(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(
            QuickLookMTHealthResponse.self,
            from: data
        )
    }
}
