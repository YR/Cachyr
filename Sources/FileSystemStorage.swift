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

public final class FileSystemStorage<Key: Hashable & Codable, Value: Codable>: CacheStorage {

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
     Queue used to synchronize disk cache access. The cache allows concurrent reads
     but only serial writes using barriers.
     */
    private let queue: DispatchQueue

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
        do {
            try FileManager.default.createDirectory(at: _url, withIntermediateDirectories: true, attributes: nil)
        } catch {
            CacheLog.error("Unable to create \(_url.path):\n\(error)")
            return nil
        }
        return _url
    }

    /**
     URL of DB file with metadata for all cache items.
     */
    private var dbFileURL: URL

    /**
     The number of bytes used by the contents of the cache.
     */
    public var storageSize: Int {
        return queue.sync {
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
                CacheLog.error("\(error)")
            }

            return size
        }
    }

    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
        return decoder
    }()

    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
        return encoder
    }()

    public init?(name: String = "no.nrk.cachyr.FileSystemStorage", baseURL: URL? = nil) {
        self.name = name

        let fm = FileManager.default

        if let baseURL = baseURL {
            _url = baseURL.appendingPathComponent(name, isDirectory: true)
        } else {
            do {
                let cachesURL = try fm.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                _url = cachesURL.appendingPathComponent(name, isDirectory: true)
            } catch {
                CacheLog.error(error)
                return nil
            }
        }

        do {
            let appSupportName = "no.nrk.cachyr"
            let appSupportURL = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let appURL = appSupportURL.appendingPathComponent(appSupportName, isDirectory: true)
            try fm.createDirectory(at: appURL, withIntermediateDirectories: true)
            dbFileURL = appURL.appendingPathComponent("\(name).json", isDirectory: false)
        } catch {
            CacheLog.error(error)
            return nil
        }

        self.queue = DispatchQueue(label: "\(name).queue", attributes: .concurrent)

        // Ensure URL path exists or can be created
        guard let _ = self.url else {
            CacheLog.error("Unable to access \(_url.absoluteString)")
            return nil
        }

        CacheLog.info("Using storage at \(_url.absoluteString)")
        CacheLog.info("Using DB at \(dbFileURL.absoluteString)")
        loadStorageKeyMap()
    }

    deinit {
        saveDB()
    }

    public var allKeys: AnySequence<Key> {
        return queue.sync {
            return AnySequence(storageKeyMap.keys)
        }
    }

    public var allAttributes: AnySequence<(Key, CacheItemAttributes)> {
        return queue.sync {
            return AnySequence(storageKeyMap.map { ($0.key, $0.value.attributes) })
        }
    }

    public func value(forKey key: Key) -> Value? {
        return queue.sync {
            guard let data = self.data(for: key) else {
                CacheLog.verbose("No data found for key '\(key)'")
                return nil
            }

            if Value.self == Data.self {
                CacheLog.verbose("Found data for key '\(key)'")
                return data as? Value
            }

            do {
                let wrapper = try jsonDecoder.decode([Value].self, from: data)
                if let wrappedValue = wrapper.first {
                    CacheLog.verbose("Found wrapped value for key '\(key)'")
                    return wrappedValue
                } else {
                    CacheLog.error("Wrapped value missing")
                    return nil
                }
            } catch {
                CacheLog.error(error)
                return nil
            }
        }
    }

    public func setValue(_ value: Value?, forKey key: Key, attributes: CacheItemAttributes?) {
        queue.sync(flags: .barrier) {
            guard let value = value else {
                CacheLog.verbose("Removing value for key '\(key)'")
                removeFile(for: key)
                return
            }

            let data: Data
            if let alreadyData = value as? Data {
                data = alreadyData
            } else {
                // JSONEncoder and PropertyListEncoder do not currently support top-level fragments
                // which means values like a plain Int cannot be encoded, so wrap all non-data
                // values in an array.
                do {
                    data = try jsonEncoder.encode([value])
                } catch {
                    CacheLog.error(error)
                    return
                }
            }
            let attributes = attributes ?? CacheItemAttributes()
            CacheLog.verbose("Setting value for key '\(key)' with attributes: \(attributes)")
            addFile(for: key, data: data, attributes: attributes)
        }
    }

    public func attributes(forKey key: Key) -> CacheItemAttributes? {
        return queue.sync {
            return storageKeyMap[key]?.attributes
        }
    }

    public func setAttributes(_ attributes: CacheItemAttributes, forKey key: Key) {
        queue.sync(flags: .barrier) {
            storageKeyMap[key]?.attributes = attributes
            saveDBAfterInterval()
        }
    }

    public func removeAll() {
        queue.sync(flags: .barrier) {
            storageKeyMap.removeAll()
            saveDB()
            guard let cacheURL = self.url else {
                return
            }
            do {
                try FileManager.default.removeItem(at: cacheURL)
            }
            catch let error {
                CacheLog.error(error.localizedDescription)
            }
        }
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

        if item.attributes.shouldBeRemoved {
            queue.async(flags: .barrier) {
                // Check for item update while removal was scheduled
                guard let item = self.storageKeyMap[key], item.attributes.shouldBeRemoved else {
                    return
                }
                self.removeFile(for: key)
            }
            return nil
        }

        return FileManager.default.contents(atPath: fileURL.path)
    }

    private func filesInCache(properties: [URLResourceKey]? = [.nameKey]) -> [URL] {
        guard let url = self.url else {
            return []
        }

        do {
            let fm = FileManager.default
            let files = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: properties, options: [.skipsHiddenFiles])
            return files
        } catch {
            CacheLog.error("\(error)")
            return []
        }
    }

    private func addFile(for key: Key, data: Data, attributes: CacheItemAttributes) {
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
            CacheLog.error("Unable to create file for \(key)")
            removeFile(for: key)
            return
        }

        saveDBAfterInterval()
    }

    private func removeFile(for key: Key) {
        if let fileURL = fileURL(forKey: key) {
            removeFile(at: fileURL)
        }
        storageKeyMap[key] = nil
        saveDBAfterInterval()
    }

    private func removeFile(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        }
        catch let error {
            CacheLog.error(error.localizedDescription)
        }
    }

    /**
     Reset storage key map and load all keys from files in cache.
     */
    private func loadStorageKeyMap() {
        loadDB()

        validateDB()

        saveDB()
    }

    private func loadDB() {
        let fm = FileManager.default
        guard let data = fm.contents(atPath: dbFileURL.path) else {
            return
        }
        let decoder = JSONDecoder()
        do {
            storageKeyMap = try decoder.decode([Key: FileAttributes].self, from: data)
        } catch {
            CacheLog.error(error)
            return
        }
        CacheLog.info("DB loaded")
    }

    private var lastDBSaveDate = Date(timeIntervalSince1970: 0)

    private func saveDB() {
        let fm = FileManager.default
        let encoder = JSONEncoder()

        do {
            let data = try encoder.encode(storageKeyMap)
            if fm.createFile(atPath: dbFileURL.path, contents: data, attributes: nil) {
                lastDBSaveDate = Date()
            }

            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try dbFileURL.setResourceValues(resourceValues)
            CacheLog.verbose("DB saved")
        } catch {
            CacheLog.error(error)
            return
        }
    }

    private var lastDBSaveTriggeredDate = Date(timeIntervalSince1970: 0)

    private let maxDBSaveInterval: TimeInterval = 5.0

    private func saveDBAfterInterval(_ interval: TimeInterval = 2.0) {
        let triggerDate = Date()
        lastDBSaveTriggeredDate = triggerDate
        queue.asyncAfter(deadline: .now() + interval, flags: .barrier) {
            let latestDate = self.lastDBSaveDate.addingTimeInterval(self.maxDBSaveInterval)
            let now = Date()
            if now >= latestDate || self.lastDBSaveTriggeredDate == triggerDate {
                self.saveDB()
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
                CacheLog.info("No file found, removing '\(key)' from DB")
                removeFile(for: key)
                continue
            }
        }

        // Make sure each file has a corresponding item
        let items = storageKeyMap.values
        for fileURL in filesInCache() {
            let fileName = fileURL.lastPathComponent
            if items.contains(where: { $0.name == fileName }) {
                continue
            }
            CacheLog.info("No item found, removing \(fileURL.absoluteString)")
            try? fm.removeItem(at: fileURL)
        }

        CacheLog.info("DB validated")
    }
}
