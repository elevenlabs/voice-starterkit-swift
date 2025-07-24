import Foundation

// Token service for authenticating a conversation with private agents.
// DO NOT use client-side token generation in production.
actor TokenService {
    private let apiKey: String
    private let baseURL = "https://api.us.elevenlabs.io/v1/convai/conversation/token"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func fetchConversationToken(for agentId: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)?agent_id=\(agentId)") else {
            throw TokenServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw TokenServiceError.apiError
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        return tokenResponse.token
    }
}

struct TokenResponse: Codable {
    let token: String
}

enum TokenServiceError: Error {
    case invalidURL
    case apiError
}
