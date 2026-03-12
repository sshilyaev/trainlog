# TrainLog — Архитектура

> Документ обновляется по мере согласования решений.

---

## Общая схема

```
┌─────────────────────────────────────────────────────────────────────┐
│                     iOS App (SwiftUI)                                │
├─────────────────────────────────────────────────────────────────────┤
│  Auth   │  Profile Switch   │  Coach Flow   │  Trainee Flow          │
│         │                   │               │                        │
│  Sign In│  Profile List     │  Dashboard    │  Dashboard             │
│  Sign Up│  Create Profile   │  Trainees     │  Goals                 │
│         │  Quick Switch     │  Client Card  │  Measurements          │
│         │                   │  Memberships  │  Add Measurement       │
│         │                   │  Visits      │  Charts (grid + full)  │
│         │                   │  (read-only)  │  Visits (read-only)   │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      Firebase                                        │
├──────────────────┬──────────────────┬───────────────────────────────┤
│ Auth             │ Firestore        │ Cloud Functions                │
│                  │                  │                                │
│ - Email/Password │ - profiles       │ - generateConnectionToken      │
│ - Anonymous?     │ - measurements   │ - validateToken, link trainee  │
│                  │ - goals          │ - token cleanup (expired)      │
│                  │ - coachTraineeLinks                                │
│                  │ - connectionTokens                                │
│                  │ - memberships    │                                │
│                  │ - visits         │                                │
└──────────────────┴──────────────────┴───────────────────────────────┘
```

---

## Модель данных (Firestore)

### Коллекция `users`
```
users/{userId}
  - email: string
  - displayName: string
  - createdAt: timestamp
```
Один документ на Firebase Auth пользователя.

---

### Коллекция `profiles`
```
profiles/{profileId}
  - userId: string              // владелец аккаунта
  - type: "coach" | "trainee"
  - name: string
  - gymName: string?            // только для coach
  - createdAt: timestamp
  - gender: "male" | "female"?  // только для trainee
  - iconEmoji: string?          // emoji иконки профиля
```

---

### Коллекция `coachTraineeLinks`
Связь тренерского профиля с подопечным (внешним или своим).

```
coachTraineeLinks/{linkId}
  - coachProfileId: string
  - traineeProfileId: string
  - createdAt: timestamp
  - displayName: string?        // имя для списка у тренера (если задано)
  - note: string?               // заметка тренера о подопечном
```
- Внешний подопечный: `traineeProfileId` → профиль другого пользователя.
- Внутренний («Добавить мой профиль»): оба профиля у одного `userId`.

---

### Коллекция `connectionTokens`
```
connectionTokens/{tokenId}
  - traineeProfileId: string
  - token: string               // 6–8 символов
  - createdAt: timestamp
  - expiresAt: timestamp
  - used: boolean
```

---

### Коллекция `measurements`
```
measurements/{measurementId}
  - profileId: string
  - date: timestamp
  - weight: number?
  - height: number?
  - neck: number?
  - shoulders: number?
  - leftBiceps: number?
  - rightBiceps: number?
  - waist: number?
  - belly: number?
  - leftThigh: number?
  - rightThigh: number?
  - hips: number?
  - buttocks: number?
  - leftCalf: number?
  - rightCalf: number?
  - note: string?
```

---

### Коллекция `goals`
```
goals/{goalId}
  - profileId: string
  - measurementType: string     // "weight", "waist", и т.д.
  - targetValue: number
  - targetDate: timestamp
  - createdAt: timestamp
```

---

### Коллекция `memberships`
Абонемент на N занятий для пары тренер–подопечный.

```
memberships/{membershipId}
  - coachProfileId: string
  - traineeProfileId: string
  - createdAt: timestamp
  - totalSessions: number       // всего занятий
  - usedSessions: number        // использовано
  - priceRub: number?           // опционально, информационно
  - status: string              // "active" | "finished" | "cancelled"
  - displayCode: string?        // номер для отображения: "A1", "B2", ...
```
- При создании абонемента `displayCode` вычисляется по порядку (1→A1, 2→A2, … 10→B1 и т.д.).
- Активный абонемент: `status == "active"` и `usedSessions < totalSessions`.

---

### Коллекция `visits`
Посещение (визит): факт прихода подопечного. Ведёт тренер.

```
visits/{visitId}
  - coachProfileId: string
  - traineeProfileId: string
  - createdAt: timestamp
  - date: timestamp             // дата посещения
  - status: string              // "planned" | "done" | "cancelled" | "noShow"
  - paymentStatus: string       // "unpaid" | "paid" | "debt"
  - membershipId: string?       // если списано с абонемента
  - membershipDisplayCode: string?  // номер абонемента для отображения, напр. "A1"
```
- При «Отметить приход» создаётся визит со статусом `done`; если есть активный абонемент с остатком — списывается занятие, `paymentStatus: "paid"`, заполняются `membershipId` и `membershipDisplayCode`; иначе `paymentStatus: "debt"`.
- Долговой визит можно погасить: контекстное меню по визиту «Списать с абонемента» — в меню перечислены **все** абонементы с остатком занятий; при выборе вызывается `markVisitPaidWithMembership(visit, membershipId)` и занятие списывается с выбранного абонемента.
- Отмена визита: `status: "cancelled"`, `paymentStatus: "unpaid"`, привязка к абонементу снимается. Если визит был списан с абонемента — занятие возвращается обратно.

