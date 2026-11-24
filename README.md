# CRAFTCEBU

A multi-vendor marketplace for Cebu's local craftmakers and artisans.
Vue 3 + Vite + Tailwind CSS + shadcn-vue on Supabase (Auth, Postgres + RLS, Storage, Edge Functions).

## Status

All seven milestones from the design doc are built.

**Milestone 7 (polish):** Shop by Origin map (Leaflet + OpenStreetMap) with makers and pieces per town; buyer reviews on delivered items, with star ratings on product cards; wishlist (heart on cards and product pages, Saved pieces page); mobile menu with search and account links.

**Milestone 6 (owner Admin Centre):** All Artisans (suspend/reactivate), All Orders (filters, details, owner can move parcels), All Products (hide, feature), Users (ban/unban, with emails), Reviews (hide), Payouts (net per shop after commission, COD commission owed, settle and history), Catalog Setup (crafts and towns), Homepage (artisan of the week, banners), Settings (commission, shipping fee, store info), Activity Log (owner actions logged by database triggers); dashboard Top shops and Sales by town; Seller Centre My Income.

**Milestone 5 (Maya sandbox):** pay with Maya at checkout. Three Edge Functions: `create-maya-checkout` opens Maya's payment page, `verify-maya-payment` confirms the result when the buyer returns, and `maya-webhook` handles Maya's notifications. Payments are always re-checked with Maya using the secret key before an order is marked paid; failed or expired payments cancel the order and return the stock.

**Milestone 4 (cart and checkout):** cart grouped by shop (saved in the browser); checkout with saved delivery addresses; cash on delivery and a demo online payment; one order split per shop by the `place_order` database function, which re-checks stock and computes totals, shipping and commission; My Purchases with Shopee-style tabs and order details with a delivery timeline; buyer cancellation; Seller Centre orders (ship, deliver, cancel), with stock returned on cancellation.

**Milestone 3 (artisan onboarding):** "Sell on CraftCebu" application with story, town and photo uploads; owner approval queue in the Admin Centre (approve, or send back with a reason the applicant sees and can fix); Seller Centre with a dashboard, product list (search, tabs, live switch, delete), product form with up to 6 photos, and shop profile editing.

**Milestone 2 (catalog):** shop page with search, craft/town/price filters and sorting; product pages with gallery, maker card, reviews and more from the shop; artisan shop pages; a makers directory; new arrivals on the home page.

### Milestone 1

- Vue 3 + TypeScript scaffold with Tailwind v4, shadcn-vue, Pinia and Vue Router
- Database schema for all 17 tables, with Row Level Security and storage buckets
- Starter data: Cebu towns, craft categories, commission and shipping settings
- Auth: sign up, log in, forgot and reset password, account page
- Role-guarded routes: `/admin` (owner only), `/seller` (artisans only)
- Owner setup script and an admin overview page with live counts

## Setup

### 1. Create a Supabase project

