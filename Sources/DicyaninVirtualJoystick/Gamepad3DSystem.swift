//
//  Gamepad3DSystem.swift
//  DicyaninVirtualJoystick
//
//  Drives the 3D gamepad joysticks from the normalized axis the drag gesture
//  writes onto each pivot (Gamepad3DJoystickComponent.axis). Each frame it:
//   1. Tilts the pivot visually so the stick leans the way it is pushed,
//      directly from the axis (no spring physics) - the same direct mapping the
//      crane-cab levers use in CraneOperatorCabBuilder.update.
//   2. Reads the axis out as a normalized stick direction + magnitude and hands
//      it to the host via VirtualJoystickBridge.output.
//
//  Only active when VirtualJoystickBridge.isEnabled() is true.
//

import RealityKit
import simd
import Foundation

public final class Gamepad3DSystem: System {

    private static let query = EntityQuery(where: .has(Gamepad3DJoystickComponent.self))

    public required init(scene: Scene) {}

    public func update(context: SceneUpdateContext) {
        guard VirtualJoystickBridge.isEnabled() else { return }

        var leftDir = SIMD3<Float>.zero,  leftMag: Float = 0,  leftActive = false
        var rightDir = SIMD3<Float>.zero, rightMag: Float = 0, rightActive = false

        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard let comp = entity.components[Gamepad3DJoystickComponent.self] else { continue }

            let lateral = clampUnit(comp.axis.x) // right +
            let forward = clampUnit(comp.axis.y) // push away +

            // --- Visual tilt straight from the axis (no spring) ---
            // Push forward (+y) tips the head away (pitch about X); push right
            // (+x) tips it right (roll about Z).
            let pitchQ = simd_quatf(angle: -forward * comp.maxTilt, axis: SIMD3<Float>(1, 0, 0))
            let rollQ  = simd_quatf(angle: -lateral * comp.maxTilt, axis: SIMD3<Float>(0, 0, 1))
            entity.orientation = pitchQ * rollQ

            // --- Normalized read-out ---
            var magnitude = sqrt(lateral * lateral + forward * forward)
            magnitude = min(magnitude, 1.0)
            let active = magnitude > comp.deadzone

            // Channel + sign convention preserved from the original system:
            //   left stick  -> leftDirection channel, y negated
            //   right stick -> rightDirection channel, y as-is
            let drivesPosition = comp.side == .right
            let y = drivesPosition ? forward : -forward
            let direction = active ? SIMD3<Float>(lateral, y, 0) : .zero
            let reportedMag = active ? magnitude : 0

            if drivesPosition {
                rightDir = direction; rightMag = reportedMag; rightActive = active
            } else {
                leftDir = direction; leftMag = reportedMag; leftActive = active
            }
        }

        VirtualJoystickBridge.output(
            VirtualJoystickInput(
                leftDirection: leftDir,
                leftMagnitude: leftMag,
                leftActive: leftActive,
                rightDirection: rightDir,
                rightMagnitude: rightMag,
                rightActive: rightActive
            )
        )
    }
}

private func clampUnit(_ v: Float) -> Float { max(-1.0, min(1.0, v)) }
