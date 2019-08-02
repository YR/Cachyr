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

class FileSystemStorageTests: XCTestCase {
    var cache: Cache<FileSystemStorage<String, String>>!

    override func setUp() {
        super.setUp()

        cache = Cache(storage: FileSystemStorage<String, String>(name: "no.nrk.cachyr.test")!)
    }

    override func tearDown() {
        super.tearDown()

        cache.removeAll()
    }

    func testCodable() {
        struct Thing: Codable, Equatable {
            let identifier: Int
            let question: String
        }

        let cache = Cache(storage: FileSystemStorage<Int, Thing>(name: "no.nrk.cachyr.test-codable")!)
        defer { cache.removeAll() }

        let key = 42
        let thing = Thing(identifier: key, question: "foo")
        cache.setValue(thing, forKey: key)
        let value = cache.value(forKey: key)
        XCTAssertNotNil(value)
        XCTAssertEqual(thing, value)
    }

    func testDataValue() {
        let cache = Cache(storage: FileSystemStorage<String, Data>(name: "no.nrk.cachyr.test-data")!)
        defer { cache.removeAll() }

        let foo = "bar".data(using: .utf8)!
        cache.setValue(foo, forKey: "foo")
        let value = cache.value(forKey: "foo")
        XCTAssertNotNil(value)
        XCTAssertEqual(foo, value)
    }

    func testStringValue() {
        let foo = "bar"
        cache.setValue(foo, forKey: "foo")
        let value = cache.value(forKey: "foo")
        XCTAssertNotNil(value)
        XCTAssertEqual(foo, value)
    }

    func testContains() {
        let key = "foo"
        XCTAssertFalse(cache.contains(key: key))
        cache.setValue(key, forKey: key)
        XCTAssertTrue(cache.contains(key: key))
    }

    func testRemove() {
        let key = "foo"
        cache.setValue(key, forKey: key)
        var value = cache.value(forKey: key)
        XCTAssertNotNil(value)
        cache.setValue(nil, forKey: key)
        value = cache.value(forKey: key)
        XCTAssertNil(value)
    }

    func testRemoveAll() {
        cache.setValue("foo", forKey: "foo")
        cache.setValue("bar", forKey: "bar")
        cache.removeAll()
        let foo = cache.value(forKey: "foo")
        XCTAssertNil(foo)
        let bar = cache.value(forKey: "bar")
        XCTAssertNil(bar)
    }

    func testExpiration() {
        let foo = "foo"

        cache.setValue(foo, forKey: foo)
        let expirationInFutureValue = cache.value(forKey: foo)
        XCTAssertNotNil(expirationInFutureValue)

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
        let fullExpiration = Date().addingTimeInterval(10)
        // No second fractions in expire date stored in extended attribute
        let expires = Date(timeIntervalSince1970: fullExpiration.timeIntervalSince1970.rounded())
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
        let expiration = Date().addingTimeInterval(10)
        let foo = "foo"
        cache.setValue(foo, forKey: foo)
        let noExpire = cache.attributes(forKey: foo)?.expirationDate
        XCTAssertNil(noExpire)
        cache.setAttributes(CacheItemAttributes(expiration: expiration), forKey: foo)
        let expire = cache.attributes(forKey: foo)?.expirationDate
        XCTAssertNotNil(expire)
        cache.setAttributes(CacheItemAttributes(), forKey: foo)
        let expirationGone = cache.attributes(forKey: foo)
        XCTAssertNotNil(expirationGone)
        XCTAssertNil(expirationGone?.expirationDate)
    }

