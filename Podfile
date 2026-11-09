platform :ios, '15.0'

inhibit_all_warnings!

target 'FlexRupee' do
  use_frameworks!
  pod 'SnapKit'
  pod 'Moya/RxSwift', '13.0.1'
  pod 'ObjectMapper', '3.4.2'
  pod 'Adjust', '~> 5.4.5'
  pod 'GoogleAdsOnDeviceConversion', '3.0.0'
  pod 'Kingfisher'
  pod 'YYStarView'
  pod 'IQKeyboardManagerSwift', '~> 6.5.1'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
    end
  end
end
