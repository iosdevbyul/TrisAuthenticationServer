//
//  EmailService.swift
//  WakTrainerServer
//
//  Created by COMATOKI on 2026-09-08.
//

import AuthenticationServerKit
import Foundation
import Vapor

extension AuthenticationEmail {
    static func signUpVerification(to email: String, verificationURL: String) -> Self {
        let escapedURL = verificationURL.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        return .init(recipient: email, subject: "WakTrainer 이메일 인증", html: """
            <p>아래 링크에서 이메일 인증을 완료해주세요. 링크는 24시간 동안 유효합니다.</p>
            <p><a href="\(escapedURL)">이메일 인증</a></p>
            """)
    }

    static func emailChangeVerification(to email: String, verificationURL: String) -> Self {
        let escapedURL = verificationURL.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        return .init(recipient: email, subject: "WakTrainer 이메일 변경 인증", html: """
            <p>로그인한 계정에서 아래 링크의 이메일 변경을 확인해주세요. 링크는 30분 동안 유효합니다.</p>
            <p><a href="\(escapedURL)">이메일 변경 확인</a></p>
            """)
    }

    static func passwordReset(to email: String, resetURL: String) -> Self {
        .init(recipient: email, subject: "WakTrainer 비밀번호 재설정", html: """
            <p>비밀번호를 재설정하려면 아래 링크를 눌러주세요.</p>
            <p><a href="\(resetURL)">비밀번호 재설정</a></p>
            """)
    }
}

struct ResendEmailTransport: EmailSending {
    func send(_ message: EmailMessage, on req: Request) async throws {
        guard let apiKey = Environment.get("RESEND_API_KEY"),
              !apiKey.isEmpty else {
            throw APIError(.internalError)
        }

        let body = ResendEmailRequest(
            from: "WakTrainer <onboarding@resend.dev>",
            to: [message.recipient],
            subject: message.subject,
            html: message.html
        )

        let response = try await req.client.post(
            URI(string: "https://api.resend.com/emails")
        ) { request in
            request.headers.bearerAuthorization = BearerAuthorization(
                token: apiKey
            )

            request.headers.contentType = .json
            try request.content.encode(body)
        }

        guard response.status.code >= 200,
              response.status.code < 300 else {
            throw APIError(.emailDeliveryFailed)
        }
    }
}

private struct ResendEmailRequest: Content {
    let from: String
    let to: [String]
    let subject: String
    let html: String
}
