import Foundation

func makeStore() -> GroupStore {
    #if canImport(FirebaseFirestore)
    if useFirebase {
        return FirebaseStore()
    } else {
        return LocalStore()
    }
    #else
    return LocalStore()
    #endif
}
