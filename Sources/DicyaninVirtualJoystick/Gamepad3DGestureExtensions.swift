//
//  Gamepad3DGestureExtensions.swift
//  HelicopterGame
//
//  Drag gesture for the 3D gamepad joystick heads. Unlike the generic
//  GestureComponent (which moves an entity freely), this gesture only records
//  WHERE the hand is — the spring-joint physics in Gamepad3DSystem resolves that
//  into a constrained tilt about the base. That keeps the stick anchored at its
//  joint while still feeling like you're physically pushing the head.
//

import SwiftUI
import RealityKit
import simd

public extension View {
    /// Attach to the immersive RealityView so the joystick heads can be grabbed.
    /// The spatial drag fallback only exists on visionOS (where the head's 3D
    /// position can be read); on other platforms this is a no-op.
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
    /// The SwiftUI pinch-drag gesture drives the joystick heads on BOTH the
    /// Simulator and a real device. A plain `DragGesture().targetedToEntity` is
    /// resolved on device by a pinch-and-drag on the head (the same path that
    /// drives the working crane-cab levers), so the rig is grabbable even when
    /// the host never wires `VirtualJoystickBridge.handPinchProvider`. When that
    /// provider IS wired, `Gamepad3DSystem` adds two-handed hand-tracking grabs
    /// on top; the two paths coexist (one writes the grab state, the other reads
    /// it) without fighting, since hand tracking only claims a stick while a hand
    /// is actually pinching near it.
    private static var gamepad3DDragGesture: some Gesture {
        DragGesture()
            .targetedToEntity(where: .has(Gamepad3DHeadComponent.self))
            .onChanged { value in
                guard let pivot = value.entity.components[Gamepad3DHeadComponent.self]?.pivot,
                      var comp = pivot.components[Gamepad3DJoystickComponent.self] else { return }

                // Hand position in scene space.
                let worldPos = value.convert(value.location3D, from: .local, to: .scene)

                // Express it as a vector from the joint base in the gamepad BODY frame
                // (the pivot's parent, which is unrotated). Using the body frame instead
                // of the rotating pivot frame avoids tilt feedback while dragging.
                let bodyPos = (pivot.parent ?? pivot).convert(position: worldPos, from: nil)
                let vecFromBase = bodyPos - pivot.position

                comp.isGrabbed = true
                comp.grabTargetLocal = vecFromBase
                pivot.components.set(comp)
            }
            .onEnded { value in
                guard let pivot = value.entity.components[Gamepad3DHeadComponent.self]?.pivot,
                      var comp = pivot.components[Gamepad3DJoystickComponent.self] else { return }

                // Release: let the spring snap it back to center.
                comp.isGrabbed = false
                comp.grabTargetLocal = nil
                pivot.components.set(comp)
            }
    }
}
#endif
