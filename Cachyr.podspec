Pod::Spec.new do |s|
  s.name         = "Cachyr"
  s.version      = "2.0.0"
  s.summary      = "A thread-safe and type-safe key-value cache written in Swift."
  s.description  = <<-DESC
    Cachyr is a key-value cache written in Swift.

    - Thread safe.
    - Link caches with different key and value types.
    - Generic storage. Use the provided filesystem and memory storage, or write your own.
    - Clean, single-purpose implementation. Does caching and nothing else.
  DESC
  s.homepage     = "https://github.com/YR/Cachyr"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author             = { "Yr" => "mobil-tilbakemelding@nrk.no" }
  s.social_media_url   = ""
  s.ios.deployment_target = "10.0"
  s.osx.deployment_target = "10.12"
  s.watchos.deployment_target = "4.0"
  s.tvos.deployment_target = "10.0"
  s.source       = { :git => "https://github.com/YR/Cachyr.git", :tag => s.version.to_s }
  s.source_files  = "Sources/**/*"
  s.frameworks  = "Foundation"
end
