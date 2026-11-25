# CraftCebu app, Phase 1: native browsing on a shared login

## Why

The CraftCebu phone app (Flutter, in `mobile/`) is currently a full-screen WebView of https://craftcebu.vercel.app. For the capstone, the parts shoppers spend the most time in should feel like a real phone app. Checkout, Maya payments and orders already work on the web and stay there. The shopper signs in once and never notices where native ends and web begins.

## Goals

- A native tab bar: **Home · Shop · Cart · Orders · Account**.
- **Native Shop**: search, craft (category) rail, town chips, price and sort sheet, product grid that loads more as you scroll, a makers rail, and quick add on every card. It mirrors the redesigned web Shop (`src/views/ShopView.vue`).
- **Native Product**: swipe gallery, name, price, maker and town, a quantity stepper, add to cart, wishlist heart, highlights and details, a review summary with the review list, and "More from this maker" and "You may also like" rails. It mirrors `src/views/ProductView.vue`.
- **Native Account**: sign in, create an account, forgot password, a profile summary, links to Wishlist, the Seller Centre (for verified artisans and the owner) and the Admin Centre (for the owner), and sign out.
- **One login**: signing in natively also signs in the web pages inside the app. Signing out does the same.
- **One cart**: the cart lives in Supabase, so native screens and web pages always show the same cart.

## Non-goals (later phases or never)

- Native Home, Cart, Checkout, Orders, Artisan pages, Seller Centre or Admin Centre. These stay web.
- A guest cart inside the app (decided: the app asks guests to sign in first, as Shopee does).
- Push notifications, seller camera upload (Phase 2 and 3), offline browsing.
- Android release builds. The Android toolchain isn't installed and disk space is low. The code should stay Android-friendly, but iOS Simulator is the test target.

## Anti-goals (failure even if it "works")

- Shoppers getting signed out at random because the app and the website fight over refresh tokens.
- The native cart badge and the web Cart page disagreeing.
- Anything changing for people using the website in a normal browser.
- Native screens showing products the website hides: inactive products or products from shops that aren't verified.

## Approaches considered

