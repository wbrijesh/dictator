//
//  TranscriptionService.swift
//  Dictator
//
//  Created by Brijesh Wawdhane on 25/08/25.
//

import Foundation

class TranscriptionService {
    private let apiURL = "https://api.openai.com/v1/audio/transcriptions"
    private let model = "gpt-4o-transcribe"
    
    enum TranscriptionError: Error {
        case noAPIKey
        case invalidResponse
        case networkError(Error)
        case apiError(String)
    }
    
    func transcribe(audioURL: URL, completion: @escaping (Result<String, TranscriptionError>) -> Void) {
        guard let apiKey = getAPIKey() else {
            completion(.failure(.noAPIKey))
            return
        }
        
        // Create multipart form data request
        let request = createMultipartRequest(audioURL: audioURL, apiKey: apiKey)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }
            
            // Parse response
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let text = json["text"] as? String {
                        completion(.success(text))
                    } else if let error = json["error"] as? [String: Any],
                              let message = error["message"] as? String {
                        completion(.failure(.apiError(message)))
                    } else {
                        completion(.failure(.invalidResponse))
                    }
                } else {
                    completion(.failure(.invalidResponse))
                }
            } catch {
                completion(.failure(.networkError(error)))
            }
        }.resume()
    }
    
    private func createMultipartRequest(audioURL: URL, apiKey: String) -> URLRequest {
        var request = URLRequest(url: URL(string: apiURL)!)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let httpBody = createMultipartBody(audioURL: audioURL, boundary: boundary)
        request.httpBody = httpBody
        
        return request
    }
    
    private func createMultipartBody(audioURL: URL, boundary: String) -> Data {
        var body = Data()
        
        // Add model parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)
        
        // Add response_format parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json\r\n".data(using: .utf8)!)
        
        // Add audio file
        if let audioData = try? Data(contentsOf: audioURL) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
            body.append(audioData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
    
    private func getAPIKey() -> String? {
        // First try to get from Keychain
        if let keychainKey = KeychainHelper.getAPIKey() {
            return keychainKey
        }
        
        // Fallback to environment variable for development
        return ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
    }
}
