# Recommended code snippets for presentation

Pick these spots for slides — each is a single focused concept (upload flow, authorization, display + verify). I added suggested line ranges that you can open quickly in VS Code and copy the code you want to show.

---

## Backend: HTTP route and controller for image uploads

- File: `doyourwork-api/routes/wagers.js`
- Why: Shows how the server accepts form uploads with multer and protects the route using auth middleware.
- Link: /Users/prateekp/Documents/doyourwork-ios/doyourwork-api/routes/wagers.js
- Suggest showing lines: 15–30 (multer configuration + the `router.post('/:id/proof', ...)` line)

## Backend: Upload controller — saves URL and sets wager state

- File: `doyourwork-api/controllers/wagers.js`
- Why: Demonstrates server-side validation, saving the file URL in DB, and changing the wager `status` to `verifying`.
- Link: /Users/prateekp/Documents/doyourwork-ios/doyourwork-api/controllers/wagers.js
- Suggest showing lines: 212–246 (the `uploadProof` function) — highlight the DB update and `proof_url` returned.

## Backend: Static file serving for uploaded images

- File: `doyourwork-api/server.js`
- Why: Shows how uploaded files are made accessible via `/uploads/*` — useful for verifying image links in the app.
- Link: /Users/prateekp/Documents/doyourwork-ios/doyourwork-api/server.js
- Suggest showing lines: 6–14 (app.use('/uploads', ...), and the small debug logger around requests)

---

## iOS: Network layer — multipart/form upload + token

- File: `DoYourWork/NetworkService.swift`
- Why: Clear demonstration of how the client assembles a multipart/form-data body, attaches the JWT authorization header, and posts the image.
- Link: /Users/prateekp/Documents/doyourwork-ios/DoYourWork/DoYourWork/NetworkService.swift
- Suggest showing lines: 74–120 (the `uploadProof` method) — highlight building the boundary, adding `Authorization` header, and decoding server responses.

## iOS: WagerDetailView — PhotosPicker + upload button

- File: `DoYourWork/Views/WagerDetailView.swift`
- Why: Shows the front-line UI for choosing a photo, previewing it, and issuing the upload; also shows main-thread state updates and posting notifications.
- Link: /Users/prateekp/Documents/doyourwork-ios/DoYourWork/DoYourWork/Views/WagerDetailView.swift
- Suggest showing lines: 120–190 (PhotosPicker selection, loading Data using `loadTransferable`, the `Upload Selected Photo` button action).

## iOS: Notification + auto-refresh for referee view

- File: `DoYourWork/ViewModels/ToVerifyViewModel.swift`
- Why: Lightweight, important tweak — when a pledger uploads proof, a notification triggers the referee's pending list to refresh.
- Link: /Users/prateekp/Documents/doyourwork-ios/DoYourWork/DoYourWork/ViewModels/ToVerifyViewModel.swift
- Suggest showing lines: 8–28 where the NotificationCenter observer gets added, and lines 32–52 (the refresh `fetchWagers()` method currently used).

## iOS: VerifyWagerView — verifying and capturing outcomes

- File: `DoYourWork/Views/VerifyWagerView.swift`
- Why: Shows referee actions approving or rejecting a proof and how it calls the `verify` endpoint — highlight the `verifyWager` call.
- Link: /Users/prateekp/Documents/doyourwork-ios/DoYourWork/DoYourWork/Views/VerifyWagerView.swift
- Suggest showing lines: 238–268 (the verify function and Network call), and 72–100 (where the `AsyncImage` is used to display the proof image).

---

## Model & DB

- Model: `DoYourWork/Models/Wager.swift` — shows `proof_image_url` property linked to server DB.
  - Link: /Users/prateekp/Documents/doyourwork-ios/DoYourWork/DoYourWork/Models/Wager.swift
  - Show: class definition + `proof_image_url: String?`.
- Database: `doyourwork-api/tables.sql` (or `guide.md`) — show the schema addition for `proof_image_url`.
  - Link: /Users/prateekp/Documents/doyourwork-ios/doyourwork-api/tables.sql
  - Show: `proof_image_url VARCHAR(1024) NULL`.

---

## Small supporting bits

- `DoYourWork/Utilities/Notifications.swift` — single-purpose Notification.Name extension for `wagerProofUploaded`.
  - Link: /Users/prateekp/Documents/doyourwork-ios/DoYourWork/DoYourWork/Utilities/Notifications.swift
  - Show: one-line `static let wagerProofUploaded` declaration.
- `AuthService.swift` — where the token is saved (JWT) used to authorize the multipart upload.
  - Link: /Users/prateekp/Documents/doyourwork-ios/DoYourWork/DoYourWork/AuthService.swift
  - Show: the `getToken()` method and where `UserDefaults` is used (explain potential security caveat).

---

Try it during the demo

- Start your server with `npm start` from `doyourwork-api`, then start the iOS app in the simulator.
- Log in as pledger, open wager detail, select an image, click "Upload Selected Photo" — watch the upload network call in app console and the server logs.
- Switch to the referee user; the `To Verify` list will refresh automatically. If you want to demonstrate manual re-check, show the toolbar refresh button.

If you want, I can create a small demo slide pack (e.g., a single `presentation.md` or a `README_presentation.md`) that includes these links and a short bullet list to accompany each snippet. Do you want that, or are these file links enough?
