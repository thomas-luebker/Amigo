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

final class PencilHoverDriver: NSObject {
    static let shared = PencilHoverDriver()

    /// Attach the hover recognizer to SDL's content view. Safe to call
    /// once at overlay-install time; the emulator loop shares the main
    /// thread, so the callback can call into the core directly.
    func install(on scene: UIWindowScene) {
        guard let sdlView = scene.windows
            .first(where: { !($0 is PassthroughWindow) })?
            .rootViewController?.view else {
            NSLog("iPadUAE pencil: no SDL view found, hover not installed")
            return
        }
        let hover = UIHoverGestureRecognizer(target: self,
                                             action: #selector(handleHover(_:)))
        sdlView.addGestureRecognizer(hover)
    }

    @objc private func handleHover(_ gesture: UIHoverGestureRecognizer) {
        switch gesture.state {
        case .began, .changed:
            guard let view = gesture.view,
                  view.bounds.width > 0, view.bounds.height > 0 else { return }
            let p = gesture.location(in: view)
            ipaduae_pointer_hover(Float(p.x / view.bounds.width),
                                  Float(p.y / view.bounds.height))
        default:
            break
        }
    }
}
