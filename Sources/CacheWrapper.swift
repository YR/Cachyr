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

public final class CacheWrapper<Cache: CacheAPI>: CacheAPI {

    public init<OtherCache: CacheAPI>(
        otherCache: OtherCache,
        keyTransformer: Transformer<Cache.Key, OtherCache.Key>,
        valueTransformer: Transformer<Cache.Value, OtherCache.Value>
    ) {
        self.containsForKey = { key in
            guard let otherKey = keyTransformer.transform(key) else { return false }
            return otherCache.contains(key: otherKey)
        }

        self.valueForKey = { key in
            guard let otherKey = keyTransformer.transform(key) else { return nil }
            if let otherValue = otherCache.value(forKey: otherKey) {
                return valueTransformer.reverseTransform(otherValue)
            } else {
                return nil
            }
        }

        self.setValueForKey = { value, key, attributes in
            guard let otherKey = keyTransformer.transform(key) else { return }
            if value == nil {
                otherCache.setValue(nil, forKey: otherKey, attributes: attributes)
            } else if let value = value, let otherValue = valueTransformer.transform(value) {
                otherCache.setValue(otherValue, forKey: otherKey, attributes: attributes)
            }
        }

        self.attributesForKey = { key in
            guard let otherKey = keyTransformer.transform(key) else { return nil }
            return otherCache.attributes(forKey: otherKey)
        }

        self.setAttributesForKey = { attributes, key in
            guard let otherKey = keyTransformer.transform(key) else { return }
            otherCache.setAttributes(attributes, forKey: otherKey)
        }

        self.removeAllInOther = {
            otherCache.removeAll()
        }

        self.removeWhere = { predicate in
            otherCache.remove(where: predicate)
        }
    }

    // MARK: - CacheAPI

    private let containsForKey: (Cache.Key) -> Bool

    public func contains(key: Cache.Key) -> Bool {
        return containsForKey(key)
    }

    private let valueForKey: (Cache.Key) -> Cache.Value?

    public func value(forKey key: Cache.Key) -> Cache.Value? {
        return valueForKey(key)
    }

    private let setValueForKey: (Cache.Value?, Cache.Key, CacheItemAttributes?) -> Void

    public func setValue(_ value: Cache.Value?, forKey key: Cache.Key, attributes: CacheItemAttributes?) {
        setValueForKey(value, key, attributes)
    }

    private let attributesForKey: (Cache.Key) -> CacheItemAttributes?

    public func attributes(forKey key: Cache.Key) -> CacheItemAttributes? {
        return attributesForKey(key)
    }

    private let setAttributesForKey: (CacheItemAttributes, Cache.Key) -> Void

    public func setAttributes(_ attributes: CacheItemAttributes, forKey key: Cache.Key) {
        setAttributesForKey(attributes, key)
    }

    private let removeAllInOther: () -> Void

    public func removeAll() {
        removeAllInOther()
    }

    private let removeWhere: (@escaping (CacheItemAttributes) -> Bool) -> Void

    public func remove(where predicate: @escaping (CacheItemAttributes) -> Bool) {
        removeWhere(predicate)
    }

}
