//
//  ResetPasswordRequestDTO.swift
//  AuthenticationServerKit
//
//  Created by COMATOKI on 2026-09-08.
//

import Vapor

public struct ResetPasswordRequestDTO: Content {
    public let token: String
    public let newPassword: String
    public init(token: String, newPassword: String) {
        self.token = token
        self.newPassword = newPassword
    }
}
