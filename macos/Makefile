# The native shell (parley-019). Needs Xcode 26 and XcodeGen.
#   make -C macos test     ParleyCore unit tests (swift test)
#   make -C macos build    engine bundle + Parley.app (Debug)
#   make -C macos run      build, then open the app

DERIVED := build/DerivedData
APP := $(DERIVED)/Build/Products/Debug/Parley.app

.PHONY: project build test run clean

project:
	xcodegen generate --quiet

build: project
	xcodebuild -project Parley.xcodeproj -scheme Parley -configuration Debug \
		-derivedDataPath $(DERIVED) -allowProvisioningUpdates build -quiet

test:
	cd ParleyCore && swift test --quiet

run: build
	open $(APP)

clean:
	rm -rf build Parley.xcodeproj ParleyCore/.build
