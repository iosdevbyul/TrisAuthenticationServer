import Vapor

enum AuthenticationValidation {
    static func validate(email: String, password: String) throws {
        guard email.utf8.count <= 254, email.contains("@"), email.contains(".") else {
            throw APIError(.validationFailed, variant: .email)
        }
        try validate(password: password)
    }

    static func validate(password: String) throws {
        // bcrypt uses at most 72 bytes, including for multibyte characters.
        guard (7...20).contains(password.count), password.utf8.count <= 72 else {
            throw APIError(.validationFailed, variant: .password)
        }
    }

}
