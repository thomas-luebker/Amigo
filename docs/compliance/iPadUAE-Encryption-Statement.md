# Encryption Export Compliance Statement

**Application:** iPadUAE — Amiga Emulator

**Bundle ID:** de.amiga-imager.uae

**Version:** 0.4.2 (build 20260719.1) and all prior builds

**Developer:** Thomas Lübker

**Date:** 19 July 2026

## Self-Classification

iPadUAE does **not implement, contain, or incorporate any cryptographic functionality**. Specifically:

1. The application implements **no encryption algorithms** — neither proprietary algorithms nor standard algorithms such as AES, RSA, or elliptic-curve cryptography.

2. The application **initiates no network communication of its own**. It contains no TLS/SSL client or server code, performs no HTTPS requests, and includes no analytics, telemetry, or update mechanisms.

3. The application's emulated-network feature (bsdsocket.library) forwards plain, unencrypted socket operations from emulated Amiga software to the operating system's socket API. The application neither performs nor terminates any encryption in this path.

4. The application's use of the operating system is limited to standard APIs for graphics, audio, input, and file access. It makes no calls to cryptographic APIs (CommonCrypto, CryptoKit, Security.framework encryption facilities, or equivalents).

5. Third-party components (WinUAE emulation core, SDL 3, LZMA SDK, AROS ROM image) are compiled without any cryptographic functionality.

Accordingly, the ITSAppUsesNonExemptEncryption key is set to false in the application's Info.plist, and the developer classifies the application as containing **no encryption** — it does not fall under the encryption items described in Category 5, Part 2 of the U.S. Export Administration Regulations, and no CCATS, ERN, or annual self-classification report is required.

## Declaration

I declare that the statements above are accurate for the referenced application and all builds distributed through TestFlight and the App Store.

Thomas Lübker

Developer, iPadUAE — thomas.luebker@mac.com
