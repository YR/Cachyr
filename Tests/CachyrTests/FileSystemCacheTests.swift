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

class FileSystemCacheTests: XCTestCase {
    var cache: FileSystemCache<String, String>!

    override func setUp() {
        super.setUp()

        cache = try! FileSystemCache<String, String>(name: "test")
        try! cache.removeAll()
    }

    override func tearDown() {
        super.tearDown()

        try! cache.removeAll()
    }

    func testCodable() throws {
        struct Thing: Codable, Equatable {
            let identifier: Int
            let question: String
        }

        let cache = try FileSystemCache<Int, Thing>(name: "test-codable")
        defer { try! cache.removeAll() }

        let key = 42
        let thing = Thing(identifier: key, question: "foo")
        try cache.setValue(thing, forKey: key)
        let value = try cache.value(forKey: key)
        XCTAssertNotNil(value)
        XCTAssertEqual(thing, value)
    }

    func testDataValue() throws {
        let cache = try FileSystemCache<String, Data>(name: "test-data")
        defer { try! cache.removeAll() }

        let foo = "bar".data(using: .utf8)!
        try cache.setValue(foo, forKey: "foo")
        let value = try cache.value(forKey: "foo")
        XCTAssertNotNil(value)
        XCTAssertEqual(foo, value)
    }

    func testStringValue() throws {
        let foo = "bar"
        try cache.setValue(foo, forKey: "foo")
        let value = try cache.value(forKey: "foo")
        XCTAssertNotNil(value)
        XCTAssertEqual(foo, value)
    }

    func testContains() throws {
        let key = "foo"
        XCTAssertFalse(cache.contains(key: key))
        try cache.setValue(key, forKey: key)
        XCTAssertTrue(cache.contains(key: key))
    }

    func testRemove() throws {
        let key = "foo"
        try cache.setValue(key, forKey: key)
        var value = try cache.value(forKey: key)
        XCTAssertNotNil(value)
        try cache.removeValue(forKey: key)
        value = try cache.value(forKey: key)
        XCTAssertNil(value)
    }

    func testRemoveAll() throws {
        try cache.setValue("foo", forKey: "foo")
        try cache.setValue("bar", forKey: "bar")
        try cache.removeAll()
        let foo = try cache.value(forKey: "foo")
        XCTAssertNil(foo)
        let bar = try cache.value(forKey: "bar")
        XCTAssertNil(bar)
    }

    func testExpiration() throws {
        let foo = "foo"

        try cache.setValue(foo, forKey: foo)
        let expirationInFutureValue = try cache.value(forKey: foo)
        XCTAssertNotNil(expirationInFutureValue)

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
        let fullExpiration = Date().addingTimeInterval(10)
        // No second fractions in expire date stored in extended attribute
        let expires = Date(timeIntervalSince1970: fullExpiration.timeIntervalSince1970.rounded())
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
        let expiration = Date().addingTimeInterval(10)
        let foo = "foo"
        try cache.setValue(foo, forKey: foo)
        let noExpire = try cache.attributes(forKey: foo)?.expirationDate
        XCTAssertNil(noExpire)
        try cache.setAttributes(CacheItemAttributes(expiration: expiration), forKey: foo)
        let expire = try cache.attributes(forKey: foo)?.expirationDate
        XCTAssertNotNil(expire)
        try cache.setAttributes(CacheItemAttributes(), forKey: foo)
        let expirationGone = try cache.attributes(forKey: foo)
        XCTAssertNotNil(expirationGone)
        XCTAssertNil(expirationGone?.expirationDate)
    }

    func testInteger() throws {
        let cacheInt = try FileSystemCache<String, Int>(name: "test-int")
        defer { try! cacheInt.removeAll() }
        let int = Int(Int.min)
        try cacheInt.setValue(int, forKey: "Int")
        let intValue = try cacheInt.value(forKey: "Int")
        XCTAssertEqual(intValue, int)

        let cacheInt8 = try FileSystemCache<String, Int8>(name: "test-int8")
        defer { try! cacheInt8.removeAll() }
        let int8 = Int8(Int8.min)
        try cacheInt8.setValue(int8, forKey: "Int8")
        let int8Value = try cacheInt8.value(forKey: "Int8")
        XCTAssertEqual(int8Value, int8)

        let cacheInt16 = try FileSystemCache<String, Int16>(name: "test-int16")
        defer { try! cacheInt16.removeAll() }
        let int16 = Int16(Int16.min)
        try cacheInt16.setValue(int16, forKey: "Int16")
        let int16Value = try cacheInt16.value(forKey: "Int16")
        XCTAssertEqual(int16Value, int16)

        let cacheInt32 = try FileSystemCache<String, Int32>(name: "test-int32")
        defer { try! cacheInt32.removeAll() }
        let int32 = Int32(Int32.min)
        try cacheInt32.setValue(int32, forKey: "Int32")
        let int32Value = try cacheInt32.value(forKey: "Int32")
        XCTAssertEqual(int32Value, int32)

        let cacheInt64 = try FileSystemCache<String, Int64>(name: "test-int64")
        defer { try! cacheInt64.removeAll() }
        let int64 = Int64(Int64.min)
        try cacheInt64.setValue(int64, forKey: "Int64")
        let int64Value = try cacheInt64.value(forKey: "Int64")
        XCTAssertEqual(int64Value, int64)

        let cacheUInt = try FileSystemCache<String, UInt>(name: "test-uint")
        defer { try! cacheUInt.removeAll() }
        let uint = UInt(UInt.max)
        try cacheUInt.setValue(uint, forKey: "UInt")
        let uintValue = try cacheUInt.value(forKey: "UInt")
        XCTAssertEqual(uintValue, uint)

        let cacheUInt8 = try FileSystemCache<String, UInt8>(name: "test-uint8")
        defer { try! cacheUInt8.removeAll() }
        let uint8 = UInt8(UInt8.max)
        try cacheUInt8.setValue(uint8, forKey: "UInt8")
        let uint8Value = try cacheUInt8.value(forKey: "UInt8")
        XCTAssertEqual(uint8Value, uint8)

        let cacheUInt16 = try FileSystemCache<String, UInt16>(name: "test-uint16")
        defer { try! cacheUInt16.removeAll() }
        let uint16 = UInt16(UInt16.max)
        try cacheUInt16.setValue(uint16, forKey: "UInt16")
        let uint16Value = try cacheUInt16.value(forKey: "UInt16")
        XCTAssertEqual(uint16Value, uint16)

        let cacheUInt32 = try FileSystemCache<String, UInt32>(name: "test-uint32")
        defer { try! cacheUInt32.removeAll() }
        let uint32 = UInt32(UInt32.max)
        try cacheUInt32.setValue(uint32, forKey: "UInt32")
        let uint32Value = try cacheUInt32.value(forKey: "UInt32")
        XCTAssertEqual(uint32Value, uint32)

        let cacheUInt64 = try FileSystemCache<String, UInt64>(name: "test-uint64")
        defer { try! cacheUInt64.removeAll() }
        let uint64 = UInt64(UInt64.max)
        try cacheUInt64.setValue(uint64, forKey: "UInt64")
        let uint64Value = try cacheUInt64.value(forKey: "UInt64")
        XCTAssertEqual(uint64Value, uint64)
    }

    func testFloatingPoint() throws {
        let cacheFloat = try FileSystemCache<String, Float>(name: "test-float")
        defer { try! cacheFloat.removeAll() }

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

        let cacheDouble = try FileSystemCache<String, Double>(name: "test-double")
        defer { try! cacheDouble.removeAll() }

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
