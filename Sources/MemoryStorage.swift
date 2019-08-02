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

    private let queue = DispatchQueue(label: "MemoryStorage.queue", attributes: .concurrent)

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
        return queue.sync {
            return AnySequence(items.keys)
        }
    }

    public var allAttributes: AnySequence<(Key, CacheItemAttributes)> {
        return queue.sync {
            return AnySequence(items.map { ($0.key, $0.value.attributes) })
        }
    }

    public func value(forKey key: Key) -> Value? {
        return queue.sync {
            guard let item = self.items[key] else {
                CacheLog.verbose("Value not found for '\(key)'")
                return nil
            }

            if item.attributes.shouldBeRemoved {
                queue.async(flags: .barrier) {
                    // Check if item attributes have been updated while removal was scheduled
                    guard let item = self.items[key], item.attributes.shouldBeRemoved else {
                        return
                    }
                    CacheLog.verbose("Removing expired value for '\(key)'")
                    self.items[key] = nil
                }
                return nil
            }

            CacheLog.verbose("Value found for '\(key)'")
            return item.value
        }
    }

    public func setValue(_ value: Value?, forKey key: Key, attributes: CacheItemAttributes?) {
        queue.sync(flags: .barrier) {
            guard let value = value else {
                CacheLog.verbose("Removing value for '\(key)'")
                items[key] = nil
                return
            }

            let finalAttributes = attributes ?? CacheItemAttributes()
            CacheLog.verbose("Setting value for '\(key)' with attributes: \(finalAttributes)")
            items[key] = Item(attributes: finalAttributes, value: value)
        }
    }

    public func attributes(forKey key: Key) -> CacheItemAttributes? {
        return queue.sync {
            return items[key]?.attributes
        }
    }

    public func setAttributes(_ attributes: CacheItemAttributes, forKey key: Key) {
        queue.sync(flags: .barrier) {
            guard self.items[key] != nil else {
                return
            }
            self.items[key]!.attributes = attributes
        }
    }

    public func removeAll() {
        queue.sync(flags: .barrier) {
            items.removeAll()
        }
    }
}
