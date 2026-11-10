# Publishing Kibble to CurseForge and Wago

Everything here is **prepared, not done**: nothing has been uploaded, and no workflow publishes to the
stores by itself. GitHub releases are already automatic (see "Releasing" below).

## What is in this folder

- `description.md` - the project description, ready to paste into both sites (Markdown).
- Summary line (CurseForge asks for a short one):
  *One button to feed, revive and call your hunter pet, with low-food warnings, vendor restock and a
  right-click settings menu. For WoW Forever.*
- `../art/logo-512.png` - project logo/avatar (512x512, from `art/icon.svg`).
- `../art/social-preview.png` - 1280x640 banner (also the GitHub social preview).
- `../.pkgmeta` and `../.github/workflows/publish-stores.yml` - the optional automatic upload (see below).

## Screenshots to take (they are yours to take, I can't capture the game)

Mind that character and NPC names show up in screenshots; crop them if you'd rather not publish them.

1. The button on screen, ideally with the mood ring visible.
2. The right-click menu open (for example Food > Vendor restock).
3. The vendor window with the *Buy N pet food* tab, in your usual UI.
4. Optional: the same window in the stock UI, the Call Pet look when the pet is away, the options panel.

## CurseForge

1. Create the project at <https://www.curseforge.com/> (Author Portal > Create project > World of Warcraft >
   Addons). Name **Kibble**, the summary above, the description from `description.md`, license MIT.
2. Pick the matching categories (Hunter / class-specific, plus a general utility or combat category).
3. **Game version: choose the WoW Forever entry if the site lists one.** I could not find documentation
   confirming how CurseForge tags Forever uploads, so check the dropdown yourself on the first upload.
4. Upload the logo and screenshots, then upload the file `Kibble-vX.Y.Z.zip` from the GitHub release.
5. For automation later: note the **project ID** (shown on the project page), and create an API token
   at <https://authors.curseforge.com/account/api-tokens>.

## Wago

1. Create the addon at <https://addons.wago.io/> (developer dashboard). Same name, summary, description,
   logo and screenshots as above.
2. Upload the release zip the first time by hand, and check which game version it is filed under.
3. The **project ID** is printed under the addon's name on the dashboard. Create an API key on the
   developer portal (<https://docs.wago.io/> has the details).

## Turning on the automatic upload (optional, later)

Only after the manual first uploads worked:

1. Add the IDs to `Kibble.toc` (they are not there yet, so the packager can't upload by accident):
   ```
   ## X-Curse-Project-ID: <number>
   ## X-Wago-ID: <id>
   ```
2. Add repository secrets (GitHub > Settings > Secrets and variables > Actions): `CF_API_KEY`,
   `WAGO_API_TOKEN`.
3. Run **Actions > Publish to CurseForge / Wago (manual)** on a release tag with *Dry run* ticked, and read
   the log: it must pick the Forever game version for interface 16001. The BigWigs packager documents no
   Forever flavour, so if it picks the wrong one, keep uploading by hand (or tell me and I'll look at it).
4. Run it again with *Dry run* unticked.

## Releasing (GitHub, already automatic)

1. Bump `## Version:` in `Kibble.toc` and add a `## x.y.z - date` section to `CHANGELOG.md`.
2. Commit and push to `main`; CI runs the tests.
3. `git tag vx.y.z && git push origin vx.y.z`. The Release workflow tests, builds `Kibble-vx.y.z.zip`
   (it refuses if the tag and the TOC version differ) and publishes the release with the CHANGELOG
   section as its notes.
