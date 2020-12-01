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

/**
 Cache which looks for value first in primary cache then in secondary.
 Useful for chaining caches, like having a memory cache in front of a disk cache.
 */
open class CombinedCache<PrimaryCache: CacheAPI, SecondaryCache: CacheAPI>: CacheAPI {

    public let primaryCache: PrimaryCache

    public let secondaryCache: SecondaryCache

    private let keyTransform: (PrimaryCache.Key) -> SecondaryCache.Key

    private let primaryValueTransform: (PrimaryCache.Value) -> SecondaryCache.Value

    private let secondaryValueTransform: (SecondaryCache.Value) -> PrimaryCache.Value

    public init(
        primary: PrimaryCache,
        secondary: SecondaryCache,
        keyTransform: @escaping (PrimaryCache.Key) -> SecondaryCache.Key,
        primaryValueTransform: @escaping (PrimaryCache.Value) -> SecondaryCache.Value,
        secondaryValueTransform: @escaping (SecondaryCache.Value) -> PrimaryCache.Value
    ) {
        self.primaryCache = primary
        self.secondaryCache = secondary
        self.keyTransform = keyTransform
        self.primaryValueTransform = primaryValueTransform
        self.secondaryValueTransform = secondaryValueTransform
    }

    // MARK: - CacheAPI

    public func contains(key: PrimaryCache.Key) -> Bool {
        if primaryCache.contains(key: key) {
            return true
        }
        let secondaryKey = keyTransform(key)
        return secondaryCache.contains(key: secondaryKey)
    }

    public func value(forKey key: PrimaryCache.Key) throws -> PrimaryCache.Value? {
        // Check for value in primary cache
        if let value = try primaryCache.value(forKey: key) {
            return value
        }

        // Not in primary cache, check secondary cache
        let secondaryKey = keyTransform(key)
        guard
            let attributes = try secondaryCache.attributes(forKey: secondaryKey),
            let secondaryValue = try secondaryCache.value(forKey: secondaryKey)
        else {
            return nil
        }

        // Found value in secondary cache, add it to primary cache and return it
        let value = secondaryValueTransform(secondaryValue)
        try primaryCache.setValue(value, forKey: key, attributes: attributes)

        return value
    }

    public func setValue(
        _ value: PrimaryCache.Value,
        forKey key: PrimaryCache.Key,
        attributes: CacheItemAttributes? = nil
    ) throws {
        try primaryCache.setValue(value, forKey: key, attributes: attributes)
        let secondaryKey = keyTransform(key)
        let secondaryValue = primaryValueTransform(value)
        try secondaryCache.setValue(secondaryValue, forKey: secondaryKey, attributes: attributes)
    }

    public func removeValue(forKey key: Key) throws {
        try primaryCache.removeValue(forKey: key)
        let secondaryKey = keyTransform(key)
        try secondaryCache.removeValue(forKey: secondaryKey)
    }

    public func removeAll() throws {
        try primaryCache.removeAll()
        try secondaryCache.removeAll()
    }

    public func remove(where predicate: @escaping (CacheItemAttributes) -> Bool) throws {
        try primaryCache.remove(where: predicate)
        try secondaryCache.remove(where: predicate)
    }

    public func attributes(forKey key: PrimaryCache.Key) throws -> CacheItemAttributes? {
        if let attributes = try primaryCache.attributes(forKey: key) {
            return attributes
        }
        let secondaryKey = keyTransform(key)
        let attributes = try secondaryCache.attributes(forKey: secondaryKey)
        return attributes
    }

    public func setAttributes(
        _ attributes: CacheItemAttributes,
        forKey key: PrimaryCache.Key
    ) throws {
        try primaryCache.setAttributes(attributes, forKey: key)
        let secondaryKey = keyTransform(key)
        try secondaryCache.setAttributes(attributes, forKey: secondaryKey)
    }
}
