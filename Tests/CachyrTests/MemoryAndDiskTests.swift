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

import XCTest
@testable import Cachyr

class MemoryAndDiskTests: XCTestCase {

    struct Book: Codable, Equatable {
        let title: String
    }

    let diskCache = Cache(storage: FileSystemStorage<String, String>()!)

    let memoryCache = Cache(storage: MemoryStorage<String, String>())

    override func setUp() {
        super.setUp()

        diskCache.setCache(memoryCache, as: .child, keyTransformer: .identity(), valueTransformer: .identity())
    }

    override func tearDown() {
        super.tearDown()

        diskCache.removeAll()
        memoryCache.removeAll()
    }

    func testStringValue() {
        let foo = "bar"
        diskCache.setValue(foo, forKey: "foo")
        let value = memoryCache.value(forKey: "foo")
        XCTAssertEqual(foo, value)
    }

    func testContains() {
        let key = "foo"
        XCTAssertFalse(memoryCache.contains(key: key))
        diskCache.setValue(key, forKey: key)
        XCTAssertTrue(memoryCache.contains(key: key))
    }

    func testRemove() {
        let foo = "foo"
        diskCache.setValue(foo, forKey: foo)
        var value = memoryCache.value(forKey: foo)
        XCTAssertNotNil(value)
        diskCache.removeValue(forKey: foo)
        memoryCache.removeValue(forKey: foo)
        value = memoryCache.value(forKey: foo)
        XCTAssertNil(value)
    }

    func testRemoveAll() {
        let foo = "foo"
        let bar = "bar"

        diskCache.setValue(foo, forKey: foo)
        diskCache.setValue(bar, forKey: bar)
        XCTAssertEqual(memoryCache.value(forKey: foo), foo)
        XCTAssertEqual(memoryCache.value(forKey: bar), bar)
        self.memoryCache.removeAll()
        self.diskCache.removeAll()
        var value = memoryCache.value(forKey: foo)
        XCTAssertNil(value)
        value = memoryCache.value(forKey: bar)
        XCTAssertNil(value)
    }

    func testRemoveExpired() {
        let foo = "foo"
        let bar = "bar"
        let barExpireDate = Date(timeIntervalSinceNow: -30)
        let barAttributes = CacheItemAttributes(expiration: barExpireDate, removal: nil)

        diskCache.setValue(foo, forKey: foo)
        diskCache.setValue(bar, forKey: bar, attributes: barAttributes)
        diskCache.remove(where: { $0.hasExpired })
        var value = memoryCache.value(forKey: foo)
        XCTAssertNotNil(value)
        value = memoryCache.value(forKey: bar)
        XCTAssertNil(value)
    }

    func testSetGetExpiration() {
        let fullExpiration = Date().addingTimeInterval(10)
        // No second fractions in expire date stored in extended attribute
        let expires = Date(timeIntervalSince1970: fullExpiration.timeIntervalSince1970.rounded())
        let attributes = CacheItemAttributes(expiration: expires, removal: nil)
        let foo = "foo"
        diskCache.setValue(foo, forKey: foo)
        let noExpire = memoryCache.attributes(forKey: foo)?.expirationDate
        XCTAssertNil(noExpire)
        diskCache.setAttributes(attributes, forKey: foo)
        let expire = memoryCache.attributes(forKey: foo)?.expirationDate
        XCTAssertNotNil(expire)
        XCTAssertEqual(expires, expire!)
    }

    func testDiskAndMemoryExpiration() {
        let key = "foo"
        let value = "bar"
        let attributes = CacheItemAttributes(expiration: Date.distantFuture, removal: nil)

        diskCache.setValue(value, forKey: key, attributes: attributes)
        let diskExpires = diskCache.attributes(forKey: key)!.expirationDate
        XCTAssertEqual(diskExpires!, attributes.expirationDate!)

        // Populate memory cache by requesting value in data cache
        let cacheValue = memoryCache.value(forKey: key)
        XCTAssertNotNil(cacheValue)
        let memoryExpires = memoryCache.attributes(forKey: key)?.expirationDate
        XCTAssertNotNil(memoryExpires)
        XCTAssertEqual(memoryExpires!, attributes.expirationDate!)
    }
}
