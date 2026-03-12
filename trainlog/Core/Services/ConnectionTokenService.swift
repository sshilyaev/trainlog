//
//  ConnectionTokenService.swift
//  TrainLog
//

import Foundation

protocol ConnectionTokenServiceProtocol {
    /// Создать токен для профиля подопечного. Document ID = token string.
    func createToken(traineeProfileId: String) async throws -> ConnectionToken
    /// Получить токен по строке кода (чтение документа по id).
    func getToken(token: String) async throws -> ConnectionToken?
    /// Отметить токен как использованный.
    func markTokenUsed(token: String) async throws
}
