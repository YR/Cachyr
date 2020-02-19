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

import Foundation

final class ReadWriteLock {
    private var rwlock = pthread_rwlock_t()

    init() {
        pthread_rwlock_init(&rwlock, nil)
    }

    deinit {
        pthread_rwlock_destroy(&rwlock)
    }

    func readLock() {
        pthread_rwlock_rdlock(&rwlock)
    }

    func tryReadLock() -> Bool {
        return pthread_rwlock_tryrdlock(&rwlock) == 0
    }

    func writeLock() {
        pthread_rwlock_wrlock(&rwlock)
    }

    func tryWriteLock() -> Bool {
        return pthread_rwlock_trywrlock(&rwlock) == 0
    }

    func unlock() {
        pthread_rwlock_unlock(&rwlock)
    }
}
