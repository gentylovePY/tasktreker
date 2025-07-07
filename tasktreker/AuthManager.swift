import Foundation

class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var showWebView = false
    @Published var error: String?
    
    private let clientId = "131f4ee3e4a3410da7e8af137230c0d2"
    private let clientSecret = "7c42dcaeae384bd7adcfb9b78c2fd070"
    private let redirectURI = "https://oauth.yandex.ru/verification_code"
    

    var authURL: URL? {
        var components = URLComponents(string: "https://oauth.yandex.ru/authorize")
        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "force_confirm", value: "yes")
        ]
        return components?.url
    }
    

    func handleCallback(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            error = "Ошибка авторизации: не получен код"
            return
        }
        exchangeCodeForToken(code: code)
    }
    

    private func exchangeCodeForToken(code: String) {
        isLoading = true
        error = nil
        
        let tokenURL = URL(string: "https://oauth.yandex.ru/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        
        let params = [
            "grant_type": "authorization_code",
            "code": code,
            "client_id": clientId,
            "client_secret": clientSecret
        ]
        
        request.httpBody = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.error = error.localizedDescription
                    return
                }
                
                guard let data = data else {
                    self.error = "Нет данных от сервера"
                    return
                }
                
                do {
                    let json = try JSONDecoder().decode(YandexAuthResponse.self, from: data)
                    self.saveTokens(response: json)
                    self.isAuthenticated = true
                } catch {
                    self.error = "Ошибка обработки токена"
                }
            }
        }.resume()
    }
    
    func fetchUserInfo(completion: @escaping ([String: Any]?, Error?) -> Void) {
        guard let accessToken = KeychainHelper.shared.get("yandexAccessToken") else {
            completion(nil, NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Требуется авторизация"]))
            return
        }
        
        let url = URL(string: "https://api.iot.yandex.net/v1.0/user/info")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("v1", forHTTPHeaderField: "X-API-Version")
        
        print("Sending request to: \(url.absoluteString)")
        print("Headers: \(request.allHTTPHeaderFields ?? [:])")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Request error: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response format")
                completion(nil, NSError(domain: "Auth", code: 500, userInfo: [NSLocalizedDescriptionKey: "Неверный ответ сервера"]))
                return
            }
            
            print("Status code: \(httpResponse.statusCode)")
            print("Response headers: \(httpResponse.allHeaderFields)")
            
            guard let data = data else {
                print("No data received")
                completion(nil, NSError(domain: "Auth", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Нет данных в ответе"]))
                return
            }
            
          
            if let rawResponse = String(data: data, encoding: .utf8) {
                print("Raw response: \(rawResponse)")
            }
            
        
            do {
              
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Successfully parsed as JSON")
                    completion(json, nil)
                    return
                }
                

                if let stringResponse = String(data: data, encoding: .utf8) {
                    print("Response is string: \(stringResponse)")
                    completion(["raw": stringResponse], nil)
                    return
                }
                
        
                completion(nil, NSError(domain: "Auth", code: 500, userInfo: [NSLocalizedDescriptionKey: "Неизвестный формат ответа"]))
                
            } catch {
                print("JSON parsing error: \(error.localizedDescription)")
                completion(nil, error)
            }
        }.resume()
    }
    
    private func saveTokens(response: YandexAuthResponse) {
        KeychainHelper.shared.save(response.access_token, forKey: "yandexAccessToken")
        if let refresh_token = response.refresh_token {
            KeychainHelper.shared.save(refresh_token, forKey: "yandexRefreshToken")
        }
        
        fetchUserInfo { json, error in
            if let error = error {
                print("Ошибка получения информации:", error.localizedDescription)
                return
            }
            
            guard let json = json else {
                print("Данные не получены")
                return
            }
            
            print("Успешно получены данные:")
            dump(json)
        }
        

        func logout() {
            KeychainHelper.shared.delete("yandexAccessToken")
            KeychainHelper.shared.delete("yandexRefreshToken")
            isAuthenticated = false
        }
    }
    
    struct YandexAuthResponse: Codable {
        let access_token: String
        let expires_in: Int
        let refresh_token: String?
        let token_type: String
    }
}
