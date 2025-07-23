@MainActor
final class Dependencies {
    static let shared = Dependencies()

    private init() {}

    // MARK: Error

    lazy var errorHandler: (Error?) -> Void = { _ in }
}

/// A property wrapper that injects a dependency from the ``Dependencies`` container.
@MainActor
@propertyWrapper
struct Dependency<T> {
    let keyPath: KeyPath<Dependencies, T>

    init(_ keyPath: KeyPath<Dependencies, T>) {
        self.keyPath = keyPath
    }

    var wrappedValue: T {
        Dependencies.shared[keyPath: keyPath]
    }
}
