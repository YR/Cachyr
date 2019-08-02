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

    private var storage: Storage

    /**
     Queue used to synchronize access to the cache.
     */
    public var accessQueue: DispatchQueue

    /**
     All asynchronous completion closures are dispatched on this queue.
     */
    public var completionQueue: DispatchQueue

    public init(
        storage: Storage,
        accessQueue: DispatchQueue? = nil,
        completionQueue: DispatchQueue? = nil
    ) {
        self.storage = storage
        self.accessQueue = accessQueue ?? DispatchQueue(label: "no.nrk.cachyr.access", attributes: .concurrent)
        self.completionQueue = completionQueue ?? DispatchQueue(label: "no.nrk.cachyr.completion", attributes: .concurrent)
    }

    public func contains(key: Storage.Key) -> Bool {
        return accessQueue.sync {
            return _contains(key: key)
        }
    }

    public func contains(
        key: Storage.Key,
        completion: @escaping (Bool) -> Void
    ) {
        accessQueue.async {
            let found = self._contains(key: key)
            self.completionQueue.async {
                completion(found)
            }
        }
    }

    /**
     Directly check if value identified by key exists in cache. Not thread-safe.
     */
    private func _contains(key: Storage.Key) -> Bool {
        var exists = storage.attributes(forKey: key) != nil
        if !exists, let parentCache = parentCacheWrapper {
            exists = parentCache.contains(key: key)
        }
        return exists
    }

    public func value(forKey key: Storage.Key) -> Storage.Value? {
        return accessQueue.sync {
            return _value(for: key)
        }
    }

    public func value(
        forKey key: Storage.Key,
        completion: @escaping (Storage.Value?) -> Void
    ) {
        accessQueue.async {
            let value = self._value(for: key)
            self.completionQueue.async {
                completion(value)
            }
        }
    }

    /**
     Common synchronous fetch value function. Not thread-safe.
     */
    private func _value(for key: Storage.Key) -> Storage.Value? {
        var value = storage.value(forKey: key)
        if value == nil, let parentCache = parentCacheWrapper {
            value = parentCache.value(forKey: key)
            if value != nil, let attributes = parentCache.attributes(forKey: key) {
                _setValue(value, for: key, attributes: attributes)
            }
        }
        return value
    }

    public func setValue(
        _ value: Storage.Value?,
        forKey key: Storage.Key,
        attributes: CacheItemAttributes? = nil
    ) {
        accessQueue.sync(flags: .barrier) {
            _setValue(value, for: key, attributes: attributes)
        }
    }

    public func setValue(
        _ value: Storage.Value?,
        forKey key: Storage.Key,
        attributes: CacheItemAttributes? = nil,
        completion: @escaping () -> Void
    ) {
        accessQueue.async(flags: .barrier) {
            self._setValue(value, for: key, attributes: attributes)
            self.completionQueue.async {
                completion()
            }
        }
    }

    /**
     Common value setter. Not thread-safe.
     */
    private func _setValue(
        _ value: Storage.Value?,
        for key: Storage.Key,
        attributes: CacheItemAttributes?
    ) {
        storage.setValue(value, forKey: key, attributes: attributes)
    }

    public func attributes(forKey key: Storage.Key) -> CacheItemAttributes? {
        return accessQueue.sync {
            return _attributes(for: key)
        }
    }

    public func attributes(
        forKey key: Storage.Key,
        completion: @escaping (CacheItemAttributes?) -> Void
    ) {
        accessQueue.async {
            let attributes = self._attributes(for: key)
            self.completionQueue.async {
                completion(attributes)
            }
        }
    }

    private func _attributes(for key: Storage.Key) -> CacheItemAttributes? {
        var attributes = storage.attributes(forKey: key)
        if attributes == nil, let parentCache = parentCacheWrapper {
            attributes = parentCache.attributes(forKey: key)
        }
        return attributes
    }

    public func setAttributes(
        _ attributes: CacheItemAttributes,
        forKey key: Storage.Key
    ) {
        accessQueue.sync {
            _setAttributes(attributes, for: key)
        }
    }

    public func setAttributes(
        _ attributes: CacheItemAttributes,
        forKey key: Storage.Key,
        completion: @escaping () -> Void
    ) {
        accessQueue.async {
            self._setAttributes(attributes, for: key)
            self.completionQueue.async {
                completion()
            }
        }
    }

    private func _setAttributes(
        _ attributes: CacheItemAttributes,
        for key: Storage.Key
    ) {
        storage.setAttributes(attributes, forKey: key)
    }

    public func removeAll() {
        accessQueue.sync(flags: .barrier) {
            _removeAll()
        }
    }

    public func removeAll(_ completion: @escaping () -> Void) {
        accessQueue.async(flags: .barrier) {
            self._removeAll()
            self.completionQueue.async {
                completion()
            }
        }
    }

    /**
     Private common remove all function. Not thread-safe.
     */
    private func _removeAll() {
        storage.removeAll()
    }

    public func remove(where predicate: @escaping (CacheItemAttributes) -> Bool) {
        accessQueue.sync(flags: .barrier) {
            _remove(where: predicate)
        }
    }

    public func remove(
        where predicate: @escaping (CacheItemAttributes) -> Bool,
        completion: @escaping () -> Void
    ) {
        accessQueue.async(flags: .barrier) {
            self._remove(where: predicate)
            self.completionQueue.async {
                completion()
            }
        }
    }

    /**
     Private common function that removes values where predicate is true. Not thread-safe.
     */
    private func _remove(where predicate: @escaping (CacheItemAttributes) -> Bool) {
        for (key, attributes) in storage.allAttributes {
            guard predicate(attributes) else { continue }
            storage.removeValue(forKey: key)
        }
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
