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

class HierarchyTests: XCTestCase {

    struct Book: Codable, Equatable {
        let identifier: Int
        let title: String
    }

    let expectationWaitTime: TimeInterval = 5

    let dataCache = Cache(storage: FileSystemStorage<Int, Data>()!)

    let memoryCache = Cache(storage: MemoryStorage<String, Book>())

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
        dataCache.removeAll()
        memoryCache.removeAll()
    }

    func testTransform() {

        let keyTransformer = Transformer<String, Int>(transform: { Int($0) }, reverse: { "\($0)" })

        let valueTransformer = Transformer<Book, Data>(
            transform: { try? JSONEncoder().encode($0) },
            reverse: { try? JSONDecoder().decode(Book.self, from: $0) })

        memoryCache.setCache(dataCache, as: .parent, keyTransformer: keyTransformer, valueTransformer: valueTransformer)
        let valueExpectation = expectation(description: "Transformed value from parent in cache")

        let dataKey = 42
        let memoryKey = "42"
        let book = Book(identifier: dataKey, title: "foo")
        let bookData = try! JSONEncoder().encode(book)

        dataCache.setValue(bookData, forKey: dataKey) {
            self.memoryCache.value(forKey: memoryKey) { (value) in
                XCTAssertEqual(book, value)
                valueExpectation.fulfill()
            }
        }
        waitForExpectations(timeout: expectationWaitTime)
    }

}
