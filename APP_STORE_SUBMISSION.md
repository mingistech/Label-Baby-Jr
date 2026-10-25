# Mac App Store submission checklist

This branch builds the Mac App Store edition of Label Baby Jr. It is macOS-only, sandboxed, and does not include the GitHub update checker.

## Prepared in the project

- [x] Explicit bundle identifier: `com.mingistech.LabelBabyJr`
- [x] App Sandbox enabled
- [x] User-selected file read/write access enabled
- [x] App-scoped security bookmarks enabled for recent documents
- [x] Printing entitlement enabled
- [x] GitHub update checks excluded from the App Store binary
- [x] Productivity app category configured
- [x] Export-compliance key set for no non-exempt encryption
- [x] Privacy manifest declares no tracking or collected data
- [x] Privacy Policy and Support commands available from the Help menu
- [x] Universal signed archive succeeds for Apple silicon and Intel Macs
- [x] `AppStoreExportOptions.plist` records the automatic App Store Connect export settings
- [x] App Store Connect package export succeeds with cloud-managed distribution signing

## Apple account and App Store Connect

- [x] Register `com.mingistech.LabelBabyJr` as an explicit macOS App ID for team `A8BNP8EEKC`
- [x] Create the cloud-managed Apple Distribution identity and Mac App Store provisioning profile
- [ ] Create the App Store Connect record
- [ ] Confirm all current Apple agreements are accepted
- [ ] Choose availability and price
- [ ] Complete the age-rating questionnaire
- [ ] Declare that the app does not collect data
- [ ] Set the Privacy Policy URL to `https://github.com/mingistech/Label-Baby-Jr/blob/codex/app-store-readiness/PRIVACY.md`
- [ ] Set the Support URL to `https://github.com/mingistech/Label-Baby-Jr/blob/codex/app-store-readiness/SUPPORT.md`

Suggested record values:

- Name: `Label Baby Jr`
- Platform: `macOS`
- Primary language: `English (U.S.)`
- Bundle ID: `com.mingistech.LabelBabyJr`
- SKU: `label-baby-jr-macos`
- Primary category: `Productivity`
- Secondary category: `Utilities`

## Product page

- [ ] Prepare a plain-text description, subtitle, and keywords
- [ ] Capture at least one 16:10 Mac screenshot at an accepted size
- [ ] Add copyright information
- [ ] Explain that the app is designed specifically for 89 × 28 mm labels
- [ ] Describe it as compatible with DYMO printers without implying endorsement

## Validation and review

- [ ] Test create, open, Save, Save As, recent documents, quit-with-unsaved-changes, and reopening recent documents in a sandboxed signed build
- [ ] Test discovery and printing with a physical DYMO printer
- [ ] Record a short printer demonstration video for App Review
- [ ] Archive using the App Store signing identity
- [ ] Run Xcode's Validate App workflow
- [ ] Upload to TestFlight and test the installed build
- [ ] Submit the selected build and metadata to App Review

## Draft App Review notes

Label Baby Jr is a focused native macOS editor for 89 × 28 mm labels. A compatible DYMO printer is required only for physical printing. Reviewers can create, format, save, close, and reopen label documents without printer hardware. Printing uses the standard macOS printing system and the App Sandbox printing entitlement. The app has no account, analytics, advertising, tracking, or external update mechanism. A short physical-printer demonstration video should be linked here before submission.
