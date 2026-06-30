//
//  Gamepad3DGestureExtensions.swift
//  DicyaninVirtualJoystick
//
//  Drag gesture for the 3D gamepad joystick heads, ported verbatim from the
//  crane-cab levers (CraneOperatorCabBuilder.applyDrag) that are confirmed
//  working on both the visionOS Simulator and a real device.
//
//  The gesture maps its 3D translation straight into a normalized stick axis
//  with a sensitivity constant and a cubic expo curve. No world-position math,
//  no spring-joint physics, no hand-tracking dependency: a plain
//  `targetedToAnyEntity` pinch-drag drives the stick everywhere.
//

import SwiftUI
import RealityKit
import simd

public extension View {
    /// Attach to the immersive RealityView so the joystick heads can be grabbed.
    @ViewBuilder
    func installGamepad3DGesture() -> some View {
        #if os(visionOS)
        simultaneousGesture(Self.gamepad3DDragGesture)
        #else
        self
        #endif
    }
}

#if os(visionOS)
public extension View {

    /// Drag sensitivity in points: the translation magnitude that maps to full
    /// deflection (matches the crane levers' `sensitivity = 220`).
    private static var gamepad3DSensitivity: Float { 220 }

    /// Expo response: small movements stay gentle, full deflection still hits 1.
    /// axis = sign(n) * |n|^3 where n is the clamped, normalized translation.
    /// Identical to `CraneOperatorCabBuilder.applyDrag`'s `curve`.
    private static func gamepad3DCurve(_ raw: Float) -> Float {
        let n = max(-1, min(1, raw / gamepad3DSensitivity))
        return (n < 0 ? -1 : 1) * powf(abs(n), 3)
    }

    private static var gamepad3DDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .targetedToEntity(where: .has(Gamepad3DHeadComponent.self))
            .onChanged { value in
                guard let pivot = value.entity.components[Gamepad3DHeadComponent.self]?.pivot,
                      var comp = pivot.components[Gamepad3DJoystickComponent.self] else { return }

                let t = value.translation3D
                // x drag -> lateral axis; up drag (negative y) -> forward (+).
                let lateral = gamepad3DCurve(Float(t.x))
                let forward = gamepad3DCurve(Float(-t.y))

                comp.isGrabbed = true
                comp.axis = SIMD2<Float>(lateral, forward)
                pivot.components.set(comp)
            }
            .onEnded { value in
                guard let pivot = value.entity.components[Gamepad3DHeadComponent.self]?.pivot,
                      var comp = pivot.components[Gamepad3DJoystickComponent.self] else { return }

                // Release: snap back to center (the crane zeroes its axes on end).
                comp.isGrabbed = false
                comp.axis = .zero
                pivot.components.set(comp)
            }
    }
}
#endif
