import Foundation

struct WebRequest: Decodable { let path: String; let cookie: String }
struct WebResponse: Encodable { let status: Int; let retryAfter: String?; let body: String }
@main struct ClaudeWebRequest {
    static func main() async {
        do {
            let input = try JSONDecoder().decode(WebRequest.self, from: FileHandle.standardInput.readDataToEndOfFile())
            guard input.path == "/api/organizations" || input.path.range(of: "^/api/organizations/[a-fA-F0-9-]{36}/usage$", options: .regularExpression) != nil,
                  !input.cookie.contains("\n"), !input.cookie.contains("\r") else { exit(2) }
            var request = URLRequest(url: URL(string: "https://claude.ai" + input.path)!)
            request.timeoutInterval = 15
            request.setValue(input.cookie, forHTTPHeaderField: "Cookie")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("TokenGauge/1.0", forHTTPHeaderField: "User-Agent")
            let config = URLSessionConfiguration.ephemeral
            config.httpShouldSetCookies = false
            let session = URLSession(configuration: config, delegate: RedirectGuard(), delegateQueue: nil)
            defer { session.invalidateAndCancel() }
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, data.count <= 2 * 1024 * 1024 else { exit(3) }
            let output = WebResponse(status: http.statusCode, retryAfter: http.value(forHTTPHeaderField: "Retry-After"), body: String(decoding: data, as: UTF8.self))
            FileHandle.standardOutput.write(try JSONEncoder().encode(output))
        } catch { exit(1) }
    }
}
final class RedirectGuard: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
