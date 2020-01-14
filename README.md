# Cachyr

A typesafe key-value cache for iOS, iPadOS, macOS, tvOS and watchOS written in Swift.

- Thread safe.
- Link caches with different key and value types.
- Generic storage. Use the provided filesystem and memory storage, or write your own.
- Clean, single-purpose implementation. Does caching and nothing else.

## Installation

### Swift Package Manager

Add to project in Xcode. In the file navigator select your project and then the "Swift Packages" tab. Press the "+" button and add the project url.

### CocoaPods

```
Add to Podfile:
pod 'Cachyr', :git => 'https://github.com/nrkno/yr-cachyr.git'

For a specific branch:
pod 'Cachyr', :git => 'https://github.com/nrkno/yr-cachyr.git', :branch => 'master'

For a specific tag, like a release:
pod 'Cachyr', :git => 'https://github.com/nrkno/yr-cachyr.git', :tag => '2.0.0'

Then:
$ pod install
```

### Manual

Clone the repo somewhere suitable, like inside your project repo so Cachyr can be added as a subrepo, then drag `Cachyr.xcodeproj` into your project.

Alternatively build the framework and add it to your project.

## Usage

### Simple Memory Cache

```swift
let cache = Cache(storage: MemoryStorage<String, String>())
let key = "foo"
let text = "bar"
cache.setValue(text, forKey: key)
let cachedText = cache.value(forKey: key)

// Or asynchronously
let cachedText = cache.value(forKey: key) { (value) in
    // Do something with value
}
```

All caches are backed by some kind of storage. Storage for memory and the file system are included. Implement the `CacheStorage` protocol to provide custom storage.

### Linking Caches

Caches can be linked to provide cache layers. There is no automatic propagation of changes between caches with one exception; querying a cache for a value or attributes for a value will query the parent if not found (and their parent etc.), and the cache will be updated with the value from the parent if the parent can provide it. The keys and values do not have to be the same for the linked caches, you can provide transforms for both.

Here is an example of a filesystem cache with a memory cache in front, where the keys and values are the same type:

```swift
struct Book: Codable {
    let title: String
}

guard let diskStorage = FileSystemStorage<String, Book>() else { return }
let diskCache = Cache(storage: diskStorage)
let memoryCache = Cache(storage: MemoryStorage<String, Book>())
memoryCache.setCache(diskCache, as: .parent,
    keyTransformer: .identity(), valueTransformer: .identity())

let book = Book(title: "Cachyr")
diskCache.setValue(book, forKey: "cachyr")
if let foundBook = memoryCache.value(forKey: "cachyr") {
	// ...
}
```

A more advanced example with key and value transforms:

```swift
guard let dataStorage = FileSystemStorage<Int, Data>() else { return }
let dataCache = Cache(storage: dataStorage)
let memoryCache = Cache(storage: MemoryStorage<String, Book>())

let keyTransformer = Transformer<String, Int>(
    transform: { Int($0) },
    reverse: { "\($0)" })

let valueTransformer = Transformer<Book, Data>(
    transform: { try? JSONEncoder().encode($0) },
    reverse: { try? JSONDecoder().decode(Book.self, from: $0) })

memoryCache.setCache(dataCache, as: .parent,
    keyTransformer: keyTransformer, valueTransformer: valueTransformer)

let dataKey = 42
let memoryKey = "42"
let book = Book(title: "foo")
let bookData = try! JSONEncoder().encode(book)

dataCache.setValue(bookData, forKey: dataKey)
let fetchedBook = memoryCache.value(forKey: memoryKey)
```
