import Foundation
import GRDB

public protocol PersistenceStore: Sendable {
    func replaceConfiguration(_ document: VodConfigDocument, sourceURL: String) throws
    func loadSites() throws -> [Site]
    func loadKeeps() throws -> [Keep]
    func containsKeep(key: String) throws -> Bool
    @discardableResult func toggleKeep(_ keep: Keep) throws -> Bool
    func loadHistories(limit: Int) throws -> [History]
    func history(key: String) throws -> History?
    func saveHistory(_ history: History) throws
    func saveTrack(_ track: TrackRecord) throws
}

public final class AppDatabase: PersistenceStore, @unchecked Sendable {
    private let queue: DatabaseQueue
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public static func live() throws -> AppDatabase {
        let manager = FileManager.default
        let directory = try manager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("XingGuang", isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        return try AppDatabase(path: directory.appendingPathComponent("xingguang.sqlite").path)
    }

    public static func inMemory() throws -> AppDatabase {
        try AppDatabase(queue: DatabaseQueue())
    }

    public convenience init(path: String) throws {
        try self.init(queue: DatabaseQueue(path: path))
    }

    private init(queue: DatabaseQueue) throws {
        self.queue = queue
        try migrator.migrate(queue)
    }

    public func replaceConfiguration(_ document: VodConfigDocument, sourceURL: String) throws {
        let sites = try document.sites.map { ($0, try json($0)) }
        let lives = try document.lives.map { ($0, try json($0)) }
        let documentJSON = try json(document)
        try queue.write { db in
            try db.inTransaction {
                try db.execute(sql: "DELETE FROM site")
                try db.execute(sql: "DELETE FROM live")
                for (site, payload) in sites {
                    try db.execute(
                        sql: "INSERT INTO site (key, searchable, changeable, json) VALUES (?, ?, ?, ?)",
                        arguments: [site.key, site.searchable, site.changeable, payload]
                    )
                }
                for (live, payload) in lives {
                    try db.execute(
                        sql: "INSERT INTO live (name, boot, pass, keep, json) VALUES (?, ?, ?, ?, ?)",
                        arguments: [live.name, live.boot, live.pass, "", payload]
                    )
                }
                try db.execute(
                    sql: """
                    INSERT INTO config (type, time, url, json, name, logo, home, parse)
                    VALUES (0, ?, ?, ?, ?, ?, ?, '')
                    ON CONFLICT(url, type) DO UPDATE SET
                        time = excluded.time,
                        json = excluded.json,
                        name = excluded.name,
                        logo = excluded.logo,
                        home = excluded.home
                    """,
                    arguments: [Int64(Date().timeIntervalSince1970 * 1000), sourceURL, documentJSON, "点播", document.logo, document.sites.first?.key ?? ""]
                )
                return .commit
            }
        }
    }

    public func loadKeeps() throws -> [Keep] {
        try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM keep ORDER BY createTime DESC").map(Self.keep(from:))
        }
    }

