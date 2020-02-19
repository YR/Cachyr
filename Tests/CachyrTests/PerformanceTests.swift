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

    private func runPerformanceTest<Storage>(cache: Cache<Storage>, iterations: Int)
        where Storage.Key == Int, Storage.Value == Int {

        let queue = DispatchQueue(label: "testPerformance", attributes: .concurrent)
        let threadCountSemaphore = DispatchSemaphore(value: 10)
        let doneSemaphore = DispatchSemaphore(value: 0)
        let numberRange = 1 ... 10
        var doneCount = 0
        let doneCountLock = ReadWriteLock()

        for _ in 0 ..< iterations {
            threadCountSemaphore.wait()
            queue.async {
                let number = numberRange.randomElement()!
                if let _ = cache.value(forKey: number) {
                    cache.removeValue(forKey: number)
                } else {
                    cache.setValue(number, forKey: number)
                }
                threadCountSemaphore.signal()
                doneCountLock.writeLock()
                doneCount += 1
                if doneCount == iterations {
                    doneSemaphore.signal()
                }
                doneCountLock.unlock()
            }
        }
        doneSemaphore.wait()
    }

    func testDiskPerformance() {
        let diskCache = Cache(storage: FileSystemStorage<Int, Int>()!)
        measure {
            runPerformanceTest(cache: diskCache, iterations: 1_000)
            diskCache.removeAll()
        }
    }

    func testMemoryPerformance() {
        let memoryCache = Cache(storage: MemoryStorage<Int, Int>())
        measure {
            runPerformanceTest(cache: memoryCache, iterations: 10_000)
            memoryCache.removeAll()
        }
    }

}
