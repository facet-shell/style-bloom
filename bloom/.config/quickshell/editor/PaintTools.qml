import QtQuick

// What the picture editor's toolbar picked, shared by the toolbar (PaintToolbar) and the
// canvas (PaintCanvas).
QtObject {
    // pen | mark | line | arrow | rect | ellipse | text | erase; "": nothing is drawn, blur
    // boxes and the crop take the mouse
    property string tool: "pen"
    // A Theme role (PaintEngine.COLORS)
    property string color: "tertiary"
    // Screen pixels (PaintEngine.WIDTHS); a new shape stores it in picture pixels
    property real width: 4
    property bool ruler: false
    // { x, y, a, len, h } in picture pixels; placed by the canvas when it is turned on
    property var rulerAt: null
}
