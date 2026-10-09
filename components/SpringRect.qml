import QtQuick
import Quickshell.Widgets
import qs.theme

ClippingRectangle {
    id: root
    property real tx: 0
    property real ty: 0
    property real tw: 0
    property real th: 0
    property real tr: 0
    property bool notch: false
    property bool springX: true
    property bool springY: true
    property bool springWidth: true
    property bool springHeight: true
    // Shrinking must not overshoot below the target: a 514 px panel collapsing to a
    // 33 px circle would otherwise dip to a ~5 px dot before bouncing back.
    property bool clampShrink: true
    // Content-driven resizes inside an open panel (e.g. launcher results) use Motion.panel.
    property QtObject heightToken: Motion.island

    property real sw: tw
    property real sh: th
    property real sr: tr
    property real _lastTw: tw
    property real _lastTh: th
    property real _lastTr: tr
    property bool _shrinkingW: false
    property bool _shrinkingH: false
    property bool _shrinkingR: false
    onTwChanged: { _shrinkingW = tw < _lastTw; _lastTw = tw }
    onThChanged: { _shrinkingH = th < _lastTh; _lastTh = th }
    onTrChanged: { _shrinkingR = tr < _lastTr; _lastTr = tr }

    x: tx
    y: ty
    width: clampShrink && _shrinkingW ? Math.max(sw, tw) : sw
    height: clampShrink && _shrinkingH ? Math.max(sh, th) : sh
    radius: clampShrink && _shrinkingR ? Math.max(sr, tr) : sr
    topLeftRadius: notch ? 0 : radius
    topRightRadius: notch ? 0 : radius
    bottomLeftRadius: radius
    bottomRightRadius: radius
    color: Theme.island
    Behavior on x { enabled: root.springX; Spring { token: Motion.island } }
    Behavior on y { enabled: root.springY; Spring { token: Motion.island } }
    Behavior on sw { enabled: root.springWidth; Spring { token: Motion.island } }
    Behavior on sh { enabled: root.springHeight; Spring { token: root.heightToken } }
    Behavior on sr { Spring { token: Motion.island } }
}
