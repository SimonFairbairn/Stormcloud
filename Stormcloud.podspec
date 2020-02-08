Pod::Spec.new do |s|
s.name             = "Stormcloud"
s.version          = "3.1.0"
s.summary          = "A JSON document manager for local and iCloud documents"
s.homepage         = "https://github.com/SimonFairbairn/Stormcloud"
s.license          = 'MIT'
s.author           = { "Simon Fairbairn" => "simon@voyagetravelapps.com" }
s.source           = { :git => "https://github.com/SimonFairbairn/Stormcloud.git", :tag => s.version }
s.social_media_url = 'https://twitter.com/SimonFairbairn'

s.ios.deployment_target = '11.0'
s.swift_version = '5'

s.source_files = 'Sources/Stormcloud/'

s.frameworks = 'CoreData'
end
