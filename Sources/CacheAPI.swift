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

public protocol CacheAPI {
    associatedtype Key
    associatedtype Value

    /**
     Check if cache contains a value for key.

     - Parameter key: Unique key identifying value.

     - Returns: True if cache contains value, false otherwise.
     */
    func contains(key: Key) -> Bool

    /**
     Fetch value from cache.

     - Parameter key: Unique key identifying value.

     - Returns: Value if contained in cache, nil otherwise.
     */
    func value(forKey key: Key) throws -> Value?

    /**
     Set value for key.

     - Parameters:
        - value: Value to store.
        - key: Unique key identifying value.
        - attributes: Optional attributes for value.
     */
    func setValue(_ value: Value, forKey key: Key, attributes: CacheItemAttributes?) throws

    /**
     Remove value for key.

     - Parameter key: Unique key identifying value.
     */
    func removeValue(forKey key: Key) throws

    /**
     Remove all values.
     */
    func removeAll() throws

    /**
     Remove values conditionally.

     - Parameter predicate: Closure with item attributes as input that returns true if item is to be removed.
     */
    func remove(where predicate: @escaping (CacheItemAttributes) -> Bool) throws

    /**
     Get item attributes for key.

     - Parameter key: Unique key identifying value.

     - Returns: Attributes describing cache item.
     */
    func attributes(forKey key: Key) throws -> CacheItemAttributes?

    /**
     Set attributes for value identified by key.

     - Parameters:
        - attributes: New item attributes to set for value identified by key.
        - key: Unique key identifying value.
     */
    func setAttributes(_ attributes: CacheItemAttributes, forKey key: Key) throws
}
