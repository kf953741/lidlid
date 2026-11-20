#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h:h}"
swift build --package-path "$ROOT" -c release
BIN_DIR="$(swift build --package-path "$ROOT" -c release --show-bin-path)"
WORK="$(mktemp -d "$ROOT/.build/store-model.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
if [[ -f "$BIN_DIR/LidOnceCore.o" ]]; then
    MODULES="$BIN_DIR"
    OBJECTS=("$BIN_DIR/LidOnceCore.o" "$BIN_DIR/LidOnceSystem.o" "$BIN_DIR/LidLidServiceProtocol.o")
else
    MODULES="$BIN_DIR/Modules"
    OBJECTS=("$BIN_DIR"/LidOnceCore.build/*.o "$BIN_DIR"/LidOnceSystem.build/*.o "$BIN_DIR"/LidLidServiceProtocol.build/*.o)
fi
swiftc -parse-as-library -swift-version 5 -I "$MODULES" \
    "$ROOT/Sources/LidOnce/App.swift" "$ROOT/Sources/LidOnce/GuardianMenuSymbol.swift" \
    "$ROOT/Sources/LidOnce/StoreConfirmationPresenter.swift" \
    "$ROOT/Sources/LidOnce/PanelStyle.swift" \
    "$ROOT/Sources/LidOnce/CompatibilitySetupPresenter.swift" \
    "$ROOT/scripts/fixtures/StoreModelHarness.swift" "${OBJECTS[@]}" \
    -framework AppKit -framework SwiftUI -framework ServiceManagement -framework Security -framework IOKit \
    -o "$WORK/store-model-test"
for PHASE in armed closed; do
    "$WORK/store-model-test" "$ROOT/scripts/fixtures/store-policy-agent.py" \
        "$WORK/snapshot-$PHASE.json" "$WORK/commands-$PHASE.jsonl" "$PHASE"
done
