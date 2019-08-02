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

    let expectationWaitTime: TimeInterval = 5

    override func setUp() {
        super.setUp()

        diskCache.setCache(memoryCache, as: .child, keyTransformer: .identity(), valueTransformer: .identity())
    }

    override func tearDown() {
        super.tearDown()

        diskCache.removeAll()
        memoryCache.removeAll()
    }

    func testAsyncStringValue() {
        let valueExpectation = expectation(description: "String value in cache")
        let foo = "bar"
        diskCache.setValue(foo, forKey: "foo") {
            self.memoryCache.value(forKey: "foo") {
                (value) in
                XCTAssertEqual(foo, value)
                valueExpectation.fulfill()
            }
        }
        waitForExpectations(timeout: expectationWaitTime)
    }

    func testSyncStringValue() {
        let foo = "bar"
        diskCache.setValue(foo, forKey: "foo")
        let value = memoryCache.value(forKey: "foo")
        XCTAssertEqual(foo, value)
    }

    func testAsyncContains() {
        let expect = expectation(description: "Cache contains key")
        let key = "foo"
        memoryCache.contains(key: key) { (found) in
            XCTAssertFalse(found)
            self.diskCache.setValue(key, forKey: key)
            self.memoryCache.contains(key: key, completion: { (found) in
                XCTAssertTrue(found)
                expect.fulfill()
            })
        }
        waitForExpectations(timeout: expectationWaitTime)
    }

    func testSyncContains() {
        let key = "foo"
        XCTAssertFalse(memoryCache.contains(key: key))
        diskCache.setValue(key, forKey: key)
        XCTAssertTrue(memoryCache.contains(key: key))
    }

    func testAsyncRemove() {
        let expect = expectation(description: "Remove value in cache")
        let foo = "foo"
        diskCache.setValue(foo, forKey: foo) {
            self.memoryCache.value(forKey: foo) { (value) in
                XCTAssertNotNil(value)
                self.diskCache.removeValue(forKey: foo)
                self.memoryCache.removeValue(forKey: foo) {
                    self.memoryCache.value(forKey: foo) { (value) in
                        XCTAssertNil(value)
                        expect.fulfill()
                    }
                }
            }
        }
        waitForExpectations(timeout: expectationWaitTime)
    }

    func testSyncRemove() {
        let foo = "foo"
        diskCache.setValue(foo, forKey: foo)
        var value = memoryCache.value(forKey: foo)
        XCTAssertNotNil(value)
        diskCache.removeValue(forKey: foo)
        memoryCache.removeValue(forKey: foo)
        value = memoryCache.value(forKey: foo)
        XCTAssertNil(value)
    }

    func testAsyncRemoveAll() {
        let valueExpectation = expectation(description: "Remove all in cache")
        let foo = "foo"
        let bar = "bar"

        diskCache.setValue(foo, forKey: foo)
        diskCache.setValue(bar, forKey: bar) {
            XCTAssertEqual(self.memoryCache.value(forKey: foo), foo)
            XCTAssertEqual(self.memoryCache.value(forKey: bar), bar)
            self.memoryCache.removeAll()
            self.diskCache.removeAll() {
                self.memoryCache.value(forKey: foo) { (value) in
                    XCTAssertNil(value)
                    self.memoryCache.value(forKey: bar) { (value) in
                        XCTAssertNil(value)
                        valueExpectation.fulfill()
                    }
                }
            }
        }
        waitForExpectations(timeout: expectationWaitTime)
    }

    func testSyncRemoveAll() {
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

    func testAsyncRemoveExpired() {
        let valueExpectation = expectation(description: "Remove expired in cache")
        let foo = "foo"
        let bar = "bar"
        let barExpireDate = Date(timeIntervalSinceNow: -30)
        let attributes = CacheItemAttributes(expiration: barExpireDate, removal: nil)

        diskCache.setValue(foo, forKey: foo)
        diskCache.setValue(bar, forKey: bar, attributes: attributes)
        diskCache.remove(where: { $0.hasExpired }) {
            self.memoryCache.value(forKey: foo) { (value) in
                XCTAssertNotNil(value)
                self.memoryCache.value(forKey: bar) { (value) in
                    XCTAssertNil(value)
                    valueExpectation.fulfill()
                }
            }
        }
        waitForExpectations(timeout: expectationWaitTime)
    }

    func testSyncRemoveExpired() {
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

    func testAsyncSetGetExpiration() {
        let expect = expectation(description: "Async get/set expiration")
        let fullExpiration = Date().addingTimeInterval(10)
        // No second fractions in expire date stored in extended attribute
        let expires = Date(timeIntervalSince1970: fullExpiration.timeIntervalSince1970.rounded())

        let foo = "foo"
        diskCache.setValue(foo, forKey: foo)
        memoryCache.attributes(forKey: foo) { (attributes) in
            XCTAssertNil(attributes?.expirationDate)
            let attributes = CacheItemAttributes(expiration: expires, removal: nil)
            self.diskCache.setAttributes(attributes, forKey: foo) {
                self.memoryCache.attributes(forKey: foo) { (attributes) in
                    XCTAssertNotNil(attributes?.expirationDate)
                    XCTAssertEqual(expires, attributes!.expirationDate!)
                    expect.fulfill()
                }
            }
        }

        waitForExpectations(timeout: expectationWaitTime)
    }

    func testSyncSetGetExpiration() {
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

    func testCompletionBackgroundQueue() {
        let expect = expectation(description: "Background queue completion")
        let currentThread = Thread.current
        let cache = Cache(
            storage: MemoryStorage<String, String>(),
            completionQueue: DispatchQueue(label: "backgroundTest", qos: .background)
        )
        cache.setValue("asdf", forKey: "foo")
        cache.value(forKey: "foo") { (_) in
            XCTAssertNotEqual(currentThread, Thread.current)
            expect.fulfill()
        }
        waitForExpectations(timeout: expectationWaitTime) { error in
            cache.removeAll()
        }
    }

    func testCompletionMainQueue() {
        let expect = expectation(description: "Main queue completion")
        let cache = Cache(
            storage: MemoryStorage<String, String>(),
            completionQueue: .main
        )
        cache.setValue("asdf", forKey: "foo")
        cache.value(forKey: "foo") { (_) in
            XCTAssertEqual(Thread.main, Thread.current)
            expect.fulfill()
        }
        waitForExpectations(timeout: expectationWaitTime) { error in
            cache.removeAll()
        }
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
