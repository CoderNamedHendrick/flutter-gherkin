# Fixture-only native setup. Never apply blindly to an application project.
require 'xcodeproj'
require 'fileutils'
root = File.expand_path('../test/fixtures/minimal_app', __dir__)
project = Xcodeproj::Project.open("#{root}/ios/Runner.xcodeproj")
runner = project.targets.find { |t| t.name == 'Runner' }
target = project.targets.find { |t| t.name == 'RunnerUITests' }
unless target
  target = project.new_target(:ui_test_bundle, 'RunnerUITests', :ios, '13.0')
  target.add_dependency(runner)
  group = project.main_group.new_group('RunnerUITests', 'RunnerUITests')
  FileUtils.mkdir_p("#{root}/ios/RunnerUITests")
  File.write("#{root}/ios/RunnerUITests/RunnerUITests.m", <<~SOURCE)
    @import XCTest;
    @import patrol;
    @import ObjectiveC.runtime;
    #if !defined(PATROL_INTEGRATION_TEST_IOS_RUNNER)
    #import "PatrolIntegrationTestIosRunner.h"
    #endif
    PATROL_INTEGRATION_TEST_IOS_RUNNER(RunnerUITests)
  SOURCE
  target.source_build_phase.add_file_reference(group.new_file('RunnerUITests.m'))
  product = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  product.product_name = 'FlutterGeneratedPluginSwiftPackage'
  target.package_product_dependencies << product
  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = product
  target.frameworks_build_phase.files << build_file
  %w[build embed_and_thin].each do |action|
    phase = target.new_shell_script_build_phase("xcode_backend #{action}")
    phase.shell_script = "/bin/sh \"$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh\" #{action}"
    phase.always_out_of_date = '1'
    target.build_phases.move(phase, action == 'build' ? 0 : target.build_phases.length-1)
  end
end
runner.build_configurations.each do |config|
  config.build_settings.delete('DEVELOPMENT_TEAM')
end
target.build_configurations.each do |config|
  source = runner.build_configurations.find { |c| c.name == config.name }
  config.base_configuration_reference = source.base_configuration_reference
  config.build_settings.merge!({
    'PRODUCT_BUNDLE_IDENTIFIER'=>'dev.gherkin.minimalApp.RunnerUITests',
    'PRODUCT_NAME'=>'$(TARGET_NAME)', 'TEST_TARGET_NAME'=>'Runner', 'GENERATE_INFOPLIST_FILE'=>'YES',
    'ENABLE_USER_SCRIPT_SANDBOXING'=>'NO', 'IPHONEOS_DEPLOYMENT_TARGET'=>'13.0',
    'TARGETED_DEVICE_FAMILY'=>'1,2', 'CODE_SIGN_STYLE'=>'Automatic',
    'SWIFT_VERSION'=>'5.0', 'LD_RUNPATH_SEARCH_PATHS'=>['$(inherited)','@executable_path/Frameworks','@loader_path/Frameworks']
  })
end
project.save
scheme_path="#{root}/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme"
scheme = Xcodeproj::XCScheme.new(scheme_path)
unless scheme.test_action.testables.any? { |t| t.xml_element.to_s.include?(target.uuid) }
  scheme.add_test_target(target)
end
scheme.test_action.testables.each { |t| t.xml_element.attributes['parallelizable']='NO' }
scheme.save_as("#{root}/ios/Runner.xcodeproj", 'Runner', true)
