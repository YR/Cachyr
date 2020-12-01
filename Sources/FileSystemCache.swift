/**
 *  Cachyr
 *
 *  Copyright (c) 2020 NRK. Licensed under the MIT license, as follows:
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in all
 *  copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 *  SOFTWARE.
 */

import Foundation

open class FileSystemCache<Key: Hashable & Codable, Value: Codable>: CacheAPI {

    private struct FileAttributes: Codable {
        let name: String
        var attributes: CacheItemAttributes
    }

    /**
     Name of cache. Must be unique to separate different caches.
     Reverse domain notation, like no.nrk.yr.cache, is a good choice.
     */
    public let name: String

    /**
     Metadata and storage name for keys.
     */
    private var storageKeyMap = [Key: FileAttributes]()

    /**
     Storage for the url property.
     */
    private let _url: URL

    /**
     URL of cache directory, of the form: `baseURL/name`
     */
    public var url: URL? {
        return try? createCacheDirectory()
    }

    /**
     URL of DB file with metadata for all cache items.
     */
    private var dbFileURL: URL

    /**
     The number of bytes used by the contents of the cache.
     */
    public var storageSize: Int {
        guard let url = self.url else {
            return 0
        }

        let fm = FileManager.default
        var size = 0

        do {
            let files = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey])
            size = files.reduce(0, { (totalSize, url) -> Int in
                let attributes = (try? fm.attributesOfItem(atPath: url.path)) ?? [:]
                let fileSize = (attributes[.size] as? NSNumber)?.intValue ?? 0
                return totalSize + fileSize
            })
        } catch {
            return 0
        }

        return size
    }

    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "inf",
            negativeInfinity: "-inf",
            nan: "nan"
        )
        return decoder
    }()

    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "inf",
            negativeInfinity: "-inf",
            nan: "nan"
        )
        return encoder
    }()

    public init(name: String = "no.nrk.cachyr.FileSystemCache", baseURL: URL? = nil) throws {
        self.name = name

        let fm = FileManager.default

        if let baseURL = baseURL {
            _url = baseURL.appendingPathComponent(name, isDirectory: true)
        } else {
            let cachesURL = try fm.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            _url = cachesURL.appendingPathComponent(name, isDirectory: true)
        }

        let appSupportName = "no.nrk.cachyr"
        let appSupportURL = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let appURL = appSupportURL.appendingPathComponent(appSupportName, isDirectory: true)
        try fm.createDirectory(at: appURL, withIntermediateDirectories: true)
        dbFileURL = appURL.appendingPathComponent("\(name).json", isDirectory: false)

        // Ensure URL path exists or can be created
        _ = try createCacheDirectory()
        try loadStorageKeyMap()
    }

    deinit {
        try? saveDB()
    }

    // MARK: - CacheAPI

    public func contains(key: Key) -> Bool {
        guard let attribs = storageKeyMap[key]?.attributes else {
            return false
        }
        return !attribs.hasExpired
    }

    public func value(forKey key: Key) throws -> Value? {
        guard
            let attribs = try attributes(forKey: key),
            !attribs.hasExpired,
            let data = self.data(for: key)
        else {
            return nil
        }

        if Value.self == Data.self {
            return data as? Value
        }

        let wrapper = try jsonDecoder.decode([Value].self, from: data)
        return wrapper.first
    }

    public func setValue(
        _ value: Value,
        forKey key: Key,
        attributes: CacheItemAttributes? = nil
    ) throws {
        let data: Data
        if let alreadyData = value as? Data {
            data = alreadyData
        } else {
            // JSONEncoder and PropertyListEncoder do not currently support top-level fragments
            // which means values like a plain Int cannot be encoded, so wrap all non-data
            // values in an array.
            data = try jsonEncoder.encode([value])
        }
        let attributes = attributes ?? CacheItemAttributes()
        try addFile(for: key, data: data, attributes: attributes)
    }

    public func removeValue(forKey key: Key) throws {
        try removeFile(for: key)
    }

    public func removeAll() throws {
        storageKeyMap.removeAll()
        try saveDB()
        guard let cacheURL = self.url else {
            return
        }
        try FileManager.default.removeItem(at: cacheURL)
    }

    public func remove(where predicate: @escaping (CacheItemAttributes) -> Bool) throws {
        for (key, fileAttributes) in storageKeyMap {
            guard predicate(fileAttributes.attributes) else { continue }
            try removeFile(for: key)
        }
    }

    public func attributes(forKey key: Key) throws -> CacheItemAttributes? {
        guard let attribs = storageKeyMap[key]?.attributes else {
            return nil
        }
        return attribs.hasExpired ? nil : attribs
    }

    public func setAttributes(_ attributes: CacheItemAttributes, forKey key: Key) throws {
        storageKeyMap[key]?.attributes = attributes
        saveDBAfterInterval()
    }

    // MARK: - Private

    private func createCacheDirectory() throws -> URL {
        try FileManager.default.createDirectory(at: _url, withIntermediateDirectories: true, attributes: nil)
        return _url
    }

    private func fileURL(forItem item: FileAttributes) -> URL? {
        return fileURL(forName: item.name)
    }

    func fileURL(forKey key: Key) -> URL? {
        guard let item = storageKeyMap[key] else { return nil }
        return fileURL(forItem: item)
    }

    func fileURL(forName name: String) -> URL? {
        guard let url = self.url else { return nil }
        return url.appendingPathComponent(name, isDirectory: false)
    }

    private func data(for key: Key) -> Data? {
        guard
            let item = storageKeyMap[key],
            let fileURL = fileURL(forItem: item)
        else {
            return nil
        }

        return FileManager.default.contents(atPath: fileURL.path)
    }

    private func filesInCache(properties: [URLResourceKey]? = [.nameKey]) throws -> [URL] {
        guard let url = self.url else {
            return []
        }

        let fm = FileManager.default
        let files = try fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: properties,
            options: [.skipsHiddenFiles]
        )
        return files
    }

    private func addFile(for key: Key, data: Data, attributes: CacheItemAttributes) throws {
        let cacheItem: FileAttributes

        if let existingItem = storageKeyMap[key] {
            cacheItem = existingItem
            storageKeyMap[key]!.attributes = attributes
        } else {
            cacheItem = FileAttributes(name: UUID().uuidString, attributes: attributes)
            storageKeyMap[key] = cacheItem
        }

        let fm = FileManager.default

        guard
            let fileURL = self.fileURL(forItem: cacheItem),
            fm.createFile(atPath: fileURL.path, contents: data, attributes: nil)
        else {
            try removeFile(for: key)
            return
        }

        saveDBAfterInterval()
    }

    private func removeFile(for key: Key) throws {
        if let fileURL = fileURL(forKey: key) {
            try removeFile(at: fileURL)
        }
        storageKeyMap[key] = nil
        saveDBAfterInterval()
    }

    private func removeFile(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    private func loadStorageKeyMap() throws {
        try loadDB()

        validateDB()

        try saveDB()
    }

    private func loadDB() throws {
        let fm = FileManager.default
        guard let data = fm.contents(atPath: dbFileURL.path) else {
            return
        }
        let decoder = JSONDecoder()
        storageKeyMap = try decoder.decode([Key: FileAttributes].self, from: data)
    }

    private var lastDBSaveDate = Date(timeIntervalSince1970: 0)

    private func saveDB() throws {
        let fm = FileManager.default
        let encoder = JSONEncoder()

        let data = try encoder.encode(storageKeyMap)
        if fm.createFile(atPath: dbFileURL.path, contents: data, attributes: nil) {
            lastDBSaveDate = Date()
        }

        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try dbFileURL.setResourceValues(resourceValues)
    }

    private var lastDBSaveTriggeredDate = Date(timeIntervalSince1970: 0)

    private let maxDBSaveInterval: TimeInterval = 5.0

    private func saveDBAfterInterval(_ interval: TimeInterval = 2.0) {
        let triggerDate = Date()
        lastDBSaveTriggeredDate = triggerDate
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            let latestDate = self.lastDBSaveDate.addingTimeInterval(self.maxDBSaveInterval)
            let now = Date()
            if now >= latestDate || self.lastDBSaveTriggeredDate == triggerDate {
                try? self.saveDB()
            }
        }
    }

    private func validateDB() {
        let fm = FileManager.default

        // Make sure each item has a corresponding file
        for (key, item) in storageKeyMap {
            guard
                !item.attributes.shouldBeRemoved,
                let fileURL = fileURL(forItem: item),
                fm.fileExists(atPath: fileURL.path)
            else {
                try? removeFile(for: key)
                continue
            }
        }

        // Make sure each file has a corresponding item
        let items = storageKeyMap.values
        let files = (try? filesInCache()) ?? []
        for fileURL in files {
            let fileName = fileURL.lastPathComponent
            if items.contains(where: { $0.name == fileName }) {
                continue
            }
            try? fm.removeItem(at: fileURL)
        }
    }
}
