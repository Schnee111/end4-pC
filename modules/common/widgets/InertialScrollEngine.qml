import QtQuick
import qs.modules.common

/**
 * Inertial scroll engine.
 *
 * ARCHITECTURE: This item is placed INSIDE the Flickable (as a child).
 * It does NOT handle events itself — instead, it exposes handleWheel()
 * which is called by a WheelHandler or MouseArea on the Flickable or its parent.
 *
 * Implements two scrolling paths:
 * 1. TOUCHPAD: Direct 1:1 finger tracking + natural kinetic fling after lift + bounds spring.
 * 2. MOUSE WHEEL: Smooth animated target stepping using OutCubic bezier easing.
 */
Item {
    id: root

    required property var flickable

    // === Config helpers (with defensive normalization for legacy config values) ===
    readonly property real _cfgTouchpadFactor: {
        var f = Config?.options?.interactions?.scrolling?.touchpadScrollFactor ?? 1.0
        return (f > 10) ? 1.0 : f // Normalize legacy values (e.g. 200) to 1.0
    }
    readonly property real _cfgMouseFactor: {
        var f = Config?.options?.interactions?.scrolling?.mouseScrollFactor ?? 1.0
        return (f > 10) ? 1.0 : f // Normalize legacy values (e.g. 120) to 1.0
    }

    // === Touchpad physics ===
    property real flingFriction: Config?.options?.interactions?.scrolling?.flingFriction ?? 0.002
    property real flingStopThreshold: Config?.options?.interactions?.scrolling?.flingStopThreshold ?? 0.01
    property real flingMinVelocity: 0.15 // px/ms threshold to launch fling
    property real touchpadSensitivity: (Config?.options?.interactions?.scrolling?.touchpadSensitivity ?? 1.0)
                                       * _cfgTouchpadFactor
    property real bounceDamping: Config?.options?.interactions?.scrolling?.bounceDamping ?? 0.3

    // === Mouse wheel physics ===
    property int wheelScrollAmount: Math.round(
        (Config?.options?.interactions?.scrolling?.wheelScrollAmount ?? 100)
        * _cfgMouseFactor)
    property int wheelDurationMin: Config?.options?.interactions?.scrolling?.wheelDurationMin ?? 180
    property int wheelDurationMax: Config?.options?.interactions?.scrolling?.wheelDurationMax ?? 350
    property int mouseScrollDeltaThreshold: Config?.options?.interactions?.scrolling?.mouseScrollDeltaThreshold ?? 120

    // === Internal state ===
    property real _velocity: 0
    property real _wheelTargetY: 0
    property real _lastEventTime: 0
    property real _lastTouchpadTime: 0
    property var  _velocitySamples: []

    Timer {
        id: liftTimer
        interval: 80
        repeat: false
        onTriggered: root._computeAndStartFling()
    }

    FrameAnimation {
        id: physicsLoop
        running: false
        onTriggered: {
            var dt = frameTime * 1000
            if (dt <= 0 || dt > 50) dt = 16.67
            var maxY = Math.max(0, root.flickable.contentHeight - root.flickable.height)
            var y = root.flickable.contentY

            if (y < 0) {
                // Overscrolled at top: absorb velocity and spring back to 0
                if (root._velocity < -0.05) {
                    root._velocity *= 0.65
                    y += root._velocity * dt
                } else {
                    root._velocity = 0
                    y += (0 - y) * 0.25
                }
            } else if (y > maxY) {
                // Overscrolled at bottom: absorb velocity and spring back to maxY
                if (root._velocity > 0.05) {
                    root._velocity *= 0.65
                    y += root._velocity * dt
                } else {
                    root._velocity = 0
                    y += (maxY - y) * 0.25
                }
            } else {
                // Inside bounds: exponential velocity decay
                root._velocity *= Math.pow(1.0 - root.flingFriction, dt)
                y += root._velocity * dt
            }

            root.flickable.contentY = y

            // Stopping condition: low velocity and at or within bounds
            var nearZero = Math.abs(y) < 0.5
            var nearMax = Math.abs(y - maxY) < 0.5
            var lowVelocity = Math.abs(root._velocity) < root.flingStopThreshold

            if (lowVelocity && (y >= 0 && y <= maxY || nearZero || nearMax)) {
                if (nearZero) root.flickable.contentY = 0
                else if (nearMax) root.flickable.contentY = maxY
                root._velocity = 0
                running = false
            }
        }
    }

    NumberAnimation {
        id: wheelAnim
        target: root.flickable
        property: "contentY"
        easing.type: Easing.OutCubic
    }

    // =========================================================
    // Public API: called by WheelHandler or MouseArea onWheel
    // =========================================================
    function handleWheel(event) {
        var dy = event.angleDelta ? event.angleDelta.y : 0
        var dx = event.angleDelta ? event.angleDelta.x : 0
        var px = (event.pixelDelta && event.pixelDelta.y !== undefined) ? event.pixelDelta.y : 0
        if (dy === 0 && dx === 0 && px === 0) return

        var enabled = Config?.options?.interactions?.scrolling?.fasterTouchpadScroll
        if (enabled === false) return

        // Distinguish touchpad vs mouse wheel reliably:
        // 1. Non-zero pixelDelta is exclusively emitted by touchpads on Linux/Wayland.
        // 2. Qt.ScrollPhase (Begin/Update/End/Momentum) is exclusively emitted by touchpads.
        // 3. angleDelta not an exact multiple of 120 indicates high-res continuous touchpad scroll.
        // 4. Any event within 250ms of a previous touchpad event belongs to the same continuous gesture.
        var now = Date.now()
        var hasPixelDelta = (px !== 0) || (event.pixelDelta && event.pixelDelta.x !== 0)
        var hasScrollPhase = (event.phase !== undefined && event.phase !== Qt.NoScrollPhase)
        var isContinuousAngle = (dy !== 0 && Math.abs(dy) % 120 !== 0)
        var inTouchpadGesture = (now - root._lastTouchpadTime < 250)

        var isTouchpad = hasPixelDelta || hasScrollPhase || isContinuousAngle || inTouchpadGesture

        if (isTouchpad) {
            root._lastTouchpadTime = now
            root._handleTouchpad(event)
        } else {
            root._handleMouseWheel(event)
        }
        event.accepted = true
    }

    function _handleTouchpad(event) {
        var dy = event.angleDelta ? event.angleDelta.y : 0
        var px = (event.pixelDelta && event.pixelDelta.y !== undefined) ? event.pixelDelta.y : 0
        if (dy === 0 && px === 0) return

        if (wheelAnim.running) {
            wheelAnim.stop()
            root._wheelTargetY = root.flickable.contentY
        }
        physicsLoop.running = false

        // Phase handling
        if (event.phase === Qt.ScrollBegin) {
            root._velocitySamples = []
            liftTimer.stop()
            return
        } else if (event.phase === Qt.ScrollEnd) {
            liftTimer.stop()
            root._computeAndStartFling()
            return
        }

        // Calculate delta: prefer pixelDelta from compositor, fallback to angleDelta * 0.2
        var rawDelta = (px !== 0) ? px : (dy * 0.2)
        var deltaPx = -rawDelta * root.touchpadSensitivity

        var maxY = Math.max(0, root.flickable.contentHeight - root.flickable.height)

        // Overscroll resistance when dragging beyond bounds
        if (root.flickable.contentY < 0 && deltaPx < 0) deltaPx *= 0.35
        if (root.flickable.contentY > maxY && deltaPx > 0) deltaPx *= 0.35

        var now = Date.now()
        var dt = now - root._lastEventTime
        if (dt > 0 && dt < 150) {
            root._velocitySamples.push(deltaPx / dt)
            if (root._velocitySamples.length > 5) root._velocitySamples.shift()
        } else if (dt >= 150) {
            root._velocitySamples = []
        }
        root._lastEventTime = now

        // Clamp extreme overscroll while swiping
        var newY = root.flickable.contentY + deltaPx
        if (newY < -80) newY = -80
        else if (newY > maxY + 80) newY = maxY + 80

        root.flickable.contentY = newY
        liftTimer.restart()
    }

    function _computeAndStartFling() {
        var maxY = Math.max(0, root.flickable.contentHeight - root.flickable.height)
        var outOfBounds = (root.flickable.contentY < 0 || root.flickable.contentY > maxY)

        if (root._velocitySamples.length === 0) {
            root._velocity = 0
            if (outOfBounds) physicsLoop.running = true
            return
        }

        var total = 0, weightSum = 0
        for (var i = 0; i < root._velocitySamples.length; i++) {
            var w = i + 1
            total += root._velocitySamples[i] * w
            weightSum += w
        }
        root._velocity = total / weightSum
        root._velocitySamples = []

        if (Math.abs(root._velocity) >= root.flingMinVelocity || outOfBounds) {
            physicsLoop.running = true
        } else {
            root._velocity = 0
        }
    }

    function _handleMouseWheel(event) {
        physicsLoop.running = false
        liftTimer.stop()
        root._velocity = 0
        root._velocitySamples = []

        var dy = event.angleDelta ? event.angleDelta.y : 0
        var direction = dy > 0 ? -1 : 1
        var maxY = Math.max(0, root.flickable.contentHeight - root.flickable.height)
        var base = wheelAnim.running ? root._wheelTargetY : root.flickable.contentY
        root._wheelTargetY = Math.max(0, Math.min(base + direction * root.wheelScrollAmount, maxY))
        var distance = Math.abs(root._wheelTargetY - root.flickable.contentY)
        var duration = Math.max(root.wheelDurationMin, Math.min(root.wheelDurationMax, distance * 1.5))

        wheelAnim.stop()
        wheelAnim.from = root.flickable.contentY
        wheelAnim.to = root._wheelTargetY
        wheelAnim.duration = duration
        wheelAnim.start()
    }
}
