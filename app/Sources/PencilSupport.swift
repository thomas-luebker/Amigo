// Apple Pencil hover → Workbench pointer.
//
// On hover-capable hardware (M2+ iPads with Pencil 2 / Pro / USB-C) the
// Pencil reports position while floating above the screen. In 1:1 mouse
// mode we feed that straight into the absolute-pointer path, so the Amiga
// pointer tracks the hovering Pencil and a touch clicks — Deluxe Paint
// style. On other hardware the recognizer simply never fires (trackpad
// pointers also trigger it, which is harmless: in 1:1 mode they already
// drive the same absolute position through SDL).

import UIKit

final class PencilHoverDriver: NSObject, UIPencilInteractionDelegate {
    static let shared = PencilHoverDriver()

    /// Attach the hover recognizer and Pencil interaction to SDL's content
    /// view. Safe to call once at overlay-install time; the emulator loop
    /// shares the main thread, so the callbacks call into the core directly.
    func install(on scene: UIWindowScene) {
        guard let sdlView = scene.windows
            .first(where: { !($0 is PassthroughWindow) })?
            .rootViewController?.view else {
            NSLog("iPadUAE pencil: no SDL view found, hover not installed")
            return
        }
        let hover = UIHoverGestureRecognizer(target: self,
                                             action: #selector(handleHover(_:)))
        // Pencil only: trackpad pointers also produce hover events, and the
        // palm rejection below must never engage for a parked mouse pointer.
        hover.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
        sdlView.addGestureRecognizer(hover)
        // Squeeze (Pencil Pro) = hold RMB — hover + squeeze walks Intuition
        // menus like a real second button. Double-tap (Pencil 2) = RMB click.
        // (Plain init + delegate property: the delegate: initializer is
        // iOS 17.5+, deployment target is 17.0.)
        let pencil = UIPencilInteraction()
        pencil.delegate = self
        sdlView.addInteraction(pencil)
    }

    /// Squeeze length picks the button (device-verified phase order:
    /// began → changed… → ended). Short squeeze (<0.4s) right-clicks; a
    /// long squeeze presses the LEFT button when the threshold is crossed
    /// and releases it with the squeeze — hover-click and hover-drag
    /// without touching the glass.
    private var longSqueeze: DispatchWorkItem?
    private var longSqueezeFired = false

    @available(iOS 17.5, *)
    func pencilInteraction(_ interaction: UIPencilInteraction,
                           didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
        switch squeeze.phase {
        case .began:
            // Guard against a lost .ended: never start with a stuck button.
            longSqueeze?.cancel()
            if longSqueezeFired {
                ipaduae_mouse_button(0, 0)
            }
            longSqueezeFired = false
            let work = DispatchWorkItem { [weak self] in
                self?.longSqueezeFired = true
                ipaduae_mouse_button(0, 1)      // LMB down, held while squeezing
            }
            longSqueeze = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
        case .ended, .cancelled:
            longSqueeze?.cancel()
            longSqueeze = nil
            if longSqueezeFired {
                longSqueezeFired = false
                ipaduae_mouse_button(0, 0)      // LMB up
            } else {
                // Short squeeze: RMB click, release deferred for the
                // emulated 50Hz input polling.
                ipaduae_mouse_button(1, 1)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    ipaduae_mouse_button(1, 0)
                }
            }
        default:
            break
        }
    }

    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        // Quick RMB click; release is deferred so the emulated 50Hz input
        // polling reliably observes the press.
        ipaduae_mouse_button(1, 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            ipaduae_mouse_button(1, 0)
        }
    }

    @objc private func handleHover(_ gesture: UIHoverGestureRecognizer) {
        switch gesture.state {
        case .began, .changed:
            ipaduae_set_pen_hover(1)   // palm rejection while hovering
            guard let view = gesture.view,
                  view.bounds.width > 0, view.bounds.height > 0 else { return }
            let p = gesture.location(in: view)
            ipaduae_pointer_hover(Float(p.x / view.bounds.width),
                                  Float(p.y / view.bounds.height))
        default:
            ipaduae_set_pen_hover(0)   // tip contact or Pencil out of range
        }
    }
}
