Pod::Spec.new do |s|
s.name             = "Stormcloud"
s.version          = "1.4.1"
s.summary          = "A JSON document manager for local and iCloud documents"
s.homepage         = "https://github.com/SimonFairbairn/Stormcloud"
s.license          = 'MIT'
s.author           = { "Simon Fairbairn" => "simon@voyagetravelapps.com" }
s.source           = { :git => "https://github.com/SimonFairbairn/Stormcloud.git", :tag => s.version }
s.social_media_url = 'https://twitter.com/SimonFairbairn'

s.ios.deployment_target = '9.0'
s.requires_arc = true

s.source_files = 'Stormcloud/'

s.frameworks = 'CoreData'
end
