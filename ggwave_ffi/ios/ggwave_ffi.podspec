#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint ggwave_ffi.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'ggwave_ffi'
  s.version          = '0.0.1'
  s.summary          = 'Flutter FFI plugin for ggwave data-over-sound library.'
  s.description      = <<-DESC
Flutter FFI plugin wrapping the ggwave library for transmitting data over sound.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  s.source           = { :path => '.' }

  # All source files in Classes directory
  s.source_files = 'Classes/**/*'

  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/Classes" "$(PODS_TARGET_SRCROOT)/Classes/reed-solomon"',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++11',
    'CLANG_CXX_LIBRARY' => 'libc++'
  }
  s.swift_version = '5.0'
end
