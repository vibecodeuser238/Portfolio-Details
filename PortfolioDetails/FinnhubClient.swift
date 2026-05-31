import Foundation

struct FinnhubClient {
    enum FinnhubError: LocalizedError {
        case missingAPIKey
        case badResponse
        case invalidKey

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: "Add a Finnhub API key in Settings."
            case .badResponse: "Finnhub returned an unexpected response."
            case .invalidKey: "Finnhub rejected this API key."
            }
        }
    }

    var apiKey: String?
    var session: URLSession = .shared

    func validateKey() async throws -> Bool {
        let quote = try await quote(for: "AAPL")
        return quote.current > 0
    }

    func quote(for symbol: String) async throws -> FinnhubQuote {
        try await get("/quote", query: ["symbol": symbol])
    }

    func profile(for symbol: String) async throws -> FinnhubProfile {
        try await get("/stock/profile2", query: ["symbol": symbol])
    }

    func metrics(for symbol: String) async throws -> FinnhubMetricResponse {
        try await get("/stock/metric", query: ["symbol": symbol, "metric": "all"])
    }

    private func get<T: Decodable>(_ path: String, query: [String: String]) async throws -> T {
        guard let apiKey, !apiKey.isEmpty else { throw FinnhubError.missingAPIKey }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "finnhub.io"
        components.path = "/api/v1" + path
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw FinnhubError.badResponse }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Finnhub-Token")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw FinnhubError.badResponse }
        if httpResponse.statusCode == 401 { throw FinnhubError.invalidKey }
        guard 200..<300 ~= httpResponse.statusCode else { throw FinnhubError.badResponse }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

