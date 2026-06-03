require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

ext_target = project.targets.find { |t| t.name == 'GamenectScreenShare' }
if ext_target.nil?
  puts "Target GamenectScreenShare not found"
  exit 1
end

# Remove all CocoaPods phases from Extension (if any left)
ext_target.build_phases.delete_if { |p| p.display_name.include?('Pods') }

# Find or add Frameworks group
frameworks_group = project.main_group.find_subpath('Frameworks', true)

# Path to the framework
framework_path = 'Pods/AgoraRtcEngine_iOS/AgoraReplayKitExtension.xcframework'

# Remove existing reference if any
existing_ref = frameworks_group.files.find { |f| f.path == framework_path }
existing_ref.remove_from_project if existing_ref

# Add file reference
file_ref = frameworks_group.new_file(framework_path)

# Add to Frameworks Build Phase
frameworks_build_phase = ext_target.frameworks_build_phase
frameworks_build_phase.files_references.each do |ref|
  if ref.path == framework_path
    frameworks_build_phase.remove_file_reference(ref)
  end
end
frameworks_build_phase.add_file_reference(file_ref)

project.save
puts "Successfully linked AgoraReplayKitExtension to GamenectScreenShare"