    func testInteger() {
        let cacheInt = Cache(storage: FileSystemStorage<String, Int>(name: "no.nrk.cachyr.test-int")!)
        defer { cacheInt.removeAll() }
        let int = Int(Int.min)
        cacheInt.setValue(int, forKey: "Int")
        let intValue = cacheInt.value(forKey: "Int")
        XCTAssertEqual(intValue, int)

        let cacheInt8 = Cache(storage: FileSystemStorage<String, Int8>(name: "no.nrk.cachyr.test-int8")!)
        defer { cacheInt8.removeAll() }
        let int8 = Int8(Int8.min)
        cacheInt8.setValue(int8, forKey: "Int8")
        let int8Value = cacheInt8.value(forKey: "Int8")
        XCTAssertEqual(int8Value, int8)

        let cacheInt16 = Cache(storage: FileSystemStorage<String, Int16>(name: "no.nrk.cachyr.test-int16")!)
        defer { cacheInt16.removeAll() }
        let int16 = Int16(Int16.min)
        cacheInt16.setValue(int16, forKey: "Int16")
        let int16Value = cacheInt16.value(forKey: "Int16")
        XCTAssertEqual(int16Value, int16)

        let cacheInt32 = Cache(storage: FileSystemStorage<String, Int32>(name: "no.nrk.cachyr.test-int32")!)
        defer { cacheInt32.removeAll() }
        let int32 = Int32(Int32.min)
        cacheInt32.setValue(int32, forKey: "Int32")
        let int32Value = cacheInt32.value(forKey: "Int32")
        XCTAssertEqual(int32Value, int32)

        let cacheInt64 = Cache(storage: FileSystemStorage<String, Int64>(name: "no.nrk.cachyr.test-int64")!)
        defer { cacheInt64.removeAll() }
        let int64 = Int64(Int64.min)
        cacheInt64.setValue(int64, forKey: "Int64")
        let int64Value = cacheInt64.value(forKey: "Int64")
        XCTAssertEqual(int64Value, int64)

        let cacheUInt = Cache(storage: FileSystemStorage<String, UInt>(name: "no.nrk.cachyr.test-uint")!)
        defer { cacheUInt.removeAll() }
        let uint = UInt(UInt.max)
        cacheUInt.setValue(uint, forKey: "UInt")
        let uintValue = cacheUInt.value(forKey: "UInt")
        XCTAssertEqual(uintValue, uint)

        let cacheUInt8 = Cache(storage: FileSystemStorage<String, UInt8>(name: "no.nrk.cachyr.test-uint8")!)
        defer { cacheUInt8.removeAll() }
        let uint8 = UInt8(UInt8.max)
        cacheUInt8.setValue(uint8, forKey: "UInt8")
        let uint8Value = cacheUInt8.value(forKey: "UInt8")
        XCTAssertEqual(uint8Value, uint8)

        let cacheUInt16 = Cache(storage: FileSystemStorage<String, UInt16>(name: "no.nrk.cachyr.test-uint16")!)
        defer { cacheUInt16.removeAll() }
        let uint16 = UInt16(UInt16.max)
        cacheUInt16.setValue(uint16, forKey: "UInt16")
        let uint16Value = cacheUInt16.value(forKey: "UInt16")
        XCTAssertEqual(uint16Value, uint16)

        let cacheUInt32 = Cache(storage: FileSystemStorage<String, UInt32>(name: "no.nrk.cachyr.test-uint32")!)
        defer { cacheUInt32.removeAll() }
        let uint32 = UInt32(UInt32.max)
        cacheUInt32.setValue(uint32, forKey: "UInt32")
        let uint32Value = cacheUInt32.value(forKey: "UInt32")
        XCTAssertEqual(uint32Value, uint32)

        let cacheUInt64 = Cache(storage: FileSystemStorage<String, UInt64>(name: "no.nrk.cachyr.test-uint64")!)
        defer { cacheUInt64.removeAll() }
        let uint64 = UInt64(UInt64.max)
        cacheUInt64.setValue(uint64, forKey: "UInt64")
        let uint64Value = cacheUInt64.value(forKey: "UInt64")
        XCTAssertEqual(uint64Value, uint64)
    }

    func testFloatingPoint() {
        let cacheFloat = Cache(storage: FileSystemStorage<String, Float>(name: "no.nrk.cachyr.test-float")!)
        defer { cacheFloat.removeAll() }

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

        let cacheDouble = Cache(storage: FileSystemStorage<String, Double>(name: "no.nrk.cachyr.test-double")!)
        defer { cacheDouble.removeAll() }

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
