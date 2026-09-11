Pod::Spec.new do |s|
  s.name             = 'volume_button_override'
  s.version          = '0.0.1'
  s.summary          = 'Android ve iOS platformlarında ses tuşlarını özelleştirebilen bir eklenti.'
  s.description      = <<-DESC
Android ve iOS platformlarında ses tuşlarını özelleştirebilen bir eklenti. Bu eklenti, ses tuşlarına özel işlevler atayabilmenizi sağlar.
                       DESC
  s.homepage         = 'https://github.com/yigithanyaramis/volume_button_override'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Yigithan Yaramis' => 'yigithanyaramis@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '11.0'
  s.frameworks       = ['MediaPlayer', 'AVFoundation']
  
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
