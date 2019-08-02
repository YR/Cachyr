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

public protocol CacheStorage {
    associatedtype Key
    associatedtype Value

    var allKeys: AnySequence<Key> { get }

    var allAttributes: AnySequence<(Key, CacheItemAttributes)> { get }

    func value(forKey key: Key) -> Value?

    mutating func setValue(_ value: Value?, forKey key: Key, attributes: CacheItemAttributes?)

    func attributes(forKey key: Key) -> CacheItemAttributes?

    mutating func setAttributes(_ attributes: CacheItemAttributes, forKey key: Key)

    mutating func removeAll()
}

public extension CacheStorage {
    mutating func setValue(_ value: Value?, forKey key: Key) {
        setValue(value, forKey: key, attributes: nil)
    }

    mutating func removeValue(forKey key: Key) {
        setValue(nil, forKey: key, attributes: nil)
    }

    func expirationDate(forKey key: Key) -> Date? {
        return attributes(forKey: key)?.expirationDate
    }

    func removalDate(forKey key: Key) -> Date? {
        return attributes(forKey: key)?.removalDate
    }
}
