# Security / Secrets

Этот репозиторий публичный. **Никаких секретов в git.**

## Что нельзя коммитить
- `GoogleService-Info.plist` (Firebase ключи/идентификаторы приложения)
- любые `.env`, токены, ключи, приватные ключи (`*.p12`, `*.pem`, `*.key`)
- `service-account.json` и любые креды для серверов
- дампы БД, экспорт пользователей

## Что уже защищено `.gitignore`
- `**/GoogleService-Info.plist`
- `**/xcuserdata/` (пользовательские настройки Xcode)
- `.cursor/` (локальные настройки IDE)

## Как работать с Firebase в этом проекте
- Добавь свой `trainlog/GoogleService-Info.plist` локально (см. `SETUP.md`).
- В репозитории есть `trainlog/GoogleService-Info.plist.example` как подсказка.

