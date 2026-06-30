//
//  Gamepad3DComponents.swift
//  DicyaninVirtualJoystick
//
//  Components for the world-anchored 3D gamepad with two grabbable joysticks.
//
//  Hierarchy per joystick:
//
//      socket (fixed visual ring on the gamepad body)
//      pivot  <-- Gamepad3DJoystickComponent  (rotates about its local origin = the joint base)
//        +- shaft  (visual stick)
//             +- head  <-- Gamepad3DHeadComponent + InputTargetComponent + CollisionComponent
//
//  Input model (ported verbatim from the crane-cab levers that are confirmed
//  working on Simulator AND device): the SwiftUI drag gesture maps its
//  translation straight into a normalized axis with a sensitivity constant and a
//  cubic expo curve. There is NO spring-joint physics and NO hand-tracking
//  dependency. The pivot is tilted each frame directly from the axis, and the
//  axis is read out as the stick's normalized output.
//

import RealityKit
import simd

// MARK: - Joystick (pivot) component

public struct Gamepad3DJoystickComponent: Component {

    public enum Side: String, Sendable {
        case left
        case right
    }

    /// Which physical stick this is. Drives which output channel it feeds
    /// (left = leftDirection, right = rightDirection).
    public var side: Side

    /// Length of the visible shaft, in meters. Kept for the rig geometry.
    public var stickLength: Float

    /// Maximum visual tilt away from vertical, in radians, at full deflection.
    public var maxTilt: Float

    /// Normalized deadzone (0...1) below which the stick reports no input.
    public var deadzone: Float

    /// Current normalized axis, each component in -1...1.
    /// x = lateral (right +), y = forward/back (push away +). Written by the
    /// drag gesture, read by `Gamepad3DSystem` for both tilt and output.
    public var axis: SIMD2<Float> = .zero

    /// True while a finger/hand is dragging the head.
    public var isGrabbed: Bool = false

    public init(side: Side,
                stickLength: Float = 0.05,
                maxTilt: Float = .pi / 5.0, // 36 degrees
                deadzone: Float = 0.06) {
        self.side = side
        self.stickLength = stickLength
        self.maxTilt = maxTilt
        self.deadzone = deadzone
    }
}

// MARK: - Head (grab target) component

/// Lightweight tag placed on the grabbable head sphere so the drag gesture can
/// target it. Holds a reference back to its pivot so the gesture can write the
/// axis onto the `Gamepad3DJoystickComponent`.
public struct Gamepad3DHeadComponent: Component {
    public weak var pivot: Entity?
    public init(pivot: Entity? = nil) {
        self.pivot = pivot
    }
}

// MARK: - Button component

/// Tag placed on a pressable button (e.g. the pillar stand's missile trigger).
public struct Gamepad3DButtonComponent: Component {

    public enum Action: String, Sendable {
        case fireMissile
        case toggleHologram
    }

    public var action: Action
    public var slot: Int
    public var restY: Float
    public var pressDepth: Float

    public init(action: Action = .fireMissile, slot: Int = 1, restY: Float = 0, pressDepth: Float = 0.006) {
        self.action = action
        self.slot = slot
        self.restY = restY
        self.pressDepth = pressDepth
    }
}

// MARK: - Pillar base (drag handle) component

/// Tag placed on the pillar stand's floor foot so a drag gesture can pick it up
/// and reposition the WHOLE stand.
public struct GamepadPillarBaseComponent: Component {
    public weak var root: Entity?
    public init(root: Entity? = nil) {
        self.root = root
    }
}
