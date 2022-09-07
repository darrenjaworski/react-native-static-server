require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

folly_version = '2021.07.22.00'
folly_compiler_flags = '-DFOLLY_NO_CONFIG -DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1 -Wno-comma -Wno-shorten-64-to-32'

Pod::Spec.new do |s|
  s.name           = 'react-native-static-server'
  s.version        = package['version']
  s.summary        = package['title']
  s.description    = package['description']
  s.license        = package['license']
  s.authors        = {
    'Dr. Sergey Pogodin' => 'doc@pogodin.studio',
    'Fred Chasen' => 'fchasen@gmail.com'
  }
  s.homepage       = package['homepage']
  s.source         = {
    :git => 'https://github.com/birdofpreyru/react-native-static-server.git',
    :tag => 'v' + package['version']
  }

  s.requires_arc   = true
  s.platform       = :ios, '12.4'

  s.preserve_paths = 'README.md', 'package.json', 'index.js'
  s.source_files   = "ios/**/*.{h,m,mm,swift}"

  s.dependency 'React-Core'
  s.dependency 'GCDWebServer', '~> 3.0'

  # This guard prevent to install the dependencies when we run `pod install` in the old architecture.
  if ENV['RCT_NEW_ARCH_ENABLED'] == '1' then
        s.compiler_flags = folly_compiler_flags + " -DRCT_NEW_ARCH_ENABLED=1"
        s.pod_target_xcconfig    = {
            "HEADER_SEARCH_PATHS" => "\"$(PODS_ROOT)/boost\"",
            "CLANG_CXX_LANGUAGE_STANDARD" => "c++17"
        }

        s.dependency "React-Codegen"
        s.dependency "RCT-Folly", folly_version
        s.dependency "RCTRequired"
        s.dependency "RCTTypeSafety"
        s.dependency "ReactCommon/turbomodule/core"
    end
end
