# TrainLog — Настройка

## После смены Bundle ID и папки (миграция с BodyMetric)

Если проект переименован в TrainLog с новым Bundle ID `com.sshilyaev.trainlog` и папкой **trainlog**:

1. **Firebase Console** — в том же проекте (или в новом):
   - **Project Settings** (шестерёнка) → раздел **Your apps**.
   - Нажми **Add app** → **iOS**.
   - Укажи Bundle ID: `com.sshilyaev.trainlog`.
   - Скачай **GoogleService-Info.plist** и замени им файл в папке **trainlog** (удалив старый).
   - Без нового plist приложение не подключится к Firebase (Auth/Firestore будут падать).

2. **Данные** — старые данные остаются в Firebase (проект тот же). Новое приложение с новым Bundle ID будет тем же пользователям заходить под теми же аккаунтами, но профили/замеры привязаны к `userId`, так что после входа данные подтянутся. Если создаёшь **новый** проект Firebase — данные нужно переносить отдельно или начать с пустой базы.

3. **Xcode** — открой проект, выбери схему **TrainLog**, убедись, что в **Signing & Capabilities** Bundle Identifier = `com.sshilyaev.trainlog`.

---

## От тебя нужно

### 1. Firebase — пошагово с нуля

Открой в браузере: **[console.firebase.google.com](https://console.firebase.google.com)** и войди в аккаунт Google.

---

#### Шаг 1. Создать проект

1. На главной странице нажми **«Создать проект»** (или **Add project**).
2. Введи название проекта (например, **TrainLog**) → **Продолжить**.
3. Аналитику Google можно отключить (переключатель «Включить Google Analytics») → **Создать проект**.
4. Дождись создания → **Продолжить**.

---

#### Шаг 2. Добавить iOS-приложение

1. На странице проекта нажми иконку **iOS** (яблоко) или **«Добавить приложение»** → выбери **iOS**.
2. В поле **Apple bundle ID** введи: `com.sshilyaev.trainlog` (как в Xcode у target TrainLog).
3. Псевдоним приложения можно оставить пустым или ввести **TrainLog**.
4. Нажми **«Зарегистрировать приложение»**.
5. Скачай файл **GoogleService-Info.plist** (кнопка **«Скачать GoogleService-Info.plist»**).
6. В Xcode перетащи этот файл в папку **trainlog** (туда, где лежат TrainLogApp.swift и остальной код). В диалоге включи опцию **Copy items if needed** и отметь target **TrainLog**.
7. В Firebase нажми **«Далее»** → **«Далее»** → **«Продолжить в консоли»**.

---

#### Шаг 3. Включить вход по email (Authentication)

1. В левом меню консоли Firebase выбери **«Сборка»** (Build) → **Authentication**.
2. Нажми **«Начать»** (или **Get started**), если сервис ещё не включён.
3. Открой вкладку **«Метод входа»** (Sign-in method).
4. В списке найди **«Эл. почта/Пароль»** (Email/Password) и нажми на строку.
5. Включи переключатель **«Включить»** → **Сохранить**.

Без этого в приложении не будут работать регистрация и вход.

---

#### Шаг 4. Создать базу Firestore

1. В левом меню выбери **«Сборка»** → **Firestore Database**.
2. Нажми **«Создать базу данных»** (Create database).
3. Выбери режим безопасности:
   - **«Начать в тестовом режиме»** — для разработки (доступ по правилам на 30 дней, потом нужно будет правила обновить).
   - Либо **«Режим производства»** — тогда сразу задай правила из шага 5.
4. Выбери регион (например, **europe-west1**) → **Включить**.
5. Дождись создания базы. Появится пустая база с вкладками **«Данные»** и **«Правила»**.

---

#### Шаг 5. Задать правила Firestore

1. Оставаясь в **Firestore Database**, открой вкладку **«Правила»** (Rules).
2. Удали текущий текст в редакторе и вставь целиком блок ниже.
3. Нажми **«Опубликовать»** (Publish).

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /profiles/{profileId} {
      allow read: if request.auth != null && request.auth.uid == resource.data.userId;
      allow create: if request.auth != null;
      allow update: if request.auth != null && request.auth.uid == resource.data.userId;
      allow delete: if request.auth != null && request.auth.uid == resource.data.userId;
    }
    match /measurements/{mId} {
      allow read, write: if request.auth != null;
    }
    match /goals/{goalId} {
      allow read, write: if request.auth != null;
    }
    match /coachTraineeLinks/{linkId} {
      allow read, create: if request.auth != null;
      allow delete: if request.auth != null;
    }
    match /memberships/{membershipId} {
      allow read, write: if request.auth != null;
    }
    match /visits/{visitId} {
      allow read, write: if request.auth != null;
    }
    match /connectionTokens/{tokenId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

Коллекции **profiles**, **measurements**, **goals**, **coachTraineeLinks**, **connectionTokens**, **memberships**, **visits** приложение создаёт само при первом сохранении данных. Вручную их создавать не нужно.

---

#### Шаг 6. Индексы (по необходимости)

При первом открытии списка замеров или **целей** Firestore может показать ошибку со ссылкой на создание индекса. **Открой ссылку из ошибки в браузере** и нажми **«Создать индекс»** (Create index). Подожди пару минут, пока индекс построится.

Либо создай составные индексы вручную: **Firestore → Индексы → Создать индекс**:

- Коллекция **measurements**: поля **profileId** (по возрастанию), **date** (по убыванию).
- Коллекция **goals**: поля **profileId** (по возрастанию), **targetDate** (по возрастанию).

---

Итого в Firebase сделано: проект, iOS-приложение, plist в проекте, включён вход по email, создана база Firestore и заданы правила. После этого можно собирать и запускать приложение.

### 2. Firebase SDK (Swift Package Manager)

#### Как удалить пакет и поставить заново

1. В Xcode открой **Project Navigator** (⌘1) и выбери самый верхний элемент — проект (синяя иконка, имя проекта).
2. В группе под проектом должна быть папка **trainlog** с исходниками.
2. В левой панели выбери сам проект (не target), открой вкладку **Package Dependencies**.
3. В списке найди **firebase-ios-sdk**, выдели и нажми кнопку **−** (минус) внизу списка.
4. Подтверди удаление. Пакет исчезнет из проекта.
5. Добавь пакет снова: **File → Add Package Dependencies...**
6. В поле URL вставь: `https://github.com/firebase/firebase-ios-sdk.git`
7. Нажми **Add Package**, дождись загрузки.
8. На следующем экране **обязательно отметь галочками** нужные продукты:
   - **FirebaseCore**
   - **FirebaseAuth**
   - **FirebaseFirestore**
9. Убедись, что в колонке справа выбран target **TrainLog**.
10. Нажми **Add Package**.

После этого продукты будут привязаны к target и ошибка «Missing package product» пропадёт.

---

#### Если пакет уже добавлен

1. В Xcode: **File → Add Package Dependencies**
2. URL: `https://github.com/firebase/firebase-ios-sdk`
3. Выбери версию (актуальная, например 12.x)
4. Нажми **Add Package**, затем в списке продуктов отметь:
   - **FirebaseAuth**
   - **FirebaseFirestore**
   - **FirebaseCore**
5. Нажми **Add Package**

Если пакет уже добавлен, но продукты не привязаны к target:
- Выбери проект → target **TrainLog** → вкладка **General**
- Прокрути до **Frameworks, Libraries, and Embedded Content**
- Нажми **+** → **Add Package Product...** → выбери **firebase-ios-sdk** → добавь **FirebaseCore**, **FirebaseAuth**, **FirebaseFirestore**

**Если при сборке «Missing package product»** — привяжи продукты к target: target **TrainLog** → вкладка **Build Phases** → **Link Binary With Libraries** → **+** → **Add Other...** → **Add Package Product...** → выбери **firebase-ios-sdk** и добавь **FirebaseCore**, **FirebaseAuth**, **FirebaseFirestore**.

### 3. Firestore indexes

При первом запросе замеров Firestore может выдать ссылку на создание индекса. Создай индекс:

- Коллекция `measurements`: поле `profileId` (Ascending), поле `date` (Descending)
- Коллекция `goals`: поле `profileId` (Ascending), поле `targetDate` (Ascending)

### 4. Firestore rules (для копирования)

Если нужно вставить правила ещё раз (Firebase Console → Firestore → вкладка Rules):

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /profiles/{profileId} {
      allow read: if request.auth != null && request.auth.uid == resource.data.userId;
      allow create: if request.auth != null;
      allow update: if request.auth != null && request.auth.uid == resource.data.userId;
      allow delete: if request.auth != null && request.auth.uid == resource.data.userId;
    }
    match /measurements/{mId} {
      allow read, write: if request.auth != null;
    }
    match /goals/{goalId} {
      allow read, write: if request.auth != null;
    }
    match /coachTraineeLinks/{linkId} {
      allow read, create: if request.auth != null;
      allow delete: if request.auth != null;
    }
    match /memberships/{membershipId} {
      allow read, write: if request.auth != null;
    }
    match /visits/{visitId} {
      allow read, write: if request.auth != null;
    }
    match /connectionTokens/{tokenId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 5. Проверка

- Собери проект (Cmd+B). Если `FirebaseAuth` / `FirebaseFirestore` не находятся — проверь, что пакеты добавлены в target.
- Запусти приложение: регистрация, вход, создание профиля, добавление замера должны работать.

**Если в Firestore уже есть документы профилей с полем `isManaged`** — приложение его больше не использует, можно не трогать. Поле **`gender`** в профиле подопечного опционально (М/Ж). В профиле опционально хранится **iconEmoji** (иконка). В связях тренер–подопечный (**coachTraineeLinks**) опционально хранятся **displayName** (имя для списка у тренера) и **note** (заметка). Коллекции **memberships** (абонементы по парам тренер–подопечный) и **visits** (посещения) используются в карточке клиента у тренера: абонементы, отметка прихода, списание с абонемента или долг; подопечный видит посещения в разделе «Посещения» в режиме только просмотра.

---

### 6. Иконка приложения и экран запуска (сплеш)

#### Иконка приложения (App Icon)

1. Открой проект в **Xcode**.
2. В левой панели (Project Navigator, ⌘1) открой **trainlog** → **Assets.xcassets**.
3. Выбери **AppIcon** (или **AppIcon.appiconset**).
4. В правой панели отобразятся слоты для иконок. В современном формате обычно нужен один универсальный слот **1024×1024** (Universal, iOS).
5. Подготовь изображение иконки **1024×1024 пикселей**, без альфа-канала, в формате PNG.
6. Перетащи файл иконки в слот **1024×1024** в Xcode (в область AppIcon) — либо перетащи на нужный размер в списке, либо перетащи в общую область, если слот один.
7. При необходимости добавь варианты для тёмной темы и tinted (если в AppIcon.appiconset есть слоты Dark и Tinted) — те же размеры, свои файлы.
8. Сохрани (⌘S). Собери проект — иконка подставится на домашний экран и в настройках.

Если в **AppIcon.appiconset** несколько слотов (например, отдельно 1024 для light/dark/tinted), заполни нужные: перетащи соответствующий PNG в каждый слот по размеру (1024×1024).

#### Экран запуска (Launch Screen / сплеш)

В проекте включена генерация экрана запуска из настроек (**UILaunchScreen**). Настроить его можно так:

1. В Xcode выбери **проект** (синяя иконка) в навигаторе.
2. Выбери **target TrainLog** → вкладка **General**.
3. Прокрути до блока **App Icons and Launch Screen** (или **Launch Screen**).
4. Там обычно есть настройки **Launch Screen**:
   - Если видишь **Launch Screen File** — можно указать свой storyboard. Создай новый файл: **File → New → File…** → **Launch Screen**, сохрани в папку **trainlog**, затем в этом поле выбери созданный storyboard. В storyboard добавь свой фон и логотип.
   - Если используется **Use Asset Catalog** или только флаги в Info — экран генерируется системой. Тогда кастомизация делается через **Asset Catalog**: в **Assets.xcassets** создай набор для Launch Image (например, **LaunchImage** или как предлагает Xcode) и добавь туда изображения для разных размеров экрана, либо настрой в **Info** ключи для фона и изображения (зависит от версии Xcode).

**Простой вариант без storyboard (рекомендуется для начала):**

1. **Assets.xcassets** → правый клик → **App Icons & Launch Images** → **New iOS Launch Image** (или **New Launch Image Set**). Назови, например, **LaunchImage**.
2. В созданный набор добавь изображение для сплеша (например, 1x, 2x, 3x или одно универсальное — зависит от шаблона). Часто достаточно одного изображения с подходящим разрешением (например, 1284×2778 для iPhone или меньше — система масштабирует).
3. В настройках target: **General** → **App Icons and Launch Screen** → в поле **Launch Screen** укажи этот asset или оставь автоматическую генерацию и задай в **Info.plist** ключ `UILaunchScreen` (словарь) с ключами `UIImageName` / `UIColorName` и т.п., если твоя версия Xcode это поддерживает.

**Через Info.plist (если нет отдельного storyboard):**

- Открой **Info** таб у target (или Info.plist, если он есть в проекте).
- Добавь ключ **UILaunchScreen** (Dictionary). Внутри можно задать, например:
  - **UIImageName** — имя изображения из Assets (создай Image Set в Assets.xcassets для сплеша и укажи его имя).
  - **UIColorName** — имя цвета фона из Assets (опционально).
  - **ImageName** — альтернативное имя картинки.

После изменений пересобери проект и запусти приложение — при старте будет отображаться твой сплеш до загрузки интерфейса.