At [supabase.com](https://supabase.com), create a project. Copy its URL, anon key and service-role key from **Project Settings → API**.

### 2. Configure environment

```bash
cp .env.example .env.local
```

Fill in `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`.
Never give the service-role key or the Maya keys a `VITE_` prefix: anything with that prefix ships to the browser.

### 3. Create the database

In the Supabase dashboard, open **SQL Editor** and run these files in order:

1. `supabase/migrations/20261124000001_schema.sql`
2. `supabase/migrations/20261124000002_rls.sql`
3. `supabase/migrations/20261124000003_storage.sql`
4. `supabase/migrations/20261124000004_api_grants.sql`
5. `supabase/migrations/20261125000001_artisan_onboarding.sql`
6. `supabase/migrations/20261126000001_checkout.sql`
7. `supabase/migrations/20261127000001_maya.sql`
8. `supabase/migrations/20261128000001_admin.sql`
9. `supabase/seed.sql`

(If you use the Supabase CLI: `npx supabase link`, then `npx supabase db push --remote --include-seed`.)

For quick testing, you can turn off **Authentication → Sign In / Providers → Email → Confirm email**, so new accounts can log in right away.

### 4. Run the app

```bash
npm install
npm run dev
```

### 5. Create the owner account

1. Sign up in the app with the owner's email.
2. Promote that account:

```bash
npm run promote-owner -- owner@example.com
```

3. Log out and back in. You land on `/admin`.

CRAFTCEBU allows exactly one owner, and the database rejects a second one.
Users can't change their own role; only the owner (or the database) can.

### 6. (Optional) Load the demo catalog

For presentations, add four verified demo shops with 14 products:

```bash
npm run seed:demo
```

Remove them again with `npm run seed:demo -- --remove`. Demo accounts use `@craftcebu.test` emails and random passwords.

### 7. Maya sandbox payments

1. Get sandbox keys from Maya Business Manager (or the shared sandbox keys on developers.maya.ph). Add them to `.env.local` as `MAYA_PUBLIC_KEY` and, if you have one, `MAYA_SECRET_KEY`. Each can be the raw key (`pk-...`), its Base64 form, or the full Basic auth value (`Basic cGst...`).
   - With only the public key, checkouts work and results are read from Maya's payment-status endpoint. The secret key adds full payment lookups and lets `npm run maya:webhooks` register webhooks.
2. Give the Edge Functions the same keys, plus the site's address for Maya's return links:

```bash
npx supabase secrets set MAYA_PUBLIC_KEY="Basic cGst..." SITE_URL=http://localhost:5173
```

3. Deploy the functions (the webhook takes calls from Maya, so it skips the Supabase login check):

```bash
npx supabase functions deploy create-maya-checkout verify-maya-payment
npx supabase functions deploy maya-webhook --no-verify-jwt
```

4. Optional: `npm run maya:webhooks` registers the webhook with Maya's sandbox.

Sandbox test card: 5123456789012346, any name, expiry 12/2030, CVV 111. Maya wallet test login: +639900100900, password `Password@1`, OTP `123456`.

## Packaging as a WebView app

The web app is built mobile-first for a WebView shell (every page checked at 360px wide):

- `viewport-fit=cover` plus safe-area padding (`pt-safe`, `pb-safe`, `pb-safe-4`) keep the header, menus, bottom bars and toasts clear of notches and home indicators.
- Form fields are at least 16px on phones, so iOS never zooms in on focus; taps have no delay or grey flash.
- Confirmations use an in-app dialog (`confirmAction` in `src/lib/confirm.ts`), never `window.confirm`, and nothing opens a new tab.
- Hover-only controls are always visible on touch screens.

What the native shell must provide:

| | Android (WebView) | iOS (WKWebView) |
|---|---|---|
| JavaScript and DOM storage | `javaScriptEnabled`, `domStorageEnabled` (login and cart live in localStorage) | on by default |
| Photo uploads | implement `WebChromeClient.onShowFileChooser`, or the "Add photo" buttons do nothing | works; add `NSPhotoLibraryUsageDescription` / `NSCameraUsageDescription` |
| Edge to edge | enable edge-to-edge so `env(safe-area-inset-*)` has values | set the web view to extend under the safe area |
| Back button | map the hardware back button to `webView.goBack()` | enable swipe-back (`allowsBackForwardNavigationGestures`) |
| Maya payments | keep Maya's page inside the WebView so it can redirect back to `SITE_URL/pay/maya/return` | same |

Set `SITE_URL` (Supabase secret) to the deployed HTTPS address the app loads, so Maya returns buyers to it.

## Project layout

```
src/
  components/      shared components; ui/ holds the shadcn-vue components
  layouts/         AppLayout (store) and AdminLayout (owner dashboard)
  lib/supabase.ts  Supabase client
  router/          routes and role guards
  stores/auth.ts   session, profile and role
  views/           pages (auth/, admin/, seller/)
supabase/
  migrations/      schema, RLS, storage
  seed.sql         towns, categories, settings
scripts/
  promote-owner.mjs
```
