// Asking for a rating, at a moment that isn't rude.
//
// The numbers that motivated this: 445 installs, 5 ratings, 5.00 average.
// A perfect average nobody can see does nothing for the store page, and
// rating count drives both ranking and install conversion.
//
// Apple hard-limits this to three prompts per user per year and silently
// swallows the rest, so a prompt spent badly is genuinely gone. The rules
// here are therefore deliberately conservative:
//
//   • never on the first two boots — a stranger has nothing to rate yet
//   • never in the first minutes of a session — wait until the machine has
//     been used, not merely opened
//   • at most once per app version
//   • only when nothing is in the way: no menu open, no first-run hint,
//     no recovery notice, app actually in the foreground
//
// Uses AppStore.requestReview(in:) rather than the deprecated
// SKStoreReviewController; iOS 16+, and we target 17.

import StoreKit
import UIKit

enum RatingPrompt {
    private static let bootsKey = "ratingStableBoots"
    private static let promptedVersionKey = "ratingPromptedVersion"

    /// Boots that stayed up long enough to count as real use. Called from
    /// the same 30s stability point the config recovery uses.
    private static var stableBoots: Int {
        get { UserDefaults.standard.integer(forKey: bootsKey) }
        set { UserDefaults.standard.set(newValue, forKey: bootsKey) }
    }

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    /// Record a boot that reached stability, then arm the prompt if this
    /// session qualifies. Safe to call more than once per launch.
    static func noteStableBoot() {
        guard !armed else { return }
        armed = true
        stableBoots += 1

        // Two boots of grace before ever asking.
        guard stableBoots >= 3 else { return }
        // Once per version, however long they keep using it.
        guard UserDefaults.standard.string(forKey: promptedVersionKey) != appVersion else { return }

        // Ten minutes in. Someone still here has actually used the thing,
        // which is the only honest moment to ask.
        DispatchQueue.main.asyncAfter(deadline: .now() + 600) {
            MainActor.assumeIsolated { request() }
        }
    }

    private static var armed = false

    @MainActor
    private static func request() {
        // Don't interrupt: no panel open, no notice pending, and the app
        // must be frontmost or the prompt is wasted on a background scene.
        let state = OverlayState.shared
        guard !state.expanded, !state.showFirstRunHint, !state.showRecoveryNotice,
              UIApplication.shared.applicationState == .active,
              let scene = UIApplication.shared.connectedScenes
                  .compactMap({ $0 as? UIWindowScene })
                  .first(where: { $0.activationState == .foregroundActive })
        else {
            // Try again later in the same session rather than burning the
            // opportunity; the version guard still caps it at one prompt.
            DispatchQueue.main.asyncAfter(deadline: .now() + 300) {
                MainActor.assumeIsolated { request() }
            }
            return
        }
        UserDefaults.standard.set(appVersion, forKey: promptedVersionKey)
        NSLog("iPadUAE: requesting App Store review (boot %ld, version %@)",
              stableBoots, appVersion)
        AppStore.requestReview(in: scene)
    }
}
