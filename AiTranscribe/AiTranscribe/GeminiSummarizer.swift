/*
 GeminiSummarizer.swift
 ======================

 Generates the session summary by sending the (already local) transcript text
 to Google's Gemini Generative Language REST API via URLSession — no SDK.

 Privacy: only the text transcript is sent. Audio never leaves the Mac
 (transcription is done locally by whisper.cpp).

 The API key is supplied by the user and stored in the macOS Keychain
 (see KeychainStore). If no key is set, summarization is skipped gracefully.
 */

import Foundation

enum GeminiSummarizer {
    /// Model name — change here to use a different Gemini model.
    static let model = "gemini-2.5-flash"

    /// Keychain account under which the user's API key is stored.
    static let apiKeyAccount = "GeminiAPIKey"

    enum SummaryError: LocalizedError {
        case noAPIKey
        case emptyTranscript
        case http(status: Int, serverMessage: String?)
        case network(String)
        case badResponse

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "No Gemini API key set"
            case .emptyTranscript: return "Transcript was empty"
            case .http(let status, let serverMessage):
                // Prefer Google's own message when present — it's the clearest
                // (e.g. "API key has been suspended", "API not enabled").
                if let serverMessage, !serverMessage.isEmpty {
                    return "Gemini: \(serverMessage)"
                }
                switch status {
                case 400: return "Gemini rejected the request (check the API key)"
                case 401, 403: return "Gemini API key is invalid or unauthorized"
                case 429: return "Gemini rate limit reached — try again later"
                default: return "Gemini API error (HTTP \(status))"
                }
            case .network(let msg): return "Network error: \(msg)"
            case .badResponse: return "Unexpected response from Gemini"
            }
        }
    }

    static var hasAPIKey: Bool {
        (KeychainStore.get(apiKeyAccount)?.isEmpty == false)
    }

    private static let prompt = """
    You are summarizing a transcript of spoken audio. The transcript may mix \
    Russian and English. Detect the DOMINANT language of the transcript and write \
    your ENTIRE response in that language — including the two section headings \
    (translate the headings; do not leave them in English unless English is the \
    dominant language).

    Return GitHub-flavored Markdown with EXACTLY two level-2 (##) sections and \
    nothing else:
    1. A heading meaning "Summary" in the dominant language, followed by a single \
    tight paragraph capturing what the audio was about.
    2. A heading meaning "Top Insights" in the dominant language, followed by 3 to 7 \
    concise bullet points with the most important takeaways.

    For example, if the dominant language is English use "## Summary" and \
    "## Top Insights"; if it is Russian use "## Краткое содержание" and \
    "## Ключевые выводы".

    Transcript:
    """

    /// Summarize the transcript. Returns the markdown summary text on success.
    static func summarize(transcript: String) async throws -> String {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SummaryError.emptyTranscript }
        guard let key = KeychainStore.get(apiKeyAccount), !key.isEmpty else {
            throw SummaryError.noAPIKey
        }

        guard let url = URL(string:
            "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else {
            throw SummaryError.badResponse
        }

        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt + "\n\n" + trimmed]]]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw SummaryError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else { throw SummaryError.badResponse }
        guard (200...299).contains(http.statusCode) else {
            throw SummaryError.http(status: http.statusCode,
                                    serverMessage: errorMessage(from: data))
        }

        return try parseSummary(from: data)
    }

    /// Extract Google's error message from an error response body, if present.
    private static func errorMessage(from data: Data) -> String? {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let error = root["error"] as? [String: Any],
            let message = error["message"] as? String
        else { return nil }
        return message
    }

    /// Extract the generated text from a generateContent response.
    private static func parseSummary(from data: Data) throws -> String {
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = root["candidates"] as? [[String: Any]],
            let first = candidates.first,
            let content = first["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]]
        else {
            throw SummaryError.badResponse
        }

        let text = parts.compactMap { $0["text"] as? String }.joined()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SummaryError.badResponse }
        return trimmed
    }
}
