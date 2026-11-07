import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.config
import "PaintEngine.js" as Engine

// The picture editor: blur boxes and pictures on top of a screenshot (or any picture), a
// drawing (the paint tools in a column on the left) and a crop, exported as <name>-edit.png.
// Same boxes as the video editor (OverlayBox.qml), no timeline. Paint is this editor with an
// empty page (Editor.newPicture). Loaded by EditorWindow.qml.
FocusScope {
    id: root

    signal closeRequested()

    readonly property alias project: project
    // { kind: "overlay", id } | null
    property var selected: null
    property bool cropping: false
    // "export & delete original" waits for a yes
    property bool confirmRaw: false
    readonly property bool painting: project.image.includes("/paintings/")

    readonly property var selOverlay: selected?.kind === "overlay" ? project.overlay(selected.id) : null

    ImageProject {
        id: project

        // The picture is gone after "export & delete original"; nothing is written back for it
        onOriginalDeleted: {
            dirty = false;
            root.closeRequested();
        }
    }

    function fileUrl(path) {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    // The drawing tools; "" is the pointer (blur boxes and crop). An empty page from paint
    // starts with the pen, a screenshot with the pointer.
    PaintTools {
        id: paintTools
        tool: ""
    }

    function openFile(path) {
        selected = null;
        cropping = false;
        confirmRaw = false;
        paintTools.tool = path.includes("/paintings/") ? "pen" : "";
        project.load(path);
        picture.source = fileUrl(path);
        forceActiveFocus();
    }

    // Same calls as the video editor, nothing plays here
    function pause() {
    }

    function select(s) {
        selected = s;
    }

    function addBlur() {
        cropping = false;
        paintTools.tool = "";
        select({ kind: "overlay", id: project.addBlur(0.5, 0.5) });
    }

    function toggleCrop() {
        cropping = !cropping;
        if (cropping)
            paintTools.tool = "";
    }

    function removeSelected() {
        if (selected?.kind !== "overlay")
            return;
        project.removeOverlay(selected.id);
        select(null);
    }

    function close() {
        project.writeNow();
        closeRequested();
    }

    Keys.onPressed: event => {
        const ctrl = event.modifiers & Qt.ControlModifier;
        const shift = event.modifiers & Qt.ShiftModifier;
        if (event.key === Qt.Key_B && !ctrl)
            addBlur();
        else if (event.key === Qt.Key_C && !ctrl)
            toggleCrop();
        else if (event.key === Qt.Key_V && !ctrl)
            paintTools.tool = "";
        else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace)
            removeSelected();
        else if ((event.key === Qt.Key_Z && ctrl && shift) || (event.key === Qt.Key_Y && ctrl)) {
            if (project.redo())
                select(null);
        } else if (event.key === Qt.Key_Z && ctrl) {
            if (project.undo())
                select(null);
        } else if (event.key === Qt.Key_S && ctrl)
            project.startExport(false);
        else if (event.key === Qt.Key_Escape) {
            select(null);
            cropping = false;
            paintTools.tool = "";
        } else if (toolbar.handleKey(event)) {
            // A drawing tool's letter (p h l a r e t x)
            cropping = false;
            select(null);
        } else
            return;
        event.accepted = true;
    }

    // The drawing at the picture's full size for the export (ImageProject.drawingNeeded). A
    // Canvas paints only inside the window, so it sits in a clipped 1×1 corner, out of
    // sight, and has the picture's size only while an export waits for it.
    Item {
        width: 1
        height: 1
        clip: true

        Canvas {
            id: exportInk

            property string file: ""

            width: file !== "" ? Math.max(1, project.imageWidth) : 1
            height: file !== "" ? Math.max(1, project.imageHeight) : 1
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.clearRect(0, 0, width, height);
                // The same font as on screen (PaintCanvas)
                if (file !== "")
                    Engine.paintShapes(ctx, project.shapes, { ox: 0, oy: 0, k: 1 }, role => Theme[role] ?? Theme.tertiary, Theme.mono);
            }
            onPainted: {
                if (file === "" || width !== project.imageWidth)
                    return;
                const target = file;
                file = "";
                renderTimeout.stop();
                project.drawingReady(save(target));
            }
        }

        Timer {
            id: renderTimeout
            interval: 8000
            onTriggered: {
                exportInk.file = "";
                project.drawingReady(false);
            }
        }

        Connections {
            target: project

            function onDrawingNeeded(file) {
                exportInk.file = file;
                renderTimeout.restart();
                exportInk.requestPaint();
            }
        }
    }

    // ── Building blocks ──────────────────────────────────────

    component Panel: Rectangle {
        radius: Theme.rounding.large
        color: Theme.surface
    }

    component Note: StyledText {
        Layout.fillWidth: true
        dim: true
        wrapMode: Text.Wrap
        font.pixelSize: Theme.size.small
    }

    // Outside the crop: the page's dark tone over the picture
    component Shade: Rectangle {
        color: Theme.scrim
    }

    // A round handle of the crop
    component CropHandle: Rectangle {
        width: 16
        height: 16
        radius: width / 2
        color: Theme.primary
        border.width: 2
        border.color: Theme.textOnPrimary
    }

    // ── Layout ───────────────────────────────────────────────

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.padding.drawer
        spacing: Theme.spacing.medium

        // Title and close
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.medium

            Rectangle {
                implicitWidth: 40
                implicitHeight: 40
                radius: height / 2
                color: Theme.primaryContainer

                Icon {
                    anchors.centerIn: parent
                    icon: root.painting ? "brush" : "photo"
                    color: Theme.textOnPrimaryContainer
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: project.name
                    font.pixelSize: Theme.size.medium
                    font.weight: Font.Medium
                }
                StyledText {
                    Layout.fillWidth: true
                    dim: true
                    font.pixelSize: Theme.size.small
                    text: `${root.painting ? "paint" : "picture"}${project.imageWidth > 0 ? ` · ${project.imageWidth}×${project.imageHeight}` : ""}`
                }
            }

            IconButton {
                icon: "close"
                onClicked: root.close()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.spacing.medium

            PaintToolbar {
                id: toolbar

                Layout.alignment: Qt.AlignTop
                tools: paintTools
                store: project

                Connections {
                    target: paintTools

                    // A drawing tool takes the mouse from the boxes and the crop
                    function onToolChanged() {
                        if (paintTools.tool !== "") {
                            root.cropping = false;
                            root.select(null);
                        }
                        root.forceActiveFocus();
                    }
                }
            }

            Panel {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.padding.normal
                    spacing: Theme.spacing.normal

                    Item {
                        id: stage

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.rounding.medium
                            color: Theme.page
                        }

                        Image {
                            id: picture

                            anchors.fill: parent
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: false
                            onStatusChanged: {
                                if (status === Image.Ready) {
                                    project.imageWidth = implicitWidth;
                                    project.imageHeight = implicitHeight;
                                }
                            }
                        }

                        // The picture's own rectangle inside the stage; overlays are fractions of it
                        Item {
                            id: frameArea

                            // In the picture's own coordinates too: the blur boxes read it by this rectangle
                            x: (picture.width - picture.paintedWidth) / 2
                            y: (picture.height - picture.paintedHeight) / 2
                            width: picture.paintedWidth
                            height: picture.paintedHeight

                            MouseArea {
                                anchors.fill: parent
                                onPressed: root.select(null)
                            }

                            Repeater {
                                model: project.overlays.length

                                delegate: OverlayBox {
                                    required property int index

                                    o: project.overlays[index] ?? null
                                    store: project
                                    facet: frameArea
                                    capture: picture
                                    nativeWidth: project.imageWidth
                                    selected: o !== null && root.selOverlay !== null && root.selOverlay.id === o.id
                                    onPicked: {
                                        root.select({ kind: "overlay", id: o.id });
                                        root.cropping = false;
                                        root.forceActiveFocus();
                                    }
                                }
                            }

                            // The drawing, above the boxes like in the export; in picture pixels.
                            // With the pointer (no drawing tool) clicks go to the boxes below.
                            PaintCanvas {
                                anchors.fill: parent
                                store: project
                                tools: paintTools
                                scale: project.imageWidth > 0 ? frameArea.width / project.imageWidth : 1
                                active: paintTools.tool !== "" && !root.cropping && project.imageWidth > 0
                                keyTarget: root
                            }

                            // ── Crop: shaded outside, the kept part framed ──
                            Item {
                                id: cropBox

                                readonly property var c: project.crop

                                anchors.fill: parent
                                visible: root.cropping || project.cropped

                                Shade { x: 0; y: 0; width: parent.width; height: cropRect.y }
                                Shade { x: 0; y: cropRect.y + cropRect.height; width: parent.width; height: parent.height - y }
                                Shade { x: 0; y: cropRect.y; width: cropRect.x; height: cropRect.height }
                                Shade { x: cropRect.x + cropRect.width; y: cropRect.y; width: parent.width - x; height: cropRect.height }

                                Rectangle {
                                    id: cropRect

                                    x: cropBox.c.x * frameArea.width
                                    y: cropBox.c.y * frameArea.height
                                    width: cropBox.c.w * frameArea.width
                                    height: cropBox.c.h * frameArea.height
                                    color: "transparent"
                                    border.width: 2
                                    border.color: root.cropping ? Theme.primary : Theme.outline

                                    MouseArea {
                                        property point start
                                        property var from

                                        anchors.fill: parent
                                        enabled: root.cropping
                                        cursorShape: Qt.SizeAllCursor
                                        onPressed: mouse => {
                                            project.snapshot();
                                            start = mapToItem(frameArea, mouse.x, mouse.y);
                                            from = Object.assign({}, project.crop);
                                        }
                                        onPositionChanged: mouse => {
                                            if (!pressed)
                                                return;
                                            const p = mapToItem(frameArea, mouse.x, mouse.y);
                                            project.setCrop({
                                                x: Math.max(0, Math.min(1 - from.w, from.x + (p.x - start.x) / frameArea.width)),
                                                y: Math.max(0, Math.min(1 - from.h, from.y + (p.y - start.y) / frameArea.height)),
                                                w: from.w,
                                                h: from.h
                                            }, false);
                                        }
                                    }

                                    // Corners: top left and bottom right
                                    Repeater {
                                        model: ["tl", "br"]

                                        delegate: CropHandle {
                                            id: corner

                                            required property string modelData

                                            visible: root.cropping
                                            x: (modelData === "tl" ? 0 : cropRect.width) - width / 2
                                            y: (modelData === "tl" ? 0 : cropRect.height) - height / 2
                                            scale: cornerArea.pressed ? 1.25 : cornerArea.containsMouse ? 1.12 : 1

                                            Behavior on scale {
                                                SpringAnim {}
                                            }

                                            MouseArea {
                                                id: cornerArea

                                                property point start
                                                property var from

                                                anchors.fill: parent
                                                anchors.margins: -6
                                                hoverEnabled: true
                                                cursorShape: Qt.SizeFDiagCursor
                                                onPressed: mouse => {
                                                    project.snapshot();
                                                    start = mapToItem(frameArea, mouse.x, mouse.y);
                                                    from = Object.assign({}, project.crop);
                                                }
                                                onPositionChanged: mouse => {
                                                    if (!pressed)
                                                        return;
                                                    const p = mapToItem(frameArea, mouse.x, mouse.y);
                                                    const dx = (p.x - start.x) / frameArea.width;
                                                    const dy = (p.y - start.y) / frameArea.height;
                                                    if (corner.modelData === "tl") {
                                                        const x = Math.max(0, Math.min(from.x + from.w - 0.02, from.x + dx));
                                                        const y = Math.max(0, Math.min(from.y + from.h - 0.02, from.y + dy));
                                                        project.setCrop({ x, y, w: from.x + from.w - x, h: from.y + from.h - y }, false);
                                                    } else {
                                                        project.setCrop({ x: from.x, y: from.y, w: from.w + dx, h: from.h + dy }, false);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Pictures dragged in from Dolphin land where they are dropped
                        DropArea {
                            anchors.fill: parent
                            onEntered: drag => drag.accepted = drag.hasUrls
                            onDropped: drop => {
                                const p = frameArea.mapFromItem(stage, drop.x, drop.y);
                                for (const url of drop.urls) {
                                    const path = decodeURIComponent(url.toString().replace(/^file:\/\//, ""));
                                    if (!/\.(png|jpe?g|webp|gif|bmp)$/i.test(path))
                                        continue;
                                    const id = project.addPicture(path,
                                        Math.max(0, Math.min(1, p.x / frameArea.width)), Math.max(0, Math.min(1, p.y / frameArea.height)));
                                    root.select({ kind: "overlay", id });
                                }
                                drop.accept();
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            visible: picture.status === Image.Error
                            spacing: Theme.spacing.normal

                            Icon {
                                Layout.alignment: Qt.AlignHCenter
                                icon: "broken_image"
                                size: Theme.icon.huge
                                color: Theme.error
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Cannot open this picture"
                                color: Theme.error
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacing.normal

                        Chip {
                            text: "blur"
                            icon: "blur_on"
                            onClicked: root.addBlur()
                        }
                        Chip {
                            text: "crop"
                            icon: "crop"
                            selected: root.cropping
                            onClicked: root.toggleCrop()
                        }
                        Chip {
                            text: "pictures…"
                            icon: "add_photo_alternate"
                            onClicked: Quickshell.execDetached(["xdg-open", `${Quickshell.env("HOME")}/Pictures`])
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.leftMargin: Theme.spacing.small
                            dim: true
                            font.pixelSize: Theme.size.tiny
                            // The toolbar's hover names the button here, where there is room
                            text: toolbar.hint !== "" ? toolbar.hint
                                : "b blur box · c crop · p h l a r e t x draw · v pointer · ctrl+z undo · ctrl+s export · drop a picture on it"
                        }

                        Button {
                            visible: !root.confirmRaw
                            text: project.exporting ? "exporting…" : "export"
                            icon: "file_export"
                            variant: "filled"
                            disabled: project.exporting || project.imageWidth <= 0
                            onClicked: project.startExport(false)
                        }

                        Button {
                            visible: !project.exporting && !root.confirmRaw
                            text: "export & delete original"
                            icon: "delete"
                            variant: "danger"
                            disabled: project.imageWidth <= 0
                            onClicked: root.confirmRaw = true
                        }

                        // Asked in place: no dialog
                        StyledText {
                            visible: root.confirmRaw
                            text: "Then the original goes into the trash?"
                            color: Theme.error
                            font.pixelSize: Theme.size.small
                        }

                        Button {
                            visible: root.confirmRaw
                            text: "yes"
                            variant: "danger"
                            onClicked: {
                                root.confirmRaw = false;
                                project.startExport(true);
                            }
                        }

                        Button {
                            visible: root.confirmRaw
                            text: "no"
                            variant: "text"
                            onClicked: root.confirmRaw = false
                        }
                    }
                }
            }

            // The inspector
            Panel {
                Layout.preferredWidth: 320
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.padding.card
                    spacing: Theme.spacing.medium

                    StyledText {
                        text: root.selOverlay === null ? (root.painting ? "Painting" : "Picture")
                            : root.selOverlay.type === "blur" ? "Blur box" : "Picture on top"
                        color: Theme.primary
                        font.pixelSize: Theme.size.small
                        font.weight: Font.DemiBold
                    }

                    // Nothing picked: the picture and its crop
                    ColumnLayout {
                        visible: root.selOverlay === null
                        Layout.fillWidth: true
                        spacing: Theme.spacing.normal

                        StyledText {
                            Layout.fillWidth: true
                            text: project.name
                            font.weight: Font.Medium
                        }
                        Note {
                            text: `${project.overlays.filter(o => o.type === "picture").length} pictures · ${project.overlays.filter(o => o.type === "blur").length} blur boxes · ${project.shapes.length} drawn`
                        }
                        Note {
                            text: project.cropped && project.imageWidth > 0
                                ? `Cropped to ${Math.round(project.crop.w * project.imageWidth)}×${Math.round(project.crop.h * project.imageHeight)} px`
                                : "Not cropped"
                        }
                        Button {
                            visible: project.cropped
                            text: "undo the crop"
                            icon: "crop_free"
                            onClicked: project.setCrop({ x: 0, y: 0, w: 1, h: 1 })
                        }
                        Note {
                            wrapMode: Text.WrapAnywhere
                            text: `export: ${project.exportFile.slice(project.exportFile.lastIndexOf("/") + 1)}`
                        }
                        Note {
                            visible: project.exportError !== ""
                            color: Theme.error
                            text: project.exportError
                        }
                    }

                    // A picture or a blur box
                    ColumnLayout {
                        readonly property var o: root.selOverlay

                        visible: root.selOverlay !== null
                        Layout.fillWidth: true
                        spacing: Theme.spacing.medium

                        StyledText {
                            Layout.fillWidth: true
                            text: parent.o?.name ?? ""
                            font.weight: Font.Medium
                        }

                        SegmentedButtons {
                            visible: parent.o?.type === "blur"
                            model: [{ key: "blur", label: "blur", icon: "blur_on" }, { key: "pixel", label: "pixelate", icon: "grid_on" }]
                            current: root.selOverlay?.style === "pixel" ? "pixel" : "blur"
                            onSelected: key => project.updateOverlay(root.selOverlay.id, { style: key })
                        }

                        RowLayout {
                            visible: parent.o?.type === "blur"
                            Layout.fillWidth: true
                            spacing: Theme.spacing.medium

                            StyledText {
                                text: "strength"
                                dim: true
                                font.pixelSize: Theme.size.small
                                Layout.preferredWidth: 64
                            }
                            Slider {
                                Layout.fillWidth: true
                                thin: true
                                value: ((root.selOverlay?.strength ?? 14) - 4) / 26
                                onMoved: v => project.updateOverlay(root.selOverlay.id, { strength: Math.round(4 + v * 26) }, false)
                            }
                            StyledText {
                                text: String(root.selOverlay?.strength ?? "")
                                tabular: true
                                font.pixelSize: Theme.size.small
                                horizontalAlignment: Text.AlignRight
                                Layout.preferredWidth: 36
                            }
                        }

                        RowLayout {
                            visible: parent.o?.type === "picture"
                            Layout.fillWidth: true
                            spacing: Theme.spacing.medium

                            StyledText {
                                text: "opacity"
                                dim: true
                                font.pixelSize: Theme.size.small
                                Layout.preferredWidth: 64
                            }
                            Slider {
                                Layout.fillWidth: true
                                thin: true
                                value: root.selOverlay?.opacity ?? 1
                                onMoved: v => project.updateOverlay(root.selOverlay.id, { opacity: Math.max(0.05, v) }, false)
                            }
                            StyledText {
                                text: `${Math.round((root.selOverlay?.opacity ?? 1) * 100)}%`
                                tabular: true
                                font.pixelSize: Theme.size.small
                                horizontalAlignment: Text.AlignRight
                                Layout.preferredWidth: 44
                            }
                        }

                        Note {
                            text: parent.o && project.imageWidth > 0
                                ? `x ${Math.round(parent.o.x * project.imageWidth)} · y ${Math.round(parent.o.y * project.imageHeight)} · ${Math.round(parent.o.w * project.imageWidth)}×${Math.round((parent.o.h > 0 ? parent.o.h : parent.o.w) * project.imageHeight)} px`
                                : ""
                        }

                        Button {
                            text: "remove"
                            icon: "delete"
                            variant: "danger"
                            onClicked: root.removeSelected()
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
        }
    }
}