1. **One shared WebView behind the native tabs (chosen).** Native Shop, Product and Account. Home, Cart and Orders share a single WebView that navigates to `/`, `/cart` or `/orders` on tab switch. Product taps inside web pages open the native Product screen. Trade-off: web tabs don't keep their own scroll position. It's the lightest option, and cart and sign-in stay in sync with little extra work.
2. **A separate WebView per web tab.** Each tab keeps its own history, like real app tabs. Rejected: three copies of the site run at once, which means more memory on low-end Android phones, plus three session handoffs and cross-tab cart refreshes.
3. **Native screens get their data through the WebView (a JS bridge to the site's code).** Rejected: slow, and native screens would break whenever the site changes.

Guest add-to-cart: the user picked **sign in first** over a phone-side guest cart that merges at sign-in.

## Design

### 1. Cart in Supabase

New migration (next timestamp after `20261128000001_admin.sql`):

- Table `public.cart_items`: `profile_id uuid` references profiles, on delete cascade; `product_id uuid` references products, on delete cascade; `qty int not null check (qty > 0)`; `created_at` and `updated_at` timestamptz; primary key `(profile_id, product_id)`.
- RLS: a signed-in user can select, insert, update and delete only rows where `profile_id = auth.uid()`. This is the same shape as the `wishlists` policy. Grant it to `authenticated` (new projects don't auto-grant; see `20261124000004_api_grants.sql`).
- RPC `add_to_cart(p_product_id uuid, p_qty int) returns int`, security definer, for `authenticated` only:
  - It upserts the caller's row, adding `p_qty`, and clamps the result to the product's current stock. It returns the new quantity.
  - It refuses products that are inactive, sold out, or whose artisan isn't verified.
  - Both native and web use it, so a double tap or two devices can't overshoot stock with a read-then-write race.
- Setting a quantity and removing a line are plain `update` and `delete` calls under RLS. `place_order` already re-checks price and stock at checkout, so nothing there changes.
- SQL checks: RLS isolation between two users, clamping to stock, refusing inactive or unverified products, and the cascade when a product is deleted. *(Builder's call, made in review:)* the PGlite harness used in earlier milestones was a throwaway outside the repo and is gone. Rebuild a small one in the repo under `supabase/tests/`, run with `npm run test:sql`:
  - It loads all migrations into PGlite.
  - It stubs `auth.users`, `auth.uid()` and the `anon`, `authenticated` and `service_role` roles.
  - It runs the cart checks plus a few smoke checks on existing RLS (one per main table).
  - Re-creating all 93 earlier checks is out of scope.

Web cart store (`src/stores/cart.ts`) keeps its public API (`lines`, `count`, `shops`, `subtotal`, `add`, `setQty`, `remove`, `removeMany`, `refresh`), so the five callers don't change.

- **Signed out, normal browser:** works exactly as today, using localStorage key `craftcebu-cart`.
- **Signed out, in the app:** there is no guest cart. The cart reads as empty, and `add` (for example, quick add on Home's product cards) sends `login` to native, matching the native screens. The web Cart page and the native badge therefore both show zero.
- **Signed in:** `lines` load from `cart_items`, joined to the same product select as `catalog.ts`, and are turned into `CartLine`s. Writes go to Supabase optimistically and roll back on error, the way `wishlist.ts` does. `add` calls `add_to_cart`, and in the app it also sends `cartChanged`.
- **On sign-in, in a browser or the app:** any lines still in localStorage are merged into Supabase through `add_to_cart`, then the local cart is cleared. In the app this picks up carts left by the current WebView-only build.
- The store exposes a `reload()` so the app can ask the web to re-read the cart after a native add.

### 2. Sharing the login between native and web

The native side owns the session. The web side borrows only the short-lived access token and **never holds the refresh token**.

Why it's built this way (found in review): supabase-js `getSession()` refreshes a session that is about to expire even when `autoRefreshToken` is off, and every query calls it. Handing the web a refresh token would let it rotate the token out from under native.

**App mode on the website.** The app's WebView appends `CraftCebuApp/1` to its user agent. The site sets `inApp = navigator.userAgent.includes('CraftCebuApp')`. When `inApp` is false, nothing changes. When `inApp` is true:

- **The Supabase client** (`src/lib/supabase.ts`) is created with supabase-js's `accessToken` option, which is supported in the installed 2.119.
  - The callback returns the token native last sent.
  - When that token is within 60 seconds of expiring, the callback first sends `needToken` and waits for native's reply, up to about 5 seconds.
  - With this option, `supabase.auth` is switched off, so the web can't refresh or sign out by itself.
- **The auth store** (`src/stores/auth.ts`) takes its session from native in app mode: the user plus the access token and its expiry. It doesn't call `supabase.auth`. Profile loading and the banned check stay the same; a banned profile sends `signOut` to native.
- The site hides its own header, mobile tab bar and footer, because the native tab bar replaces them.
- Every navigation to `/login` or `/register`, including `requiresAuth` guard redirects, cancels and asks native to show sign-in instead.

**Bridge.** The site and the app talk through a JavaScript channel named `CraftCebuNative`; native answers by calling `window.craftcebu.*` functions the site defines when `inApp` is true. Messages are JSON.

| Direction | Message | Meaning |
|---|---|---|
| web → native | `ready` | The site has booted. Native replies with `setSession` or `clearSession`. |
| web → native | `needToken` | The access token is about to expire. Native refreshes if needed and replies with `setSession`, or with `clearSession` if the refresh fails. |
| web → native | `signOut` | For example, a banned profile. Native signs out, which also clears every WebView. |
| web → native | `login` `{ returnTo }` | Show native sign-in, then return to that path. |
| web → native | `openProduct` `{ slug }` | Open the native Product screen. |
| web → native | `openShop` `{ category?, town?, q? }` | Switch to the native Shop tab with those filters. |
| web → native | `cartChanged` | Refresh the native cart badge. |
| native → web | `setSession({ access_token, expires_at, user })` | Stores the token for the client's `accessToken` callback and updates the auth store. It never includes the refresh token. |
| native → web | `clearSession()` | Forget the token and clear the auth store and cart. |
| native → web | `navigate(path)` | `router.push(path)`. Used on web tab switches. |
| native → web | `reloadCart()` | Calls the cart store's `reload()`. |

- The auth store's `init()` in app mode waits for the first `setSession` or `clearSession` reply before resolving. It times out after about 3 seconds and treats that as signed out. That way route guards don't bounce a signed-in shopper to the sign-in flow.
- Whenever supabase_flutter reports a sign-in, token refresh or sign-out, native pushes `setSession` or `clearSession` to every live WebView.
- Taps on product and shop links happen inside Vue Router with no page load, so the WebView's navigation delegate can't see them. The site's `router.beforeEach` sends `openProduct` or `openShop` and cancels the navigation when `inApp` is true. `/shop?category=…` links on Home therefore land on the native Shop tab.

### 3. Native app structure

The current `main.dart` gets split up. The palette constants and the WebView setup in `ShellScreen` are reused: the navigation delegate, external links, the Android photo picker, the offline view and back handling.

- **Supabase:** `supabase_flutter`, initialised with the project URL and the anon key. Both are already public in the web bundle; the service-role key and Maya keys never go in the app. It persists the session on the device and refreshes it automatically.
- **Tab shell:** an `IndexedStack` keeps the native tab screens alive across switches. The single web tab view is shown for Home, Cart and Orders; switching to one of those calls `navigate('/')`, `navigate('/cart')` or `navigate('/orders')`. Switching to Cart also calls `reloadCart()`. The app opens on Home. The Cart tab shows a badge with the number of pieces, read from `cart_items`.
- **Back button:** Android back and the iOS edge swipe pop native screens first, then step back in the WebView, then leave the app from Home.
- **Shop screen:** queries match `fetchProducts` and `fetchFacets` in `src/lib/catalog.ts`. That includes the `artisan.status = verified` and `is_active` filters, ratings from visible reviews, and sort by newest or price. Products with no photos use the same craft stand-in photos as `src/lib/images.ts`.
- **Product screen:** queries match `fetchProduct`, `fetchReviews`, the more-from-maker rail and the related rail in `ProductView.vue`.
  - Tapping the maker opens `/artisans/<slug>` in the web tab, on the Home tab.
  - "Add to cart" when signed out opens sign-in, then adds the item and shows "Added · View cart". "View cart" goes to the Cart tab.
  - The wishlist heart uses the `wishlists` table, and a signed-out tap opens sign-in.
- **Account and sign-in:** a native screen with email and password sign-in, sign-up, and forgot password.
  - Sign-up sends `full_name`, as `auth.ts` does.
  - Forgot password sends the reset link to the web `/reset-password` page.
  - After sign-in, the app loads the profile; a banned profile is signed out with the same message the web shows.
  - Sign-up may need email confirmation. In that case the app shows "Check your email" (this depends on Supabase Auth URL settings pointing to craftcebu.vercel.app).
- **Account links to web pages.** App mode hides the web header, user menu and footer, so Account has to link to every page they used to reach. *(Builder's call, made in review.)*
  - Edit profile (`/account`).
  - Sell on CraftCebu (`/sell`), for anyone who isn't an artisan or the owner. This includes pending or rejected applicants, as the web user menu does today.
  - Seller Centre (`/seller`) for verified artisans and the owner.
  - Admin Centre (`/admin`) for the owner.
  - Shop by origin (`/origins`) and Meet the makers (`/artisans`).
- These pages open in a full-screen WebView pushed over the tabs. It's a second, short-lived controller with the same user agent and bridge, closed with a back button.
- **Look:** the paper, ink and atsuete palette, Fraunces for headings and DM Sans for text. The font files are bundled in `assets/` rather than fetched at run time, so they work on a bad connection. Both fonts use the Open Font License.

### 4. Shipping safely

- The web changes are backward compatible. Without the `CraftCebuApp` user agent the site behaves as today, so the current WebView-only build and normal browsers keep working while the native build is in progress.
- **Order:** migration, then the web cart store and app mode (deployed), then the native app.
- Pushing the migration, pushing to GitHub (which deploys to Vercel), and any Supabase changes each need the user's go-ahead.
- **iOS dependencies:** CocoaPods doesn't work on this Mac (Ruby 2.6), so every plugin has to support Swift Package Manager. Check `supabase_flutter`'s native dependencies (e.g. `app_links`, `shared_preferences`, `path_provider`) build under SPM before writing screens on top of it. If one doesn't, fall back to the pure-Dart `supabase` package with session storage in `shared_preferences`.

### 5. How we know it works

- `npm run test:sql` passes, including the cart checks.
- **In a desktop browser:** the site with no app user agent behaves exactly as today, including the guest cart and the merge on sign-in. With the user agent faked, the site hides its header and tab bar, sends the bridge messages, and accepts `setSession`. It asks for `needToken` when the token is near expiry, and no refresh-token request ever leaves the page.
- **On the iOS Simulator, end to end:**
  1. Browse Shop as a guest.
  2. Tap add, sign in natively, and see the item added.
  3. The Cart tab shows the item and the badge matches.
  4. Check out with Maya sandbox in the web view.
  5. The order appears under Orders.
  6. Sign out in Account and see the web tabs signed out.
  7. Reopen the app after more than an hour and confirm the shopper is still signed in, with no refresh-token errors.
- `flutter analyze` is clean.

## Left to the builder

- State management in Flutter. Plain `ChangeNotifier` or `ValueNotifier` is enough; avoid adding a framework unless a screen needs it.
- File and widget layout under `mobile/lib/`, exact spacing, motion, and loading skeletons, staying close to the web design.
- Whether images use `Image.network` or a caching package. Any package with native code must pass the SPM check.
- Page size for infinite scroll (the web uses 12).
- The exact bridge function names, as long as they cover the table above.
