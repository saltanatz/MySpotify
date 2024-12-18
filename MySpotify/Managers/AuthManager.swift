//
//  AuthManager.swift
//  MySpotify
//
//  Created by Saltanat Zarkhinova on 10.12.2024.
//

import Foundation

final class AuthManager {
    static let shared = AuthManager()
    
    private init() {}
    
    struct Constraints {
        static let clientID = "8c030bf456824d5894656c1314447d72"
        static let clientSecret = "6304cbc88c1341378fce675d101a6a3d"
        static let tokenAPIURL = "https://accounts.spotify.com/api/token"
        static let redirectURI = "myspotify://callback"
    }
    
    public var signInURL: URL? {
        let state = UUID().uuidString
        UserDefaults.standard.set(state, forKey: "spotify_auth_state")
        let scopes = "user-read-private%20user-read-email%20playlist-read-private%20playlist-modify-public%20playlist-modify-private%20user-follow-read%20user-library-modify%20user-library-read"
        let base = "https://accounts.spotify.com/authorize"
        let urlString = "\(base)?response_type=code&client_id=\(Constraints.clientID)&scope=\(scopes)&redirect_uri=\(Constraints.redirectURI)&state=\(state)&show_dialog=TRUE"
        return URL(string: urlString)
    }
    
    var isSignedIn: Bool {
        return accessToken != nil
    }
    
    private var accessToken: String? {
        return UserDefaults.standard.string(forKey: "access_token")
    }
    
    private var refreshToken: String? {
        return UserDefaults.standard.string(forKey: "refresh_token")
    }
    
    private var tokenExpirationDate: Date? {
        return UserDefaults.standard.object(forKey: "expirationDate") as? Date
    }
    
    private var shouldRefreshToken: Bool {
        guard let expirationDate = tokenExpirationDate else {
            return false
        }
        let currentDate = Date()
        let fiveMinutes: TimeInterval = 300
        return currentDate.addingTimeInterval(fiveMinutes) >= expirationDate
    }
    
    public func exchangeCodeForToken(code: String, completion: @escaping ((Bool)->Void)) {
        guard let url = URL(string: Constraints.tokenAPIURL) else {
            return
        }
        
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: Constraints.redirectURI),
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = components.query?.data(using: .utf8)
        let basicToken = Constraints.clientID+":"+Constraints.clientSecret
        let data = basicToken.data(using: .utf8)
        guard let base64 = data?.base64EncodedString() else {
            print("Error in base64")
            completion(false)
            return
        }
        request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) {[weak self] data, response, error in
            if let error = error {
                print("Network error: \(error.localizedDescription)")
                completion(false)
                return
            }
                
            if let response = response as? HTTPURLResponse {
                print("HTTP Response Code: \(response.statusCode)")
            }
                
            guard let data = data else {
                print("No data received from Spotify API")
                completion(false)
                return
            }
            do {
                let result = try JSONDecoder().decode(AuthResponse.self, from: data)
                self?.cacheToken(result: result)
                completion(true)
            } catch {
                print(error.localizedDescription)
                completion(false)
            }
        } 
        task.resume()
    }
    
    public func refreshAccessToken(completion: @escaping (Bool) -> Void) {
        guard let refreshToken = refreshToken else {
            completion(false)
            return
        }
        
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken)
        ]
        
        var request = URLRequest(url: URL(string: Constraints.tokenAPIURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let basicToken = Constraints.clientID + ":" + Constraints.clientSecret
        guard let base64 = basicToken.data(using: .utf8)?.base64EncodedString() else {
            completion(false)
            return
        }
        request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
        request.httpBody = components.query?.data(using: .utf8)
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let data = data, error == nil else {
                completion(false)
                return
            }
            
            do {
                let result = try JSONDecoder().decode(AuthResponse.self, from: data)
                self?.cacheToken(result: result)
                completion(true)
            } catch {
                print("Failed to refresh token: \(error.localizedDescription)")
                completion(false)
            }
        }
        task.resume()
    }
    
    public func cacheToken(result: AuthResponse) {
        UserDefaults.standard.setValue(result.access_token, forKey: "access_token")
        if let refresh_token = result.refresh_token {
            UserDefaults.standard.setValue(result.refresh_token, forKey: "refresh_token")
        }
        UserDefaults.standard.setValue(Date().addingTimeInterval(TimeInterval(result.expires_in)), forKey: "expirationDate")
    }
}