---

## Правила безопасности Firestore

- `profiles` — только свой `userId` (read/create/update/delete по владельцу).
- `measurements`, `goals` — чтение/запись по `profileId`: владелец профиля или тренер, у которого в `coachTraineeLinks` есть `traineeProfileId`.
- `coachTraineeLinks` — тренер может создавать/читать/удалять ссылки для своих coach-профилей; trainee может читать свои связи.
- `connectionTokens` — создание и чтение только владельцем trainee-профиля; обновление (used) — через Cloud Function.
- `memberships`, `visits` — чтение и запись при наличии авторизации (правила допускают доступ по `request.auth != null`; разграничение по coach/trainee и парам выполняется на уровне запросов приложения).

---

## Структура приложения (Swift)

```
trainlog/
├── App/
│   ├── TrainLogApp.swift
│   └── AppState.swift
│
├── Core/
│   ├── Design/           // Design.swift, ButtonComponents, SettingsComponents
│   ├── Errors/           // AppErrors (маппинг ошибок для пользователя)
│   ├── Models/
│   │   ├── Profile.swift
│   │   ├── Measurement.swift
│   │   ├── Goal.swift
│   │   ├── CoachTraineeLink.swift
│   │   ├── ConnectionToken.swift
│   │   ├── Membership.swift
│   │   └── Visit.swift
│   ├── Services/         // *ServiceProtocol + Firestore*Service, Mock*Service
│   │   ├── AuthService, ProfileService, MeasurementService, GoalService
│   │   ├── CoachTraineeLinkService, ConnectionTokenService
│   │   ├── MembershipService, VisitService
│   └── Extensions/
│
├── Features/
│   ├── Auth/
│   ├── Splash/
│   ├── ProfileSwitch/    // выбор профиля, создание, редактирование, онбординг
│   ├── Coach/            // подопечные, карточка клиента, абонементы, посещения
│   └── Trainee/          // дашборд, замеры, цели, графики, посещения (read-only)
│
└── Resources/
```

---

## Ключевые сценарии

1. **Подключение по токену**: trainee генерирует токен → coach сканирует/вводит → выбирает coach-профиль → создаётся `coachTraineeLinks`.
2. **«Добавить мой профиль»**: coach выбирает свой trainee-профиль → создаётся `coachTraineeLinks` (тот же `userId`).
3. **Графики**: сетка мини-графиков → тап → полноэкранный график с целями (горизонтальная линия).
4. **Удаление профиля**: удаление профиля и связанных `measurements`, `goals`, `coachTraineeLinks`, `connectionTokens` (memberships и visits при необходимости доработать политику).
5. **Абонемент**: тренер в карточке подопечного → Абонементы → Новый абонемент (N занятий, опц. цена) → создаётся документ в `memberships` с `displayCode` (A1, B2, …).
6. **Посещение**: тренер → Посещения → Отметить приход (дата) → создаётся визит в `visits`, при наличии активного абонемента списывается занятие и визит привязывается к абонементу; иначе визит в статусе долг. Долг можно погасить: контекстное меню по визиту «Списать с абонемента» — в меню перечислены все абонементы с остатком занятий, выбор конкретного абонемента для списания.
7. **Просмотр посещений подопечным**: профиль → Посещения → список по тренерам, по каждому список визитов (дата, статус, с какого абонемента списано).
8. **Переиспользуемые блоки**: календарь посещаемости (`VisitsCalendarView`), блок абонементов («Активные»/«Завершённые» — `MembershipsBlockView`), список посещений за месяц (`VisitsListBlockView`) — общие для тренера и подопечного; различается только логика (у тренера — кнопки «Добавить посещение», «Списать с абонемента», у подопечного — только просмотр).
9. **Последний выбранный профиль**: при выборе профиля его id сохраняется в UserDefaults (`lastSelectedProfileId_<userId>`). После загрузки профилей при перезаходе в приложение, если сохранённый профиль есть в списке, сразу открывается главный экран с ним без экрана выбора.
10. **Нижнее меню (табы)**: по умолчанию открывается вкладка «Профиль» (у тренера и подопечного). В списке подопечных — поиск/фильтр по имени или заметке; при первом заходе на вкладку — лоадер до загрузки списка.

---

## Стек

| Компонент | Технология |
|-----------|------------|
| UI | SwiftUI |
| Графики | Swift Charts |
| Backend | Firebase Auth, Firestore |
| QR | AVFoundation |
| DI / State | @Observable, Environment |

---

## Предпродакшен и стандарты

Подробно: **docs/PREPRODUCTION_STANDARDS.md**.

Кратко:

1. **UX / Design System** — все кнопки, списки, иконки, заголовки, шрифты, цвета и размеры переиспользуются из `Core/Design` (Design.swift, ButtonComponents.swift, SettingsComponents.swift). Не хардкодить стили в экранах.
2. **Слой данных** — работа с сервером только через протоколы сервисов (`*ServiceProtocol`). Реализации — Firestore или Mock. Экраны не зависят от Firebase. Заложена возможность замены бэкенда на отдельный API.
3. **Загрузка** — у каждого экрана/перехода с загрузкой данных обязательно состояние загрузки (лоадер). Унифицированный вид (один компонент/паттерн по всему приложению).
4. **Ошибки** — все ошибки при работе с сервером маппятся в пользовательские сообщения (словарь/модуль) и отображаются пользователю единообразно (alert или общий компонент).
