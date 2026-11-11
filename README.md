# Nukad Kart — customer app (demo build)

**Apne Nukkad Ki Har Dukaan!** Flutter customer app for Nukad Kart, a hyperlocal marketplace for kirana shops and moving sabzi/phal thelas within 500 m.

This first build runs on **demo data**: sign-in, store replies and order status are simulated. No real payments, orders or accounts.

## Download the APK

Latest build: **Releases → NukadKart.apk**
`https://github.com/aggarwal97kajal-lab/nukad-kart/releases/latest/download/NukadKart.apk`

On Android: open the link, download, and allow "Install unknown apps" for your browser.

## What is inside

- 2.5 s animated splash (cart slides in, groceries drop, sparrow lands, 500 m ripple, logo reveal)
- Google sign-in screen (simulated) + required phone number
- Home: shops within 500 m / moving sellers
- 4 categories, 25 subcategories (Household Essentials now includes **Home & Pooja**)
- Same product at nearby stores with each store's price
- One store per cart, with the "start new cart?" warning
- Pay at delivery; store accepts within 5 minutes; live status: accepted → packed → out for delivery → delivered
- Rating asked once per store or thela, editable from the store page
- Thelas: Call / WhatsApp, today's prices, request for tomorrow
- Report a problem (Nukad Kart records it and passes it to the store; no refunds by Nukad Kart)

## Build

Every push to `main` builds the APK with GitHub Actions (`.github/workflows/build-apk.yml`) and publishes it as a release. The Android folder is generated in CI with `flutter create`.

Local: `flutter create --platforms=android --project-name nukad_kart . && flutter run`

Fonts: Poppins and Inter (SIL Open Font License).
