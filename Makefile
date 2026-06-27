generate:
	@osascript -e 'tell application "Xcode" to quit' 2>/dev/null; true
	tuist generate
	@find . -path "*/Projects/*/project.pbxproj" | while read f; do \
		grep -q "LastUpgradeCheck" "$$f" || \
		sed -i '' 's/attributes = {/attributes = {\n\t\t\tLastUpgradeCheck = 2640;/' "$$f"; \
	done
	open Application.xcworkspace
