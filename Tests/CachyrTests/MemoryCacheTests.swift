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

class MemoryCacheTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testIntValues() throws {
        let cache = MemoryCache<String, Int>()
        try cache.setValue(42, forKey: "Int")
        let intValue = try cache.value(forKey: "Int")
        XCTAssertEqual(42, intValue)
    }

    func testDoubleValues() throws {
        let cache = MemoryCache<String, Double>()
        try cache.setValue(42.0, forKey: "Double")
        let doubleValue = try cache.value(forKey: "Double")
        XCTAssertEqual(42.0, doubleValue)
    }

    func testStringValues() throws {
        let cache = MemoryCache<String, String>()
        try cache.setValue("Test", forKey: "String")
        let stringValue = try cache.value(forKey: "String")
        XCTAssertEqual("Test", stringValue)
    }

    func testStructValues() throws {
        struct Foo {
            let bar = "Bar"
        }

        let cache = MemoryCache<String, Foo>()
        try cache.setValue(Foo(), forKey: "Foo")
        let foo = try cache.value(forKey: "Foo")
        XCTAssertEqual("Bar", foo?.bar)
    }

    func testClassValues() throws {
        class Foo {
            let bar = "Bar"
        }

        let cache = MemoryCache<String, Foo>()
        try cache.setValue(Foo(), forKey: "Foo")
        let foo = try cache.value(forKey: "Foo")
        XCTAssertEqual("Bar", foo?.bar)
    }

    func testContains() throws {
        let cache = MemoryCache<String, String>()
        let key = "foo"
        XCTAssertFalse(cache.contains(key: key))
        try cache.setValue(key, forKey: key)
        XCTAssertTrue(cache.contains(key: key))
    }

    func testRemove() throws {
        let cache = MemoryCache<String, String>()
        let key = "foo"
        try cache.setValue(key, forKey: key)
        var value = try cache.value(forKey: key)
        XCTAssertEqual(value, key)
        try cache.removeValue(forKey: key)
        value = try cache.value(forKey: key)
        XCTAssertNil(value)
    }

    func testRemoveAll() throws {
        let cache = MemoryCache<String, Int>()
        let values = [1, 2, 3]
        for i in values {
            try cache.setValue(i, forKey: "\(i)")
        }
        for i in values {
            let value = try cache.value(forKey: "\(i)")
            XCTAssertEqual(value, i)
        }
        try cache.removeAll()
        for i in values {
            let value = try cache.value(forKey: "\(i)")
            XCTAssertNil(value)
        }
    }

    func testExpiration() throws {
        let cache = MemoryCache<String, String>()
        let foo = "foo"

        let hasNotExpiredDate = Date(timeIntervalSinceNow: 30)
        try cache.setValue(foo, forKey: foo, attributes: CacheItemAttributes(expiration: hasNotExpiredDate))
        let notExpiredValue = try cache.value(forKey: foo)
        XCTAssertNotNil(notExpiredValue)

        let hasExpiredDate = Date(timeIntervalSinceNow: -30)
        try cache.setValue(foo, forKey: foo, attributes: CacheItemAttributes(expiration: hasExpiredDate))
        let expiredValue = try cache.value(forKey: foo)
        XCTAssertNil(expiredValue)
    }

    func testRemoveExpired() throws {
        let cache = MemoryCache<String, String>()
        let foo = "foo"
        let bar = "bar"
        let barExpireDate = Date(timeIntervalSinceNow: -30)

        try cache.setValue(foo, forKey: foo)
        try cache.setValue(bar, forKey: bar, attributes: CacheItemAttributes(expiration: barExpireDate))
        try cache.remove(where: { $0.hasExpired })

        let fooValue = try cache.value(forKey: foo)
        XCTAssertNotNil(fooValue)
        let barValue = try cache.value(forKey: bar)
        XCTAssertNil(barValue)
    }

    func testSetGetExpiration() throws {
        let cache = MemoryCache<String, String>()
        let expires = Date().addingTimeInterval(10)
        let foo = "foo"
        try cache.setValue(foo, forKey: foo)
        let noExpire = try cache.attributes(forKey: foo)?.expirationDate
        XCTAssertNil(noExpire)
        try cache.setAttributes(CacheItemAttributes(expiration: expires), forKey: foo)
        let expire = try cache.attributes(forKey: foo)?.expirationDate
        XCTAssertNotNil(expire)
        XCTAssertEqual(expires, expire)
    }

    func testRemoveExpiration() throws {
        let cache = MemoryCache<String, String>()
        let expiration = Date().addingTimeInterval(10)
        let foo = "foo"
        try cache.setValue(foo, forKey: foo)
        let noExpire = try cache.attributes(forKey: foo)?.expirationDate
        XCTAssertNil(noExpire)
        try cache.setAttributes(CacheItemAttributes(expiration: expiration), forKey: foo)
        let expire = try cache.attributes(forKey: foo)?.expirationDate
        XCTAssertNotNil(expire)
        try cache.setAttributes(CacheItemAttributes(expiration: nil), forKey: foo)
        let expirationGone = try cache.attributes(forKey: foo)?.expirationDate
        XCTAssertNil(expirationGone)
    }

    func testInteger() throws {
        let cacheInt = MemoryCache<String, Int>()
        let int = Int(Int.min)
        try cacheInt.setValue(int, forKey: "Int")
        let intValue = try cacheInt.value(forKey: "Int")
        XCTAssertEqual(intValue, int)

        let cacheInt8 = MemoryCache<String, Int8>()
        let int8 = Int8(Int8.min)
        try cacheInt8.setValue(int8, forKey: "Int8")
        let int8Value = try cacheInt8.value(forKey: "Int8")
        XCTAssertEqual(int8Value, int8)

        let cacheInt16 = MemoryCache<String, Int16>()
        let int16 = Int16(Int16.min)
        try cacheInt16.setValue(int16, forKey: "Int16")
        let int16Value = try cacheInt16.value(forKey: "Int16")
        XCTAssertEqual(int16Value, int16)

        let cacheInt32 = MemoryCache<String, Int32>()
        let int32 = Int32(Int32.min)
        try cacheInt32.setValue(int32, forKey: "Int32")
        let int32Value = try cacheInt32.value(forKey: "Int32")
        XCTAssertEqual(int32Value, int32)

        let cacheInt64 = MemoryCache<String, Int64>()
        let int64 = Int64(Int64.min)
        try cacheInt64.setValue(int64, forKey: "Int64")
        let int64Value = try cacheInt64.value(forKey: "Int64")
        XCTAssertEqual(int64Value, int64)

        let cacheUInt = MemoryCache<String, UInt>()
        let uint = UInt(UInt.max)
        try cacheUInt.setValue(uint, forKey: "UInt")
        let uintValue = try cacheUInt.value(forKey: "UInt")
        XCTAssertEqual(uintValue, uint)

        let cacheUInt8 = MemoryCache<String, UInt8>()
        let uint8 = UInt8(UInt8.max)
        try cacheUInt8.setValue(uint8, forKey: "UInt8")
        let uint8Value = try cacheUInt8.value(forKey: "UInt8")
        XCTAssertEqual(uint8Value, uint8)

        let cacheUInt16 = MemoryCache<String, UInt16>()
        let uint16 = UInt16(UInt16.max)
        try cacheUInt16.setValue(uint16, forKey: "UInt16")
        let uint16Value = try cacheUInt16.value(forKey: "UInt16")
        XCTAssertEqual(uint16Value, uint16)

        let cacheUInt32 = MemoryCache<String, UInt32>()
        let uint32 = UInt32(UInt32.max)
        try cacheUInt32.setValue(uint32, forKey: "UInt32")
        let uint32Value = try cacheUInt32.value(forKey: "UInt32")
        XCTAssertEqual(uint32Value, uint32)

        let cacheUInt64 = MemoryCache<String, UInt64>()
        let uint64 = UInt64(UInt64.max)
        try cacheUInt64.setValue(uint64, forKey: "UInt64")
        let uint64Value = try cacheUInt64.value(forKey: "UInt64")
        XCTAssertEqual(uint64Value, uint64)
    }

    func testFloatingPoint() throws {
        let cacheFloat = MemoryCache<String, Float>()

        let float = Float(Float.pi)
        try cacheFloat.setValue(float, forKey: "Float")
        let floatValue = try cacheFloat.value(forKey: "Float")
        XCTAssertEqual(floatValue, float)

        let negFloat = Float(-Float.pi)
        try cacheFloat.setValue(negFloat, forKey: "negFloat")
        let negFloatValue = try cacheFloat.value(forKey: "negFloat")
        XCTAssertEqual(negFloatValue, negFloat)

        let infFloat = Float.infinity
        try cacheFloat.setValue(infFloat, forKey: "infFloat")
        let infFloatValue = try cacheFloat.value(forKey: "infFloat")
        XCTAssertEqual(infFloatValue, infFloat)

        let nanFloat = Float.nan
        try cacheFloat.setValue(nanFloat, forKey: "nanFloat")
        let nanFloatValue = try cacheFloat.value(forKey: "nanFloat")
        XCTAssertEqual(nanFloatValue?.isNaN, nanFloat.isNaN)

        let cacheDouble = MemoryCache<String, Double>()

        let double = Double(Double.pi)
        try cacheDouble.setValue(double, forKey: "Double")
        let doubleValue = try cacheDouble.value(forKey: "Double")
        XCTAssertEqual(doubleValue, double)

        let negDouble = Double(-Double.pi)
        try cacheDouble.setValue(negDouble, forKey: "negDouble")
        let negDoubleValue = try cacheDouble.value(forKey: "negDouble")
        XCTAssertEqual(negDoubleValue, negDouble)

        let infDouble = Double.infinity
        try cacheDouble.setValue(infDouble, forKey: "infDouble")
        let infDoubleValue = try cacheDouble.value(forKey: "infDouble")
        XCTAssertEqual(infDoubleValue, infDouble)

        let nanDouble = Double.nan
        try cacheDouble.setValue(nanDouble, forKey: "nanDouble")
        let nanDoubleValue = try cacheDouble.value(forKey: "nanDouble")
        XCTAssertEqual(nanDoubleValue?.isNaN, nanDouble.isNaN)
    }
}
