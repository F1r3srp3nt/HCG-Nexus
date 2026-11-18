# Branding assets (bundled, work offline)

| File | Use | Source and provenance |
|---|---|---|
| `hcg-logo.png` (480×221, RGBA) | HCG logo in the panel header and Overview | Official futuristic HCG logo (chrome "HCG" lettering, electric-blue edges), supplied by the founder. Master: HCG-Mail `Windows-executable-Application/assets/branding/hcg-logo-transparent.png` @ `13d93a8` (1520×700, SHA-256 `7a8723c9d73843099604846252c5141595dbf9d04cb98f0f4897565e82cd694d`), itself the lettering cropped from the founder's original (HCG-Executable-Maker `branding/hcg-logo-temporary-original.png`, SHA-256 `4f8e3c93…c78a0`, which that repo labels "Temporary official HCG logo"). Here it is only resized (Lanczos, 480 px wide). SHA-256 `424dbe643508f40c5ec88951a6f26bee831e068c9b57d7ac040a17d186403a07` |
| `nexus-emblem.png` (180×180) | Nexus emblem in the Overview hero | HCG Nexus app icon from the supplied icon pack (`App/Assets.xcassets/AppIcon.appiconset/Icon-1024.png`, SHA-256 `3975c939593794d3f9513f4b5250835fec6d65841bcbf1a4e0d69de26afc0cf7`), resized. SHA-256 `8e8582bebdeea900614b6385f55e005bef6aaa6570f91ad863be13685efa86af` |
| `hcg-nexus-banner.png` | **Missing — slot only** | No official HCG Nexus banner exists in any accessible HCG repository or branch (checked 18 Nov 2026). Until one is supplied, the Overview shows a typographic header (logo + emblem + "NEXUS"), which is a layout, not a banner. |

## The banner that is needed

Supply **one file**, `hcg-nexus-banner.png` (or `.jpg`), in the HCG house style used by the HCG Repo,
HCG Terminal and HCG Server banners:

- 3:1 aspect ratio, **2000×667 px** (minimum 1200×400), sRGB, no transparency required;
- dark obsidian background, chrome "HCG NEXUS" lettering with cyan edge light, optional restrained violet;
- keep text and emblem inside the central 70 % width: the Overview crops the sides on narrow panels
  (aspect fill, centred) and shows it at about 300×100 pt.

Drop it into this folder and rebuild. It is picked up by the tweak (installed to
`<prefix>/Library/Application Support/HCGNexus/`), the standalone app (asset catalog `HCGNexusBanner`)
and the preview harness. Do not substitute generated or third-party artwork.
