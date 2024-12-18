//
//  AuthResponse.swift
//  MySpotify
//
//  Created by Saltanat Zarkhinova on 18.12.2024.
//

import Foundation

struct AuthResponse: Codable {
    let access_token: String
    let token_type: String
    let scope: String
    let expires_in: Int
    let refresh_token: String?
}
