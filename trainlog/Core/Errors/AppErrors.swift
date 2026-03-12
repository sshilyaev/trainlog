//
//  AppErrors.swift
//  TrainLog
//

import Foundation
import FirebaseAuth

/// Единый маппинг ошибок в сообщения для пользователя (на русском).
enum AppErrors {

    /// Сообщение для показа в alert или в интерфейсе. Всегда непустая строка.
    static func userMessage(for error: Error) -> String {
        let ns = error as NSError

        // Firebase Auth
        if ns.domain == AuthErrorDomain, let authCode = AuthErrorCode(_bridgedNSError: ns) {
            switch authCode.code {
            case .wrongPassword:
                return "Неверный пароль."
            case .userNotFound:
                return "Пользователь не найден. Проверьте email."
            case .invalidEmail:
                return "Некорректный email."
            case .networkError:
                return "Нет соединения с интернетом. Попробуйте ещё раз."
            case .tooManyRequests:
                return "Слишком много попыток. Попробуйте позже."
            case .emailAlreadyInUse:
                return "Этот email уже зарегистрирован."
            case .weakPassword:
                return "Пароль слишком простой. Используйте не менее 6 символов."
            case .invalidCredential:
                return "Неверный email или пароль."
            case .userDisabled:
                return "Аккаунт отключён. Обратитесь в поддержку."
            default:
                break
            }
        }

        // Firestore — по домену и коду
        if ns.domain == "FIRFirestoreErrorDomain" {
            switch ns.code {
            case 7: // permission-denied
                return "Нет доступа к данным. Проверьте подключение к интернету и войдите снова."
            case 14: // unavailable
                return "Сервис временно недоступен. Попробуйте позже."
            case 5: // not-found
                return "Данные не найдены."
            default:
                break
            }
        }

        // Сеть (URLError)
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                return "Нет соединения с интернетом. Проверьте сеть и попробуйте снова."
            case NSURLErrorTimedOut:
                return "Превышено время ожидания. Попробуйте позже."
            default:
                break
            }
        }

        return "Что-то пошло не так. Попробуйте позже."
    }
}
