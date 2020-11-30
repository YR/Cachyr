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

class CombinedCacheTests: XCTestCase {

    struct Book: Codable, Equatable {
        let title: String
    }

    var cache: CombinedCache<MemoryCache<String, String>, FileSystemCache<String, String>>!

    override func setUp() {
        super.setUp()

        cache = CombinedCache(
            primary: MemoryCache<String, String>(),
            secondary: try! FileSystemCache<String, String>(name: "test-memoryanddisk"),
            keyTransform: { $0 },
            primaryValueTransform: { $0 },
            secondaryValueTransform: { $0 }
        )
    }

    override func tearDown() {
        super.tearDown()

        try! cache.removeAll()
    }

    func testStringValue() throws {
        let foo = "bar"

        try cache.secondaryCache.setValue(foo, forKey: "foo")
        let value = try cache.value(forKey: "foo")
        XCTAssertEqual(foo, value)
    }

    func testContains() throws {
        let key = "foo"
        XCTAssertFalse(cache.contains(key: key))
        try cache.secondaryCache.setValue(key, forKey: key)
        XCTAssertTrue(cache.contains(key: key))
    }

    func testRemove() throws {
        let foo = "foo"
        try cache.secondaryCache.setValue(foo, forKey: foo)
        var value = try cache.value(forKey: foo)
        XCTAssertNotNil(value)
        try cache.removeValue(forKey: foo)
        value = try cache.value(forKey: foo)
        XCTAssertNil(value)
    }

    func testRemoveAll() throws {
        let foo = "foo"
        let bar = "bar"

        try cache.secondaryCache.setValue(foo, forKey: foo)
        try cache.secondaryCache.setValue(bar, forKey: bar)
        XCTAssertEqual(try cache.value(forKey: foo), foo)
        XCTAssertEqual(try cache.value(forKey: bar), bar)
        try cache.removeAll()
        var value = try cache.secondaryCache.value(forKey: foo)
        XCTAssertNil(value)
        value = try cache.primaryCache.value(forKey: bar)
        XCTAssertNil(value)
    }

    func testRemoveExpired() throws {
        let foo = "foo"
        let bar = "bar"
        let barExpireDate = Date(timeIntervalSinceNow: -30)
        let barAttributes = CacheItemAttributes(expiration: barExpireDate, removal: nil)

        try cache.secondaryCache.setValue(foo, forKey: foo)
        try cache.secondaryCache.setValue(bar, forKey: bar, attributes: barAttributes)
        try cache.secondaryCache.remove(where: { $0.hasExpired })
        var value = try cache.value(forKey: foo)
        XCTAssertNotNil(value)
        value = try cache.value(forKey: bar)
        XCTAssertNil(value)
    }

    func testSetGetExpiration() throws {
        let fullExpiration = Date().addingTimeInterval(10)
        // No second fractions in expire date stored in extended attribute
        let expires = Date(timeIntervalSince1970: fullExpiration.timeIntervalSince1970.rounded())
        let attributes = CacheItemAttributes(expiration: expires, removal: nil)
        let foo = "foo"
        try cache.secondaryCache.setValue(foo, forKey: foo)
        let noExpire = try cache.attributes(forKey: foo)?.expirationDate
        XCTAssertNil(noExpire)
        try cache.secondaryCache.setAttributes(attributes, forKey: foo)
        let expire = try cache.attributes(forKey: foo)?.expirationDate
        XCTAssertNotNil(expire)
        XCTAssertEqual(expires, expire!)
    }

    func testDiskAndMemoryExpiration() throws {
        let key = "foo"
        let value = "bar"
        let attributes = CacheItemAttributes(expiration: Date.distantFuture, removal: nil)

        try cache.secondaryCache.setValue(value, forKey: key, attributes: attributes)
        let diskExpires = try cache.secondaryCache.attributes(forKey: key)!.expirationDate
        XCTAssertEqual(diskExpires!, attributes.expirationDate!)

        // Populate memory cache by requesting value in data cache
        let cacheValue = try cache.value(forKey: key)
        XCTAssertNotNil(cacheValue)
        let memoryExpires = try cache.attributes(forKey: key)?.expirationDate
        XCTAssertNotNil(memoryExpires)
        XCTAssertEqual(memoryExpires!, attributes.expirationDate!)
    }
}
