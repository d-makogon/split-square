# SplitSquare — iOS Starter (SwiftUI)

Готовый стартовый набор исходников под iOS-приложение для совместных трат:
- Группы с валютой по умолчанию
- Инвайт-ссылки (Firebase Dynamic Links) — опционально
- Добавление/редактирование трат (поровну/вручную), фиксация плательщика
- Добавление выплат (переводы между участниками)
- Экран «Выплаты»: расчёт минимального набора переводов для закрытия долгов
- Локальное хранилище по умолчанию; Firestore/Firebase — по желанию

## Как быстро запустить
1) В Xcode создайте новый проект **iOS App (SwiftUI, Swift)** с именем `SplitSquare`.
2) Удалите сгенерированные `ContentView.swift` и `SplitSquareApp.swift` (или замените их содержимым из `App/SplitSquareApp.swift`).
3) Скопируйте всю папку `App`, `Core`, `Data`, `Features` из этого архива в ваш проект (drag & drop в Xcode, **Create folder references** или **Create groups** — на ваш выбор).
4) Соберите и запустите. По умолчанию будет использоваться **локальное in‑memory** хранилище (без интернета).

## Включить Firebase (реал-тайм синхронизацию и инвайты)
1) В Xcode > Project > **Package Dependencies** добавьте:
   - `https://github.com/firebase/firebase-ios-sdk`
   - выберите продукты: `FirebaseAuth`, `FirebaseFirestore`, `FirebaseDynamicLinks`
2) В консоли Firebase создайте iOS-приложение (Bundle ID = вашего проекта) и скачайте `GoogleService-Info.plist`. Добавьте его в Xcode (в таргет).
3) В `Data/BackendSwitch.swift` поставьте `useFirebase = true`.
4) Соберите и запустите на устройстве. Инвайт-ссылки работают через Firebase Dynamic Links (см. `Data/InviteService.swift`).

## Что внутри
- **Core/** модели, валюты, округление, расчёт балансов и минимальных переводов.
- **Data/** абстракции и две реализации бекенда: Local (in-memory) и Firebase (если доступен), сервис инвайтов.
- **Features/** SwiftUI экраны: группы, детали, добавление трат/выплат, расчёт выплат.
- **App/** входная точка, роутинг.

## Известные моменты
- Для Firebase нужен реальный `GoogleService-Info.plist` и домен Dynamic Links.
- Правила безопасности Firestore приведены в комментариях в `Data/FirebaseStore.swift`.
- Валютные курсы вводятся вручную (поле «Курс → [валюта группы]»). Можно подключить API курсов по желанию.

Удачи!
