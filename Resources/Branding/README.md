# Branding assets (bundled, work offline)

| File | Use | Source and provenance |
|---|---|---|
| `hcg-logo.png` (480×221, RGBA) | HCG logo in the panel header and Overview | Official futuristic HCG logo (chrome "HCG" lettering, electric-blue edges), supplied by the founder. Master: HCG-Mail `Windows-executable-Application/assets/branding/hcg-logo-transparent.png` @ `13d93a8` (1520×700, SHA-256 `7a8723c9d73843099604846252c5141595dbf9d04cb98f0f4897565e82cd694d`), itself the lettering cropped from the founder's original (HCG-Executable-Maker `branding/hcg-logo-temporary-original.png`, SHA-256 `4f8e3c93…c78a0`, which that repo labels "Temporary official HCG logo"). Here it is only resized (Lanczos, 480 px wide). SHA-256 `424dbe643508f40c5ec88951a6f26bee831e068c9b57d7ac040a17d186403a07` |
| `nexus-emblem.png` (180×180) | Nexus emblem in the Overview hero | HCG Nexus app icon from the supplied icon pack (`App/Assets.xcassets/AppIcon.appiconset/Icon-1024.png`, SHA-256 `3975c939593794d3f9513f4b5250835fec6d65841bcbf1a4e0d69de26afc0cf7`), resized. SHA-256 `8e8582bebdeea900614b6385f55e005bef6aaa6570f91ad863be13685efa86af` |
| `hcg-nexus-banner.jpg` (1500×500, JPEG q90) | Banner in the Overview hero (shown whole, aspect fit) | **Official HCG Nexus banner, founder-supplied and approved for the HCG Store on 15 Nov 2026** (chrome four-pointed star and "HCG Nexus" lettering). Master: HCG Store (`F1r3srp3nt/store`) `assets/products/hcg-nexus/banner.webp` @ `991044a` (2172×724, lossless original, SHA-256 `cd4ff09a09b84cab8bd395a4a8a5865a825f8325aca5b1e40b1275a766e9acfe`); provenance in that repo's `web-hcg-store/docs/ASSETS.md` ("Founder-approved product banners and icons"). Here it is only resized (Lanczos) and saved as JPEG; no crop or edit. SHA-256 `1cb7c600a9c78adcbf58603906e40068abb9f8ce4f26850a71f57233b1295a3b`. Same file in `App/Assets.xcassets/HCGNexusBanner.imageset` and `PreviewHarness/Resources` |

## Still open

- **Final HCG logo files.** `hcg-logo.png` is the mark the founder supplied as the *temporary official* HCG logo;
  the HCG Store lists "final official HCG logo files (SVG preferred)" as still to come. When they arrive, replace
  `hcg-logo.png` (and `App/Assets.xcassets/HCGLogo.imageset`, `PreviewHarness/Resources/hcg-logo.png`).
- The banner was located on 18 Nov 2026 in the HCG Store repository. The earlier note here ("no official banner
  exists") only covered repositories attached to that session.
