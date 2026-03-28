.PHONY: run build test app clean

run:
	swift run

test:
	swift run ThreeDoTests

build:
	swift build -c release

app: build
	@echo "Creating ThreeDo.app bundle..."
	@rm -rf .build/ThreeDo.app
	@mkdir -p .build/ThreeDo.app/Contents/MacOS
	@mkdir -p .build/ThreeDo.app/Contents/Resources
	@cp .build/release/ThreeDo .build/ThreeDo.app/Contents/MacOS/ThreeDo
	@cp Resources/Info.plist .build/ThreeDo.app/Contents/Info.plist
	@echo "Done: .build/ThreeDo.app"
	@open .build/ThreeDo.app

clean:
	swift package clean
	rm -rf .build/ThreeDo.app