    public func loadSites() throws -> [Site] {
        try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT json FROM site ORDER BY rowid").compactMap { row in
                let value: String = row["json"]
                return try? decoder.decode(Site.self, from: Data(value.utf8))
            }
        }
    }

    public func containsKeep(key: String) throws -> Bool {
        try queue.read { db in
            try Bool.fetchOne(db, sql: "SELECT EXISTS(SELECT 1 FROM keep WHERE key = ?)", arguments: [key]) ?? false
        }
    }

    @discardableResult
    public func toggleKeep(_ keep: Keep) throws -> Bool {
        try queue.write { db in
            let exists = try Bool.fetchOne(db, sql: "SELECT EXISTS(SELECT 1 FROM keep WHERE key = ?)", arguments: [keep.key]) ?? false
            if exists {
                try db.execute(sql: "DELETE FROM keep WHERE key = ?", arguments: [keep.key])
                return false
            }
            try db.execute(
                sql: "INSERT INTO keep (key, siteName, vodName, vodPic, createTime, type, cid) VALUES (?, ?, ?, ?, ?, ?, ?)",
                arguments: [keep.key, keep.siteName, keep.vodName, keep.vodPic, keep.createTime, keep.type, keep.configID]
            )
            return true
        }
    }

    public func loadHistories(limit: Int = 100) throws -> [History] {
        try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM history ORDER BY createTime DESC LIMIT ?", arguments: [max(limit, 1)]).map(Self.history(from:))
        }
    }

    public func history(key: String) throws -> History? {
        try queue.read { db in
            try Row.fetchOne(db, sql: "SELECT * FROM history WHERE key = ?", arguments: [key]).map(Self.history(from:))
        }
    }

    public func saveHistory(_ history: History) throws {
        try queue.write { db in
            try db.execute(
                sql: """
                INSERT INTO history
                    (key, vodPic, vodName, vodFlag, vodRemarks, episodeUrl, revSort, revPlay, createTime, opening, ending, position, duration, speed, scale, cid)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(key) DO UPDATE SET
                    vodPic = excluded.vodPic,
                    vodName = excluded.vodName,
                    vodFlag = excluded.vodFlag,
                    vodRemarks = excluded.vodRemarks,
                    episodeUrl = excluded.episodeUrl,
                    revSort = excluded.revSort,
                    revPlay = excluded.revPlay,
                    createTime = excluded.createTime,
                    opening = excluded.opening,
                    ending = excluded.ending,
                    position = excluded.position,
                    duration = excluded.duration,
                    speed = excluded.speed,
                    scale = excluded.scale,
                    cid = excluded.cid
                """,
                arguments: [
                    history.key, history.vodPic, history.vodName, history.vodFlag, history.vodRemarks,
                    history.episodeURL, history.reverseSort, history.reversePlay, history.createTime,
                    history.opening, history.ending, history.position, history.duration, history.speed,
                    history.scale, history.configID
                ]
            )
        }
    }

    public func saveTrack(_ track: TrackRecord) throws {
        try queue.write { db in
            try db.execute(
                sql: """
                INSERT INTO track (type, key, name, format, selected)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(key, type) DO UPDATE SET
                    name = excluded.name,
                    format = excluded.format,
                    selected = excluded.selected
                """,
                arguments: [track.type, track.key, track.name, track.format, track.selected]
            )
        }
    }

    private func json<T: Encodable>(_ value: T) throws -> String {
        String(data: try encoder.encode(value), encoding: .utf8) ?? "{}"
    }

    private static func keep(from row: Row) -> Keep {
        Keep(
            key: row["key"],
            siteName: row["siteName"],
            vodName: row["vodName"],
            vodPic: row["vodPic"],
            createTime: row["createTime"],
            type: row["type"],
            configID: row["cid"]
        )
    }

    private static func history(from row: Row) -> History {
        var item = History(key: row["key"], vodName: row["vodName"], vodPic: row["vodPic"])
        item.vodFlag = row["vodFlag"]
        item.vodRemarks = row["vodRemarks"]
        item.episodeURL = row["episodeUrl"]
        item.reverseSort = row["revSort"]
        item.reversePlay = row["revPlay"]
        item.createTime = row["createTime"]
        item.opening = row["opening"]
        item.ending = row["ending"]
        item.position = row["position"]
        item.duration = row["duration"]
        item.speed = row["speed"]
        item.scale = row["scale"]
        item.configID = row["cid"]
        return item
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "config") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("type", .integer).notNull().defaults(to: 0)
                table.column("time", .integer).notNull().defaults(to: 0)
                table.column("url", .text).notNull()
                table.column("json", .text).notNull().defaults(to: "")
                table.column("name", .text).notNull().defaults(to: "")
                table.column("logo", .text).notNull().defaults(to: "")
                table.column("home", .text).notNull().defaults(to: "")
                table.column("parse", .text).notNull().defaults(to: "")
                table.uniqueKey(["url", "type"])
            }
            try db.create(table: "site") { table in
                table.column("key", .text).primaryKey()
                table.column("searchable", .integer).notNull().defaults(to: 1)
                table.column("changeable", .integer).notNull().defaults(to: 1)
                table.column("json", .text).notNull().defaults(to: "")
            }
            try db.create(table: "live") { table in
                table.column("name", .text).primaryKey()
                table.column("boot", .boolean).notNull().defaults(to: false)
                table.column("pass", .boolean).notNull().defaults(to: false)
                table.column("keep", .text).notNull().defaults(to: "")
                table.column("json", .text).notNull().defaults(to: "")
            }
            try db.create(table: "keep") { table in
                table.column("key", .text).primaryKey()
                table.column("siteName", .text).notNull().defaults(to: "")
                table.column("vodName", .text).notNull().defaults(to: "")
                table.column("vodPic", .text).notNull().defaults(to: "")
                table.column("createTime", .integer).notNull().defaults(to: 0)
                table.column("type", .integer).notNull().defaults(to: 0)
                table.column("cid", .integer).notNull().defaults(to: 0)
            }
            try db.create(table: "history") { table in
                table.column("key", .text).primaryKey()
                table.column("vodPic", .text).notNull().defaults(to: "")
                table.column("vodName", .text).notNull().defaults(to: "")
                table.column("vodFlag", .text).notNull().defaults(to: "")
                table.column("vodRemarks", .text).notNull().defaults(to: "")
                table.column("episodeUrl", .text).notNull().defaults(to: "")
                table.column("revSort", .boolean).notNull().defaults(to: false)
                table.column("revPlay", .boolean).notNull().defaults(to: false)
                table.column("createTime", .integer).notNull().defaults(to: 0)
                table.column("opening", .integer).notNull().defaults(to: -1)
                table.column("ending", .integer).notNull().defaults(to: -1)
                table.column("position", .integer).notNull().defaults(to: -1)
                table.column("duration", .integer).notNull().defaults(to: -1)
                table.column("speed", .double).notNull().defaults(to: 1)
                table.column("scale", .integer).notNull().defaults(to: -1)
                table.column("cid", .integer).notNull().defaults(to: 0)
            }
            try db.create(table: "track") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("type", .integer).notNull()
                table.column("key", .text).notNull()
                table.column("name", .text).notNull().defaults(to: "")
                table.column("format", .text).notNull().defaults(to: "")
                table.column("selected", .boolean).notNull().defaults(to: false)
                table.uniqueKey(["key", "type"])
            }
        }
        return migrator
    }
}
