# Firebase быстрая настройка

1) Консоль Firebase → новый проект → добавить iOS‑приложение с вашим Bundle ID.
2) Скачать `GoogleService-Info.plist` и добавить в Xcode (в таргет).
3) Xcode → Project → Package Dependencies → добавить `https://github.com/firebase/firebase-ios-sdk`:
   - Products: `FirebaseAuth`, `FirebaseFirestore`, `FirebaseDynamicLinks`
4) В Info.plist добавьте URL Types для Dynamic Links (см. документацию Firebase).
5) В коде `Data/BackendSwitch.swift` установите `useFirebase = true`.
6) (Необязательно) Настройте свой домен Dynamic Links, например `https://splitsqapp.page.link`.

Готово.
