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

class PerformanceTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    private func runPerformanceTest<Cache: CacheAPI>(cache: Cache, iterations: Int)
        where Cache.Key == Int, Cache.Value == Int {

        let queue = DispatchQueue(label: "testPerformance")
        let doneSemaphore = DispatchSemaphore(value: 0)
        let numberRange = 1 ... 10
        var doneCount = 0

        for _ in 0 ..< iterations {
            queue.async {
                let number = numberRange.randomElement()!
                if let _ = try! cache.value(forKey: number) {
                    try! cache.removeValue(forKey: number)
                } else {
                    try! cache.setValue(number, forKey: number, attributes: nil)
                }
                doneCount += 1
                if doneCount == iterations {
                    doneSemaphore.signal()
                }
            }
        }
        doneSemaphore.wait()
    }

    func testDiskPerformance() throws {
        let diskCache = try FileSystemCache<Int, Int>()
        measure {
            runPerformanceTest(cache: diskCache, iterations: 1_000)
            try! diskCache.removeAll()
        }
    }

    func testMemoryPerformance() throws {
        let memoryCache = MemoryCache<Int, Int>()
        measure {
            runPerformanceTest(cache: memoryCache, iterations: 10_000)
            try! memoryCache.removeAll()
        }
    }

}
