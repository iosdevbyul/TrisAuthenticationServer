//
//  AuthDTOs.swift
//  AuthenticationServerKit
//
//  Created by COMATOKI on 2026-08-28.
//


import Vapor

public struct RefreshRequestDTO: Content {
    public let refreshToken: String
    public init(refreshToken: String) {
        self.refreshToken = refreshToken
    }
}

// MARK: - Request DTOs
/// iOS 클라이언트의 LoginRequestDTO / SignUpRequestDTO와 매핑
public struct AuthRequestDTO: Content {
    public let email: String
    public let password: String
    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

/// iOS 클라이언트의 ForgotPasswordRequestDTO와 매핑
public struct ForgotPasswordRequestDTO: Content {
    public let email: String
    public init(email: String) {
        self.email = email
    }
}

// MARK: - Response DTOs
public struct UserResponseDTO: Content {
    public let id: String
    public let email: String
    public let isEmailVerified: Bool
    public init(id: String, email: String, isEmailVerified: Bool) {
        self.id = id
        self.email = email
        self.isEmailVerified = isEmailVerified
    }
}

public struct SessionResponseDTO: Content {
    public let user: UserResponseDTO
    public let accessToken: String
    public let refreshToken: String?
    public init(user: UserResponseDTO, accessToken: String, refreshToken: String?) {
        self.user = user
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}

public struct MessageResponseDTO: Content {
    public let message: String
    public init(message: String) {
        self.message = message
    }
}

/// iOS 클라이언트의 ChangePasswordRequestDTO와 매핑
public struct ChangePasswordRequestDTO: Content {
    public let currentPassword: String
    public let newPassword: String
    public init(currentPassword: String, newPassword: String) {
        self.currentPassword = currentPassword
        self.newPassword = newPassword
    }
}


public struct VerifyEmailRequestDTO: Content {
    public let token: String
    public init(token: String) {
        self.token = token
    }
}

public struct ResendVerificationEmailRequestDTO: Content {
    public let email: String
    public init(email: String) {
        self.email = email
    }
}

public struct RequestEmailChangeRequestDTO: Content {
    public let currentPassword: String
    public let newEmail: String
    public init(currentPassword: String, newEmail: String) {
        self.currentPassword = currentPassword
        self.newEmail = newEmail
    }
}

public struct ConfirmEmailChangeRequestDTO: Content {
    public let token: String
    public init(token: String) {
        self.token = token
    }
}
