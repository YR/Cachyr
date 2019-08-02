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

class MemoryStorageTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testIntValues() {
        let cache = Cache(storage: MemoryStorage<String, Int>())
        cache.setValue(42, forKey: "Int")
        let intValue = cache.value(forKey: "Int")
        XCTAssertEqual(42, intValue)
    }

    func testDoubleValues() {
        let cache = Cache(storage: MemoryStorage<String, Double>())
        cache.setValue(42.0, forKey: "Double")
        let doubleValue = cache.value(forKey: "Double")
        XCTAssertEqual(42.0, doubleValue)
    }

    func testStringValues() {
        let cache = Cache(storage: MemoryStorage<String, String>())
        cache.setValue("Test", forKey: "String")
        let stringValue = cache.value(forKey: "String")
        XCTAssertEqual("Test", stringValue)
    }

    func testStructValues() {
        struct Foo {
            let bar = "Bar"
        }

        let cache = Cache(storage: MemoryStorage<String, Foo>())
        cache.setValue(Foo(), forKey: "Foo")
        let foo = cache.value(forKey: "Foo")
        XCTAssertEqual("Bar", foo?.bar)
    }

    func testClassValues() {
        class Foo {
            let bar = "Bar"
        }

        let cache = Cache(storage: MemoryStorage<String, Foo>())
        cache.setValue(Foo(), forKey: "Foo")
        let foo = cache.value(forKey: "Foo")
        XCTAssertEqual("Bar", foo?.bar)
    }

    func testContains() {
        let cache = Cache(storage: MemoryStorage<String, String>())
        let key = "foo"
        XCTAssertFalse(cache.contains(key: key))
        cache.setValue(key, forKey: key)
        XCTAssertTrue(cache.contains(key: key))
    }

    func testRemove() {
        let cache = Cache(storage: MemoryStorage<String, String>())
        let key = "foo"
        cache.setValue(key, forKey: key)
        var value = cache.value(forKey: key)
        XCTAssertEqual(value, key)
        cache.setValue(nil, forKey: key)
        value = cache.value(forKey: key)
        XCTAssertNil(value)
    }

    func testRemoveAll() {
        let cache = Cache(storage: MemoryStorage<String, Int>())
        let values = [1, 2, 3]
        for i in values {
            cache.setValue(i, forKey: "\(i)")
        }
        for i in values {
            let value = cache.value(forKey: "\(i)")
            XCTAssertEqual(value, i)
        }
        cache.removeAll()
        for i in values {
            let value = cache.value(forKey: "\(i)")
            XCTAssertNil(value)
        }
    }

    func testExpiration() {
        let cache = Cache(storage: MemoryStorage<String, String>())
        let foo = "foo"

        let hasNotExpiredDate = Date(timeIntervalSinceNow: 30)
        cache.setValue(foo, forKey: foo, attributes: CacheItemAttributes(expiration: hasNotExpiredDate))
        let notExpiredValue = cache.value(forKey: foo)
        XCTAssertNotNil(notExpiredValue)

        let hasExpiredDate = Date(timeIntervalSinceNow: -30)
        cache.setValue(foo, forKey: foo, attributes: CacheItemAttributes(expiration: hasExpiredDate))
        let expiredValue = cache.value(forKey: foo)
        XCTAssertNil(expiredValue)
    }

    func testRemoveExpired() {
        let cache = Cache(storage: MemoryStorage<String, String>())
        let foo = "foo"
        let bar = "bar"
        let barExpireDate = Date(timeIntervalSinceNow: -30)

        cache.setValue(foo, forKey: foo)
        cache.setValue(bar, forKey: bar, attributes: CacheItemAttributes(expiration: barExpireDate))
        cache.remove(where: { $0.hasExpired })

        let fooValue = cache.value(forKey: foo)
        XCTAssertNotNil(fooValue)
        let barValue = cache.value(forKey: bar)
        XCTAssertNil(barValue)
    }

    func testSetGetExpiration() {
        let cache = Cache(storage: MemoryStorage<String, String>())
        let expires = Date().addingTimeInterval(10)
        let foo = "foo"
        cache.setValue(foo, forKey: foo)
        let noExpire = cache.attributes(forKey: foo)?.expirationDate
        XCTAssertNil(noExpire)
        cache.setAttributes(CacheItemAttributes(expiration: expires), forKey: foo)
        let expire = cache.attributes(forKey: foo)?.expirationDate
        XCTAssertNotNil(expire)
        XCTAssertEqual(expires, expire)
    }

    func testRemoveExpiration() {
        let cache = Cache(storage: MemoryStorage<String, String>())
        let expiration = Date().addingTimeInterval(10)
        let foo = "foo"
        cache.setValue(foo, forKey: foo)
        let noExpire = cache.attributes(forKey: foo)?.expirationDate
        XCTAssertNil(noExpire)
        cache.setAttributes(CacheItemAttributes(expiration: expiration), forKey: foo)
        let expire = cache.attributes(forKey: foo)?.expirationDate
        XCTAssertNotNil(expire)
        cache.setAttributes(CacheItemAttributes(expiration: nil), forKey: foo)
        let expirationGone = cache.attributes(forKey: foo)?.expirationDate
        XCTAssertNil(expirationGone)
    }

    func testInteger() {
        let cacheInt = Cache(storage: MemoryStorage<String, Int>())
        let int = Int(Int.min)
        cacheInt.setValue(int, forKey: "Int")
        let intValue = cacheInt.value(forKey: "Int")
        XCTAssertEqual(intValue, int)

        let cacheInt8 = Cache(storage: MemoryStorage<String, Int8>())
        let int8 = Int8(Int8.min)
        cacheInt8.setValue(int8, forKey: "Int8")
        let int8Value = cacheInt8.value(forKey: "Int8")
        XCTAssertEqual(int8Value, int8)

        let cacheInt16 = Cache(storage: MemoryStorage<String, Int16>())
        let int16 = Int16(Int16.min)
        cacheInt16.setValue(int16, forKey: "Int16")
        let int16Value = cacheInt16.value(forKey: "Int16")
        XCTAssertEqual(int16Value, int16)

        let cacheInt32 = Cache(storage: MemoryStorage<String, Int32>())
        let int32 = Int32(Int32.min)
        cacheInt32.setValue(int32, forKey: "Int32")
        let int32Value = cacheInt32.value(forKey: "Int32")
        XCTAssertEqual(int32Value, int32)

        let cacheInt64 = Cache(storage: MemoryStorage<String, Int64>())
        let int64 = Int64(Int64.min)
        cacheInt64.setValue(int64, forKey: "Int64")
        let int64Value = cacheInt64.value(forKey: "Int64")
        XCTAssertEqual(int64Value, int64)

        let cacheUInt = Cache(storage: MemoryStorage<String, UInt>())
        let uint = UInt(UInt.max)
        cacheUInt.setValue(uint, forKey: "UInt")
        let uintValue = cacheUInt.value(forKey: "UInt")
        XCTAssertEqual(uintValue, uint)

        let cacheUInt8 = Cache(storage: MemoryStorage<String, UInt8>())
        let uint8 = UInt8(UInt8.max)
        cacheUInt8.setValue(uint8, forKey: "UInt8")
        let uint8Value = cacheUInt8.value(forKey: "UInt8")
        XCTAssertEqual(uint8Value, uint8)

        let cacheUInt16 = Cache(storage: MemoryStorage<String, UInt16>())
        let uint16 = UInt16(UInt16.max)
        cacheUInt16.setValue(uint16, forKey: "UInt16")
        let uint16Value = cacheUInt16.value(forKey: "UInt16")
        XCTAssertEqual(uint16Value, uint16)

        let cacheUInt32 = Cache(storage: MemoryStorage<String, UInt32>())
        let uint32 = UInt32(UInt32.max)
        cacheUInt32.setValue(uint32, forKey: "UInt32")
        let uint32Value = cacheUInt32.value(forKey: "UInt32")
        XCTAssertEqual(uint32Value, uint32)

        let cacheUInt64 = Cache(storage: MemoryStorage<String, UInt64>())
        let uint64 = UInt64(UInt64.max)
        cacheUInt64.setValue(uint64, forKey: "UInt64")
        let uint64Value = cacheUInt64.value(forKey: "UInt64")
        XCTAssertEqual(uint64Value, uint64)
    }

    func testFloatingPoint() {
        let cacheFloat = Cache(storage: MemoryStorage<String, Float>())

        let float = Float(Float.pi)
        cacheFloat.setValue(float, forKey: "Float")
        let floatValue = cacheFloat.value(forKey: "Float")
        XCTAssertEqual(floatValue, float)

        let negFloat = Float(-Float.pi)
        cacheFloat.setValue(negFloat, forKey: "negFloat")
        let negFloatValue = cacheFloat.value(forKey: "negFloat")
        XCTAssertEqual(negFloatValue, negFloat)

        let infFloat = Float.infinity
        cacheFloat.setValue(infFloat, forKey: "infFloat")
        let infFloatValue = cacheFloat.value(forKey: "infFloat")
        XCTAssertEqual(infFloatValue, infFloat)

        let nanFloat = Float.nan
        cacheFloat.setValue(nanFloat, forKey: "nanFloat")
        let nanFloatValue = cacheFloat.value(forKey: "nanFloat")
        XCTAssertEqual(nanFloatValue?.isNaN, nanFloat.isNaN)

        let cacheDouble = Cache(storage: MemoryStorage<String, Double>())

        let double = Double(Double.pi)
        cacheDouble.setValue(double, forKey: "Double")
        let doubleValue = cacheDouble.value(forKey: "Double")
        XCTAssertEqual(doubleValue, double)

        let negDouble = Double(-Double.pi)
        cacheDouble.setValue(negDouble, forKey: "negDouble")
        let negDoubleValue = cacheDouble.value(forKey: "negDouble")
        XCTAssertEqual(negDoubleValue, negDouble)

        let infDouble = Double.infinity
        cacheDouble.setValue(infDouble, forKey: "infDouble")
        let infDoubleValue = cacheDouble.value(forKey: "infDouble")
        XCTAssertEqual(infDoubleValue, infDouble)

        let nanDouble = Double.nan
        cacheDouble.setValue(nanDouble, forKey: "nanDouble")
        let nanDoubleValue = cacheDouble.value(forKey: "nanDouble")
        XCTAssertEqual(nanDoubleValue?.isNaN, nanDouble.isNaN)
    }
}
