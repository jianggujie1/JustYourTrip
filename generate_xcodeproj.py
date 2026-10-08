import os
import uuid

def gen_id():
    return uuid.uuid4().hex[:24].upper()

root_dir = "/Users/jianggujie1/dev/antigravityWork/JustYourTrip"
project_name = "JustYourTrip"
source_root = os.path.join(root_dir, project_name)

# Find all swift files and resources
swift_files = []
resource_files = []

for dirpath, _, filenames in os.walk(source_root):
    for f in filenames:
        if f.endswith(".swift"):
            rel_path = os.path.relpath(os.path.join(dirpath, f), root_dir)
            swift_files.append((f, rel_path))
        elif f == "Info.plist":
            rel_path = os.path.relpath(os.path.join(dirpath, f), root_dir)
            resource_files.append((f, rel_path))

swift_files.sort(key=lambda x: x[1])

# Generate UUIDs
proj_id = gen_id()
target_id = gen_id()
main_group_id = gen_id()
sources_build_phase_id = gen_id()
resources_build_phase_id = gen_id()
frameworks_build_phase_id = gen_id()
target_config_list_id = gen_id()
proj_config_list_id = gen_id()
target_debug_config_id = gen_id()
target_release_config_id = gen_id()
proj_debug_config_id = gen_id()
proj_release_config_id = gen_id()

file_entries = [] # (filename, rel_path, file_ref_id, build_file_id)
for fname, rpath in swift_files:
    file_entries.append((fname, rpath, gen_id(), gen_id()))

info_plist_entry = (resource_files[0][0], resource_files[0][1], gen_id(), None)

# Group structure: JustYourTrip root group
group_children_ids = [e[2] for e in file_entries] + [info_plist_entry[2]]

# App product reference
product_ref_id = gen_id()
products_group_id = gen_id()

# Build PBXBuildFile section
build_files_str = ""
for fname, rpath, f_id, b_id in file_entries:
    build_files_str += f"\t\t{b_id} /* {fname} in Sources */ = {{isa = PBXBuildFile; fileRef = {f_id} /* {fname} */; }};\n"

# Build PBXFileReference section
file_refs_str = ""
for fname, rpath, f_id, b_id in file_entries:
    file_refs_str += f"\t\t{f_id} /* {fname} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"{rpath}\"; sourceTree = \"<group>\"; }};\n"
file_refs_str += f"\t\t{info_plist_entry[2]} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = \"{info_plist_entry[1]}\"; sourceTree = \"<group>\"; }};\n"
file_refs_str += f"\t\t{product_ref_id} /* {project_name}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {project_name}.app; sourceTree = BUILT_PRODUCTS_DIR; }};\n"

sources_str = "".join([f"\t\t\t\t{e[3]} /* {e[0]} in Sources */,\n" for e in file_entries])

pbxproj_content = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{build_files_str}/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{file_refs_str}/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		{frameworks_build_phase_id} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{main_group_id} = {{
			isa = PBXGroup;
			children = (
				{products_group_id} /* Products */,
"""

for fname, rpath, f_id, b_id in file_entries:
    pbxproj_content += f"\t\t\t\t{f_id} /* {fname} */,\n"
pbxproj_content += f"\t\t\t\t{info_plist_entry[2]} /* Info.plist */,\n"

pbxproj_content += f"""			);
			sourceTree = "<group>";
		}};
		{products_group_id} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{product_ref_id} /* {project_name}.app */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{target_id} /* {project_name} */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {target_config_list_id} /* Build configuration list for PBXNativeTarget "{project_name}" */;
			buildPhases = (
				{sources_build_phase_id} /* Sources */,
				{frameworks_build_phase_id} /* Frameworks */,
				{resources_build_phase_id} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = {project_name};
			productName = {project_name};
			productReference = {product_ref_id} /* {project_name}.app */;
			productType = "com.apple.product-type.application";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{proj_id} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1600;
				LastUpgradeCheck = 1600;
				TargetAttributes = {{
					{target_id} = {{
						CreatedOnToolsVersion = 16.0;
					}};
				}};
			}};
			buildConfigurationList = {proj_config_list_id} /* Build configuration list for PBXProject "{project_name}" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = {main_group_id};
			productRefGroup = {products_group_id} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{target_id} /* {project_name} */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{resources_build_phase_id} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{sources_build_phase_id} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{sources_str}			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		{proj_debug_config_id} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 5.0;
			}};
			name = Debug;
		}};
		{proj_release_config_id} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				ENABLE_NS_ASSERTIONS = NO;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				MTL_ENABLE_DEBUG_INFO = NO;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
				SWIFT_VERSION = 5.0;
			}};
			name = Release;
		}};
		{target_debug_config_id} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_ASSET_PATHS = "";
				DEVELOPMENT_TEAM = JTQCQL8MVH;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = JustYourTrip/Resources/Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.yourtrip.JustYourTrip;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			}};
			name = Debug;
		}};
		{target_release_config_id} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_ASSET_PATHS = "";
				DEVELOPMENT_TEAM = JTQCQL8MVH;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = JustYourTrip/Resources/Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.yourtrip.JustYourTrip;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{proj_config_list_id} /* Build configuration list for PBXProject "{project_name}" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{proj_debug_config_id} /* Debug */,
				{proj_release_config_id} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{target_config_list_id} /* Build configuration list for PBXNativeTarget "{project_name}" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{target_debug_config_id} /* Debug */,
				{target_release_config_id} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */

	}};
	rootObject = {proj_id} /* Project object */;
}}
"""

proj_dir = os.path.join(root_dir, f"{project_name}.xcodeproj")
os.makedirs(proj_dir, exist_ok=True)
with open(os.path.join(proj_dir, "project.pbxproj"), "w", encoding="utf-8") as f:
    f.write(pbxproj_content)

# Shared scheme
shared_data_dir = os.path.join(proj_dir, "xcshareddata", "xcschemes")
os.makedirs(shared_data_dir, exist_ok=True)

scheme_content = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{target_id}"
               BuildableName = "{project_name}.app"
               BlueprintName = "{project_name}"
               ReferencedContainer = "container:{project_name}.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target_id}"
            BuildableName = "{project_name}.app"
            BlueprintName = "{project_name}"
            ReferencedContainer = "container:{project_name}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
</Scheme>
"""

with open(os.path.join(shared_data_dir, f"{project_name}.xcscheme"), "w", encoding="utf-8") as f:
    f.write(scheme_content)

print("Xcode project generated successfully!")
