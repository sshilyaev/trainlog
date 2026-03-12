# TrainLog

iOS-приложение (SwiftUI) для ведения дневника замеров и работы тренера с подопечными: профили, замеры, цели, абонементы и посещения.

## Стек
- **UI**: SwiftUI
- **Backend**: Firebase Auth + Firestore

## Быстрый старт
1. Открой проект в Xcode (`trainlog.xcodeproj`).
2. Установи Firebase через SPM (см. `SETUP.md`).
3. Скачай `GoogleService-Info.plist` для bundle id `com.sshilyaev.trainlog` и положи в `trainlog/` (см. `SETUP.md`).
4. Собери и запусти.

## Важно
- `GoogleService-Info.plist` **не коммитится** (секреты). Добавь свой локально.

## Документация
- `SETUP.md` — настройка Firebase и сборки
- `ARCHITECTURE.md` — архитектура и модели данных
- `docs/PREPRODUCTION_STANDARDS.md` — стандарты UI/UX, загрузка, ошибки, слой данных

