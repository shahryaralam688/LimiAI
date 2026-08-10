#!/usr/bin/env ruby
# Adds the "LimiAIDevice" app target (LIMI AI Device) to Limi.xcodeproj.
# Mirrors the Limi target's sources/frameworks/resources, excluding the
# @main LimiApp.swift and adding the DeviceApp/ native UI sources.

require 'xcodeproj'

PROJECT_PATH = 'Limi.xcodeproj'
TARGET_NAME = 'LimiAIDevice'
BUNDLE_ID = 'osi.shahryar.LimitLess.Device.v1'
PRODUCT_NAME = 'LIMI AI Device'

project = Xcodeproj::Project.open(PROJECT_PATH)
limi = project.targets.find { |t| t.name == 'Limi' }
abort('Limi target not found') unless limi

if project.targets.any? { |t| t.name == TARGET_NAME }
  abort("#{TARGET_NAME} already exists — remove it first")
end

target = project.new_target(:application, TARGET_NAME, :ios, '18.2')

# --- Build configurations: copy from Limi, override app identity ---
config_group = project.main_group.find_subpath('Config', false) ||
               project.main_group.groups.find { |g| g.path == 'Config' }
xcconfig_refs = {}
%w[Debug Release].each do |name|
  path = "Config/LimiAIDevice-#{name}.xcconfig"
  ref = (config_group || project.main_group).new_reference("../#{path}")
  ref.set_path(path)
  ref.set_source_tree('<group>')
  xcconfig_refs[name] = ref
end

target.build_configurations.each do |config|
  src = limi.build_configurations.find { |c| c.name == config.name }
  config.build_settings.clear
  config.build_settings.merge!(src.build_settings)
  config.base_configuration_reference = xcconfig_refs[config.name]

  config.build_settings['PRODUCT_NAME'] = PRODUCT_NAME
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = BUNDLE_ID
  config.build_settings['INFOPLIST_FILE'] = 'DeviceApp/Info.plist'
  config.build_settings['INFOPLIST_KEY_CFBundleDisplayName'] = PRODUCT_NAME
  # Device app does not require ARKit-capable hardware.
  config.build_settings.delete('INFOPLIST_KEY_UIRequiredDeviceCapabilities')
end

# --- DeviceApp group + sources ---
device_group = project.main_group.new_group('DeviceApp', 'DeviceApp')
%w[
  LimiDeviceApp.swift
  DeviceRootView.swift
  DeviceSignInView.swift
  DeviceHomeView.swift
  DeviceAddFlowView.swift
  DeviceControlView.swift
].each do |file|
  ref = device_group.new_reference(file)
  target.source_build_phase.add_file_reference(ref, true)
end
device_group.new_reference('Info.plist')

# --- Copy explicit sources from Limi (skip the @main entry) ---
limi.source_build_phase.files.each do |bf|
  ref = bf.file_ref
  next unless ref
  next if ref.path == 'LimiApp.swift'
  target.source_build_phase.add_file_reference(ref, true)
end

# --- Frameworks: system frameworks (skip the CocoaPods framework) ---
limi.frameworks_build_phase.files.each do |bf|
  ref = bf.file_ref
  next unless ref
  next if ref.path.to_s.include?('Pods_')
  target.frameworks_build_phase.add_file_reference(ref, true)
end

# --- Frameworks: Swift Package products ---
limi.package_product_dependencies.each do |dep|
  new_dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  new_dep.product_name = dep.product_name
  new_dep.package = dep.package
  target.package_product_dependencies << new_dep

  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = new_dep
  target.frameworks_build_phase.files << build_file
end

# --- Resources: fonts, usdz models, etc. ---
limi.resources_build_phase.files.each do |bf|
  ref = bf.file_ref
  next unless ref
  target.resources_build_phase.add_file_reference(ref, true)
end

# --- Features synchronized folder (assets + all feature sources) ---
features_group = project.objects.find do |o|
  o.isa == 'PBXFileSystemSynchronizedRootGroup' && o.path == 'Features'
end
abort('Features synchronized group not found') unless features_group

exception = project.new(Xcodeproj::Project::Object::PBXFileSystemSynchronizedBuildFileExceptionSet)
exception.target = target
exception.membership_exceptions = ['AddDevice/AddDeviceCoordinator.swift', 'Info.plist']
features_group.exceptions << exception

if target.respond_to?(:file_system_synchronized_groups)
  target.file_system_synchronized_groups ||= []
  target.file_system_synchronized_groups << features_group
else
  abort('xcodeproj gem too old for synchronized groups')
end

# --- rkassets build rule (same stub as Limi) ---
rule = project.new(Xcodeproj::Project::Object::PBXBuildRule)
rule.compiler_spec = 'com.apple.compilers.proxy.script'
rule.file_type = 'folder.rkassets'
rule.is_editable = '1'
rule.script = "# realitytool\n"
target.build_rules << rule

# --- RealityKitContent copy script (same as Limi) ---
phase = target.new_shell_script_build_phase('Run Script')
phase.shell_path = '/bin/sh'
phase.input_paths = ['$(PLATFORM_DIR)/Developer/Library/Frameworks/RealityKit.framework/Resources/RealityKitContent.bundle']
phase.output_paths = ['$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/RealityKitContent.bundle']
phase.shell_script = "#!/bin/sh\nFRAMEWORK_RKC=\"${PLATFORM_DIR}/Developer/Library/Frameworks/RealityKit.framework/Resources/RealityKitContent.bundle\"\nDEST=\"${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/RealityKitContent.bundle\"\nif [ -d \"$FRAMEWORK_RKC\" ]; then\n    rm -rf \"${DEST}\"\n    cp -R \"${FRAMEWORK_RKC}\" \"${DEST}\"\nfi\n"

project.save

# --- Shared scheme ---
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.set_launch_target(target)
scheme.save_as(PROJECT_PATH, TARGET_NAME, true)

puts "✅ #{TARGET_NAME} target added (#{BUNDLE_ID})"
