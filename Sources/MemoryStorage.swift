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

public final class MemoryStorage<Key: Hashable, Value>: CacheStorage {

    private struct Item {
        var attributes: CacheItemAttributes
        let value: Value
    }

    private var items: [Key: Item] = [:]

    private let memoryPressureSource: DispatchSourceMemoryPressure

    public init() {
        self.memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: .critical)
        memoryPressureSource.setEventHandler { [weak self] in
            self?.removeAll()
        }
        memoryPressureSource.activate()
    }

    // MARK: - CacheStorage

    public var allKeys: AnySequence<Key> {
        return AnySequence(items.keys)
    }

    public var allAttributes: AnySequence<(Key, CacheItemAttributes)> {
        return AnySequence(items.map { ($0.key, $0.value.attributes) })
    }

    public func value(forKey key: Key) -> Value? {
        if let item = items[key] {
            CacheLog.verbose("Value found for '\(key)'")
            return item.value
        }

        CacheLog.verbose("Value not found for '\(key)'")
        return nil
    }

    public func setValue(_ value: Value?, forKey key: Key, attributes: CacheItemAttributes?) {
        guard let value = value else {
            CacheLog.verbose("Removing value for '\(key)'")
            items[key] = nil
            return
        }

        let finalAttributes = attributes ?? CacheItemAttributes()
        CacheLog.verbose("Setting value for '\(key)' with attributes: \(finalAttributes)")
        items[key] = Item(attributes: finalAttributes, value: value)
    }

    public func attributes(forKey key: Key) -> CacheItemAttributes? {
        return items[key]?.attributes
    }

    public func setAttributes(_ attributes: CacheItemAttributes, forKey key: Key) {
        guard self.items[key] != nil else {
            return
        }
        self.items[key]!.attributes = attributes
    }

    public func removeAll() {
        items.removeAll()
    }
}
