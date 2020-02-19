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

public enum CacheTarget {
    case child
    case parent
}

/**
 Generic cache backed by user-defined storage.
 */
public final class Cache<Storage: CacheStorage>: CacheAPI {

    private let lock = ReadWriteLock()

    private var storage: Storage

    public init(storage: Storage) {
        self.storage = storage
    }

    public func contains(key: Storage.Key) -> Bool {
        lock.readLock()
        var foundAttributes = storage.attributes(forKey: key)
        lock.unlock()
        if foundAttributes == nil, let parentCache = parentCacheWrapper {
            foundAttributes = parentCache.attributes(forKey: key)
        }
        if let attributes = foundAttributes {
            return !attributes.shouldBeRemoved
        }
        return false
    }

    public func value(forKey key: Storage.Key) -> Storage.Value? {
        lock.readLock()
        var maybeValue = storage.value(forKey: key)
        var maybeAttributes = storage.attributes(forKey: key)
        lock.unlock()

        if maybeValue == nil, let parentCache = parentCacheWrapper {
            CacheLog.verbose("Looking for '\(key)' in parent")
            maybeAttributes = parentCache.attributes(forKey: key)
            maybeValue = parentCache.value(forKey: key)
            if maybeValue != nil, let attributes = maybeAttributes {
                // Got value and attributes from parent
                if attributes.shouldBeRemoved {
                    // But it's scheduled for removal
                    CacheLog.verbose("Found '\(key)' in parent but item is scheduled for removal")
                    maybeAttributes = nil
                    maybeValue = nil
                } else {
                    // Update storage with value from parent but not if it has been updated
                    // in the meantime
                    lock.writeLock()
                    let updatedAttributes = storage.attributes(forKey: key)
                    if let attributes = updatedAttributes, !attributes.shouldBeRemoved {
                        CacheLog.verbose("Found '\(key)' in parent but item has been updated in local storage")
                        maybeAttributes = updatedAttributes
                        maybeValue = storage.value(forKey: key)
                    } else {
                        CacheLog.verbose("Found '\(key)' in parent, updating local storage")
                        storage.setValue(maybeValue, forKey: key, attributes: maybeAttributes)
                    }
                    lock.unlock()
                }
            } else {
                // Fetching value and attributes from parent isn't atomic
                // so nil both if one is missing
                CacheLog.verbose("Value for '\(key)' not found in parent")
                maybeAttributes = nil
                maybeValue = nil
            }
        }

        if let attributes = maybeAttributes, attributes.shouldBeRemoved {
            lock.writeLock()
            // Check if value was updated after read unlock
            maybeAttributes = storage.attributes(forKey: key)
            maybeValue = nil
            if let attributes = maybeAttributes, !attributes.shouldBeRemoved {
                maybeValue = storage.value(forKey: key)
            } else {
                storage.setValue(nil, forKey: key)
            }
            lock.unlock()
        }

        return maybeValue
    }

    public func setValue(
        _ value: Storage.Value?,
        forKey key: Storage.Key,
        attributes: CacheItemAttributes? = nil
    ) {
        lock.writeLock()
        storage.setValue(value, forKey: key, attributes: attributes)
        lock.unlock()
    }

    public func attributes(forKey key: Storage.Key) -> CacheItemAttributes? {
        lock.readLock()
        var attributes = storage.attributes(forKey: key)
        lock.unlock()
        if attributes == nil, let parentCache = parentCacheWrapper {
            attributes = parentCache.attributes(forKey: key)
        }
        return attributes
    }

    public func setAttributes(
        _ attributes: CacheItemAttributes,
        forKey key: Storage.Key
    ) {
        lock.writeLock()
        storage.setAttributes(attributes, forKey: key)
        lock.unlock()
    }

    public func removeAll() {
        lock.writeLock()
        storage.removeAll()
        lock.unlock()
    }

    public func remove(where predicate: @escaping (CacheItemAttributes) -> Bool) {
        lock.writeLock()
        for (key, attributes) in storage.allAttributes {
            guard predicate(attributes) else { continue }
            storage.removeValue(forKey: key)
        }
        lock.unlock()
    }

    // MARK: - Cache linking

    public var childCacheWrapper: CacheWrapper<Cache<Storage>>?

    public var parentCacheWrapper: CacheWrapper<Cache<Storage>>?

    public func setCache<OtherStorage>(
        _ otherCache: Cache<OtherStorage>,
        as target: CacheTarget,
        keyTransformer: Transformer<Storage.Key, OtherStorage.Key>,
        valueTransformer: Transformer<Storage.Value, OtherStorage.Value>
    ) {
        switch target {
        case .child:
            childCacheWrapper = CacheWrapper<Cache<Storage>>(
                otherCache: otherCache,
                keyTransformer: keyTransformer,
                valueTransformer: valueTransformer
            )

            otherCache.parentCacheWrapper = CacheWrapper<Cache<OtherStorage>>(
                otherCache: self,
                keyTransformer: keyTransformer.reversed(),
                valueTransformer: valueTransformer.reversed()
            )
        case .parent:
            parentCacheWrapper = CacheWrapper<Cache<Storage>>(
                otherCache: otherCache,
                keyTransformer: keyTransformer,
                valueTransformer: valueTransformer
            )

            otherCache.childCacheWrapper = CacheWrapper<Cache<OtherStorage>>(
                otherCache: self,
                keyTransformer: keyTransformer.reversed(),
                valueTransformer: valueTransformer.reversed()
            )
        }
    }
}
