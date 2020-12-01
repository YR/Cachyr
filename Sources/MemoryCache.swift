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

open class MemoryCache<Key: Hashable, Value>: CacheAPI {

    /// Indicate if cache should be cleared when a memory pressure notification is received.
    public var clearOnMemoryPressure: Bool {
        didSet {
            if clearOnMemoryPressure {
                memoryPressureSource.resume()
            } else {
                memoryPressureSource.suspend()
            }
        }
    }

    private struct Item {
        var attributes: CacheItemAttributes
        let value: Value
    }

    private var items: [Key: Item] = [:]

    private let memoryPressureSource: DispatchSourceMemoryPressure

    public init(clearOnMemoryPressure: Bool = true) {
        self.clearOnMemoryPressure = clearOnMemoryPressure
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: .critical)
        memoryPressureSource.setEventHandler { [weak self] in
            try? self?.removeAll()
        }
        memoryPressureSource.activate()
        if !clearOnMemoryPressure {
            memoryPressureSource.suspend()
        }
    }

    // MARK: - CacheAPI

    public func contains(key: Key) -> Bool {
        return (try? attributes(forKey: key)) != nil
    }

    public func value(forKey key: Key) throws -> Value? {
        guard let item = items[key] else {
            return nil
        }
        return item.attributes.hasExpired ? nil : item.value
    }

    public func setValue(
        _ value: Value,
        forKey key: Key,
        attributes: CacheItemAttributes? = nil
    ) throws {
        let attributes = attributes ?? CacheItemAttributes()
        items[key] = Item(attributes: attributes, value: value)
    }

    public func removeValue(forKey key: Key) throws {
        items[key] = nil
    }

    public func removeAll() throws {
        items.removeAll()
    }

    public func remove(where predicate: @escaping (CacheItemAttributes) -> Bool) throws {
        for (key, item) in items {
            guard predicate(item.attributes) else { continue }
            items[key] = nil
        }
    }

    public func attributes(forKey key: Key) throws -> CacheItemAttributes? {
        guard let attribs = items[key]?.attributes, !attribs.hasExpired else {
            return nil
        }
        return attribs
    }

    public func setAttributes(_ attributes: CacheItemAttributes, forKey key: Key) throws {
        items[key]?.attributes = attributes
    }
}
