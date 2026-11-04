import QtQuick

// The settings' small choice rows ("small · normal · large", "off · calm · full"): Tabs in
// its segmented look. Same API as Tabs: model, current, signal selected(key).
//
//   SegmentedButtons {
//       model: [{ key: "small", label: "small" }, { key: "round", label: "round" }, …]
//       current: Config.corners
//       onSelected: key => Config.set("corners", key)
//   }
Tabs {
    variant: "segmented"
}
