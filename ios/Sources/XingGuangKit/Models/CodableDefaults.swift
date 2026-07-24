import Foundation

extension KeyedDecodingContainer {
    func string(_ key: Key, default defaultValue: String = "") -> String {
        if let value = try? decode(String.self, forKey: key) { return value }
        if let value = try? decode(Int64.self, forKey: key) { return String(value) }
        if let value = try? decode(Double.self, forKey: key) { return String(value) }
        if let value = try? decode(Bool.self, forKey: key) { return String(value) }
        return defaultValue
    }

    func integer(_ key: Key, default defaultValue: Int = 0) -> Int {
        do {
            return try decodeIfPresent(Int.self, forKey: key) ?? defaultValue
        } catch {
            return Int(string(key)) ?? defaultValue
        }
    }

    func int64(_ key: Key, default defaultValue: Int64 = 0) -> Int64 {
        do {
            return try decodeIfPresent(Int64.self, forKey: key) ?? defaultValue
        } catch {
            return Int64(string(key)) ?? defaultValue
        }
    }

    func double(_ key: Key, default defaultValue: Double = 0) -> Double {
        do {
            return try decodeIfPresent(Double.self, forKey: key) ?? defaultValue
        } catch {
            return Double(string(key)) ?? defaultValue
        }
    }

    func boolean(_ key: Key, default defaultValue: Bool = false) -> Bool {
        do {
            return try decodeIfPresent(Bool.self, forKey: key) ?? defaultValue
        } catch {
            return integer(key, default: defaultValue ? 1 : 0) == 1
        }
    }

    func array<T: Decodable>(_ type: T.Type, _ key: Key) -> [T] {
        (try? decodeIfPresent([T].self, forKey: key)) ?? []
    }

    func dictionary<T: Decodable>(_ type: T.Type, _ key: Key) -> [String: T] {
        (try? decodeIfPresent([String: T].self, forKey: key)) ?? [:]
    }
}
