# Native App Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the CraftCebu Flutter app native where shoppers browse (Shop, Product, Account, tab bar), keep the cart in Supabase, and share one login with the web pages that stay in the app.

**Architecture:**
- **Cart:** a `cart_items` table and an `add_to_cart` RPC become the single cart for both native and web.
- **Website in the app:** the Vue site gains an "app mode", triggered by a `CraftCebuApp` user agent. In app mode it borrows only access tokens from native through a JS bridge, hides its own header and tab bar, and hands product, shop and login navigation to native.
- **Native app:** the Flutter app owns the Supabase session. A native tab shell hosts the Shop, Product and Account screens plus one shared WebView for Home, Cart and Orders.

**Tech Stack:**
- Supabase: Postgres, RLS, PGlite for SQL tests.
- Web: Vue 3, Pinia, Vue Router, supabase-js 2.119 (`accessToken` option), Node 26 `node --test` for pure TS modules.
- Mobile: Flutter, `supabase_flutter`, `webview_flutter`, Swift Package Manager (no CocoaPods).

**Spec:** `docs/superpowers/specs/2026-11-25-native-app-phase1-design.md`. Read it first; this plan argues from it.

## Global Constraints

- **Normal browsers don't change.** With no `CraftCebuApp` in the user agent (and no dev fake flag), the site must behave exactly as today.
- **The web never holds the refresh token in app mode.** No message, storage write or log in the web view may contain `refresh_token`.
- **App user agent:** native appends ` CraftCebuApp/1` to the WebView's default user agent.
- **Bridge names:** the JS channel is `CraftCebuNative`. Native calls into the page via `window.craftcebu.*`. Every message is a JSON object with a `type` field.
- **Token margin:** the web asks native for a new token when the current one has 60 seconds or less left. It waits up to 5 seconds for the reply. The auth store's first-session wait in app mode times out after 3 seconds and treats that as signed out.
- **Same catalog rules everywhere.** Native queries apply the same filters as `src/lib/catalog.ts`: `is_active = true`, `artisan.status = 'verified'`, ratings only from reviews with `is_hidden = false`.
- **Keys:** the service-role key and Maya keys never go in the app or under any `VITE_` name. The Supabase URL and anon key reach Flutter via `--dart-define-from-file=env.json`. `mobile/env.json` is gitignored, and `mobile/env.example.json` is committed.
- **iOS dependencies:** CocoaPods is unusable on this Mac (Ruby 2.6). Every Flutter plugin must build with Swift Package Manager.
- **Don't touch the root `package.json` or `package-lock.json`.** They carry the user's uncommitted Capacitor changes. SQL tests get their own `supabase/tests/package.json`. Web unit tests run with plain `node --test`. Never `git add -A`; stage named paths only.
- **Get the user's go-ahead first** for `supabase db push`, `git push` (which deploys to Vercel), and any file download such as font files. Ask in chat each time.
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Palette:** paper `#FAF6EE`, ink `#1F1A17`, atsuete `#AE3D24`, mango `#EDB54A`. Fonts are Fraunces (headings) and DM Sans (text), bundled as TTF.

## Review Focus

1. **The app is reopened after more than an hour in the background.** The shopper stays signed in, and the web tabs get a fresh token from native rather than refreshing on their own. Pinned by tests in Task 2 and Task 7, and by Task 13's step 7.
2. **Double-tapping add, or adding more than stock.** The cart quantity never exceeds stock, and the second tap reports "you already have every available piece" rather than erroring. Pinned in Task 1 (SQL) and Task 10 (quick add).
3. **A product in the cart becomes inactive, sold out or deleted.** The cart page drops it with the existing "removed" toast, and its `cart_items` row is deleted too, so the native badge doesn't count it. Pinned in Task 3.
4. **A signed-out shopper hits a page that needs sign-in inside the web view** (wishlist heart on Home, `/orders`, `/checkout`). Native sign-in opens, and after signing in the shopper lands back on the page they wanted. Pinned in Task 4 and Task 12.
5. **New Postgres functions are executable by `PUBLIC` by default.** `add_to_cart` must be revoked from `public` and `anon`, and an anonymous call must fail. Pinned in Task 1.

---

## File map

**Supabase**
- Create `supabase/migrations/20261129000001_cart.sql`: the `cart_items` table, RLS, grants, the `add_to_cart` RPC, and an `updated_at` trigger.
- Create `supabase/tests/package.json`, `supabase/tests/harness.mjs` (loads the stubs and migrations into PGlite) and `supabase/tests/stubs.sql` (stand-ins for the `auth` and `storage` schemas and the roles).
- Create `supabase/tests/cart.test.mjs` and `supabase/tests/smoke.test.mjs`.

**Web**
- Create `src/lib/app/token.ts`: pure, with no imports.
- Create `src/lib/app/bridge.ts`: app-mode detection, posting to native, and the `window.craftcebu` handlers.
- Create `src/lib/cart.ts`: Supabase cart calls.
- Modify `src/lib/supabase.ts`, `src/stores/auth.ts`, `src/stores/cart.ts`, `src/router/index.ts`, `src/layouts/AppLayout.vue`, `src/main.ts` and `src/types/database.ts`.
- Create `tests/web/token.test.ts`. It lives outside `src/` so `vue-tsc` ignores it.

**Mobile** (`mobile/lib/`)
- `main.dart`: init, then `runApp`.
- `config.dart`: dart-define values.
- `theme.dart`.
- `session/app_session.dart`.
- `web/web_view_factory.dart`, `web/bridge.dart` and `web/web_page.dart`.
- `shell/tab_shell.dart`.
- `data/models.dart`, `data/catalog_repo.dart`, `data/cart_repo.dart`, `data/wishlist_repo.dart` and `data/stand_in_images.dart`.
- `screens/shop/…`, `screens/product/…`, `screens/account/…` and `screens/web_page_screen.dart`.
- Tests in `mobile/test/`.

---

### Task 1: Cart table, `add_to_cart`, and the SQL test harness

**Files:**
- Create: `supabase/tests/package.json`. It needs `"type": "module"`, a dependency on `@electric-sql/pglite`, and the script `"test": "node --test"`.
- Create: `supabase/tests/stubs.sql` and `supabase/tests/harness.mjs`.
- Create: `supabase/tests/cart.test.mjs` and `supabase/tests/smoke.test.mjs`.
- Create: `supabase/migrations/20261129000001_cart.sql`.

**Interfaces:**
- Produces, in SQL:
  - Table `public.cart_items(profile_id uuid, product_id uuid, qty int > 0, created_at, updated_at)` with primary key `(profile_id, product_id)`, and on-delete cascade from both profiles and products.
  - `public.add_to_cart(p_product_id uuid, p_qty int) returns int`. It returns the new quantity, clamped to stock.
  - It raises `'not_available'` when the product is inactive, missing, or from an artisan that isn't verified.
  - It raises `'sold_out'` when stock is 0.
  - It raises `'invalid_qty'` when `p_qty < 1`.
- Produces, in JS: `harness.mjs` exports these.
  - `async newDb(): Promise<PGlite>`: stubs plus every file in `supabase/migrations/` in name order, then `supabase/seed.sql`.
  - `async asUser(db, userId | null, fn)`: sets role `authenticated` (or `anon` when `null`) and `request.jwt.claim.sub`, runs `fn`, then resets.
  - `async makeUser(db, { email, role? }): Promise<string>`: inserts into `auth.users`, so the `handle_new_user` trigger makes the profile, then optionally sets the profile role.
  - `async makeProduct(db, { stock, isActive?, artisanStatus? }): Promise<string>`: creates an artisan user, an artisan row and a product.

`stubs.sql` must provide:
- Roles `anon`, `authenticated` and `service_role`.
- Schema `auth`, with a `users` table that has at least `id`, `email` and `raw_user_meta_data jsonb`.
- `auth.uid()`, returning `nullif(current_setting('request.jwt.claim.sub', true), '')::uuid`.
- Schema `storage`, with `buckets` and `objects` tables, and `storage.foldername(text) returns text[]`. These are the only `auth.`/`storage.` objects the migrations use.

- [ ] **Step 1: Write the harness and a smoke test.** `smoke.test.mjs` contains:
  - `migrations load`: `newDb()` resolves.
  - `anon sees only active products from verified shops`: as `null`, a select on products returns the verified-active product and none of the others.
  - `buyer cannot read another buyer's wishlist`: as user B, a select on A's wishlist rows returns 0 rows.

- [ ] **Step 2: Run the smoke test and check it passes.** Run `npm --prefix supabase/tests install && npm --prefix supabase/tests test`. Expected: 3 pass. Fix the stubs, not the migrations, until it does.

- [ ] **Step 3: Write the failing cart tests** in `cart.test.mjs`:
  - `add_to_cart inserts then accumulates`: with stock 5, adding 2 returns 2; adding 2 again returns 4.
  - `add_to_cart clamps to stock`: with stock 3, adding 2 then 5 returns 3, and the row's qty is 3.
  - `add_to_cart rejects sold out`: with stock 0, it throws `/sold_out/`.
  - `add_to_cart rejects inactive and unverified`: `isActive: false`, and separately `artisanStatus: 'pending'`, each throw `/not_available/`.
  - `add_to_cart rejects qty below 1`: `p_qty` of 0 throws `/invalid_qty/`.
  - `anon cannot call add_to_cart`: as `null`, it throws a permission error.
  - `users only see and change their own cart`: B's `select`, `update` and `delete` on A's rows affect 0 rows, and B's insert with `profile_id = A` throws.
  - `deleting a product removes cart rows`: after deleting the product (as `service_role`), the cart has 0 rows.

- [ ] **Step 4: Run the cart tests and check they fail.** Run `npm --prefix supabase/tests test`. Expected: the cart tests fail because `add_to_cart` and `cart_items` don't exist.

- [ ] **Step 5: Write `20261129000001_cart.sql`.**
  - RLS policy "Manage own cart": `for all using (profile_id = auth.uid()) with check (profile_id = auth.uid())`.
  - `grant select, insert, update, delete on public.cart_items to authenticated` and `grant all … to service_role`.
  - `add_to_cart` is `security definer` with `set search_path = public`.
  - Lock the product row with `select … for update` before upserting.
  - `revoke execute on function public.add_to_cart(uuid, int) from public, anon; grant execute … to authenticated`.
  - Add an `updated_at` trigger on update.

- [ ] **Step 6: Run all SQL tests and check they pass.** Run `npm --prefix supabase/tests test`. Expected: 11 pass, 0 fail.

- [ ] **Step 7: Commit**

```bash
git add supabase/migrations/20261129000001_cart.sql supabase/tests
git commit -m "Add the shared cart table with SQL tests"
```

(Not pushed to Supabase yet; that happens in Task 5.)

---

### Task 2: Web app mode, the token bridge, and the auth store

**Files:**
- Create: `src/lib/app/token.ts`, `src/lib/app/bridge.ts` and `tests/web/token.test.ts`.
- Modify: `src/lib/supabase.ts`, `src/stores/auth.ts` and `src/main.ts`.

**Interfaces:**
- Produces, in `token.ts`, which has no imports so `node --test` can load it:
  - `export const TOKEN_MARGIN_SECONDS = 60`
  - `export function needsFreshToken(expiresAt: number | null, nowSeconds: number, margin = TOKEN_MARGIN_SECONDS): boolean`. It returns true when `expiresAt` is null or `expiresAt - nowSeconds <= margin`.
  - `export function parseSessionPayload(raw: unknown): AppSessionPayload | null`. It accepts only `{ access_token: string, expires_at: number, user: { id: string, email?: string } }`, and strips any other keys, including `refresh_token`.
  - `export interface AppSessionPayload { access_token: string, expires_at: number, user: { id: string, email?: string, user_metadata?: Record<string, unknown> } }`
- Produces, in `bridge.ts`:
  - `export const inApp: boolean`. It's true when `navigator.userAgent.includes('CraftCebuApp')`, or when `import.meta.env.DEV && localStorage.getItem('craftcebuFakeApp') === '1'`. Wrap the localStorage read in try/catch.
  - `export type NativeMessage = { type: 'ready' } | { type: 'needToken' } | { type: 'signOut' } | { type: 'login', returnTo: string } | { type: 'openProduct', slug: string } | { type: 'openShop', category?: string, town?: number, q?: string } | { type: 'cartChanged' }`
  - `export function postToNative(msg: NativeMessage): void`. It calls `window.CraftCebuNative?.postMessage(JSON.stringify(msg))`. Under the DEV fake flag it pushes to `window.__craftcebuSent` instead.
  - `export function appAccessToken(): Promise<string | null>`. It returns the current token. If `needsFreshToken` says so, it first posts `needToken` and waits up to 5 seconds for the next `setSession` or `clearSession`.
  - `export function onAppSession(cb: (s: AppSessionPayload | null) => void): () => void`, which returns an unsubscribe function.
  - `export function installAppHandlers(h: { navigate(path: string): void, reloadCart(): void }): void`. It defines `window.craftcebu = { setSession, clearSession, navigate, reloadCart }` and then posts `ready`.
- Modifies `supabase.ts`: when `inApp`, `createClient(url, anonKey, { accessToken: appAccessToken })`; otherwise the call is unchanged.
- Modifies `auth.ts`, in app mode only:
  - `init()` subscribes with `onAppSession`, then waits for the first payload or 3 seconds.
  - `session` holds `{ access_token, expires_at, user }`, cast to `Session`.
  - `signOut()` posts `signOut` and clears local state.
  - `signIn`, `signUp`, `sendPasswordReset` and `updatePassword` throw `new Error('Use the app's sign-in')`.
  - There are no `supabase.auth` calls anywhere in app mode, since the `accessToken` option disables them.
  - Banned profile: post `signOut`.
- Modifies `main.ts`: after mounting, when `inApp`, call `installAppHandlers({ navigate: p => router.push(p), reloadCart: () => useCartStore().reload() })`. Leave `reload` as a no-op until Task 3.

- [ ] **Step 1: Write the failing tests** in `tests/web/token.test.ts`, importing `../../src/lib/app/token.ts`:
  - `fresh token is kept`: `needsFreshToken(1000, 900)` is false.
  - `token within 60s needs refresh`: `needsFreshToken(1000, 940)` is true.
  - `missing expiry needs refresh`: `needsFreshToken(null, 0)` is true.
  - `payload strips refresh_token`: `parseSessionPayload({ access_token: 'a', expires_at: 1, refresh_token: 'r', user: { id: 'u' } })` deep-equals `{ access_token: 'a', expires_at: 1, user: { id: 'u' } }`.
  - `malformed payload is rejected`: `parseSessionPayload({ access_token: 1 })` is null.

- [ ] **Step 2: Run the tests and check they fail.** Run `node --test tests/web/`. Expected: FAIL, because the module isn't found.

- [ ] **Step 3: Implement `token.ts`, then `bridge.ts`, `supabase.ts`, `auth.ts` and `main.ts`** per the interfaces above.

- [ ] **Step 4: Run the tests and the type check.** Run `node --test tests/web/ && npm run build`. Expected: 5 pass, and the build succeeds.

- [ ] **Step 5: Browser check of normal mode.** Run the dev server (`npm run dev`) and open it in the browser pane.
  - Signing in, browsing and the guest cart behave exactly as before.
  - `window.craftcebu` is undefined.

- [ ] **Step 6: Commit**

```bash
git add src/lib/app src/lib/supabase.ts src/stores/auth.ts src/main.ts tests/web
git commit -m "Let the site borrow its session from the app"
```

---

### Task 3: Cart store backed by Supabase

**Files:**
- Create: `src/lib/cart.ts`.
- Modify: `src/stores/cart.ts` and `src/types/database.ts`, adding `CartItem`.

**Interfaces:**
- Consumes `auth.user`, `inApp` and `postToNative` from Task 2, and `add_to_cart` from Task 1.
- Produces, in `src/lib/cart.ts`:
  - `fetchCartLines(): Promise<CartLine[]>`. It selects `cart_items` with `product:products(<the productSelect from catalog.ts>)` and maps each row to `CartLine`. Export `productSelect` from `catalog.ts` rather than copying it.
  - `addToCart(productId: string, qty: number): Promise<number>`, which calls the RPC.
  - `setCartQty(productId: string, qty: number): Promise<void>`
  - `removeCartItems(productIds: string[]): Promise<void>`
- Produces, in the store: the public API is unchanged (`lines`, `count`, `shops`, `subtotal`, `add`, `setQty`, `remove`, `removeMany`, `refresh`), plus `reload(): Promise<void>`.
  - `add` becomes `async add(product, qty): Promise<void>`. Callers in `ProductCard.vue` and `ProductView.vue` await it and show the existing toasts.
  - When `add` is called in app mode while signed out, it posts `login` with `returnTo` set to the current path and resolves without adding.

Behaviour, per the spec's section 1:
- **Signed out, normal browser:** localStorage, as today.
- **Signed out, in the app:** `lines` is empty.
- **Signed in:** `lines` comes from `fetchCartLines()`.
  - Writes are optimistic and roll back on error, with a toast.
  - In app mode, every successful write posts `cartChanged`.
- **On a signed-in change** (`watch(() => auth.user?.id)`): call `addToCart` for each saved local line, clear the `craftcebu-cart` key, then `reload()`.
- **`refresh(fresh)`:** when signed in, it also calls `removeCartItems` for the dropped ids.

- [ ] **Step 1: Write `src/lib/cart.ts` and wire the store.** This logic is about Supabase and Pinia state and has no pure core, so it's checked in the browser rather than unit-tested.

- [ ] **Step 2: Run the type check.** Run `npm run build`. Expected: success.

- [ ] **Step 3: Browser check in normal mode.** This needs the migration live (Task 5) for the signed-in parts. Until then, check only the guest flow, and note that the signed-in checks move to Task 5.
  - A guest adds 2 items, and the cart shows them.
  - Signing in merges them into `cart_items`, and the local key is cleared.
  - Changing quantity and removing persist across a reload.
  - A product whose stock is set to 0 disappears from the cart with the "removed" toast, and its row is gone.

- [ ] **Step 4: Commit**

```bash
git add src/lib/cart.ts src/lib/catalog.ts src/stores/cart.ts src/types/database.ts src/components/catalog/ProductCard.vue src/views/ProductView.vue
git commit -m "Keep signed-in carts in Supabase"
```

---

### Task 4: Hand navigation to native, and hide the web chrome in the app

**Files:**
- Modify: `src/router/index.ts`, `src/layouts/AppLayout.vue` and `src/style.css` (only if a utility is needed).

**Interfaces:**
- Consumes `inApp` and `postToNative` from Task 2.
- In `router.beforeEach`, when `inApp`, these checks run before the existing guards:
  - `to.name === 'product'`: post `openProduct` with `{ slug }` and `return false`.
  - `to.name === 'shop'`: post `openShop` with `category`, `town` (as a number) and `q` from the query, and `return false`.
  - `to.name` is `login` or `register`: post `login` with `returnTo` set to `to.query.redirect ?? from.fullPath`, and `return false`.
  - The `requiresAuth` redirect for a signed-out user posts `login` with `returnTo` set to `to.fullPath`, and returns `false` instead of the login route.
  - On the very first navigation (`from.matched.length === 0`), a `false` would leave a blank page, so return `{ name: 'home' }` after posting.
- In `AppLayout.vue`, when `inApp`: don't render the `<header>`, `MobileTabBar` or `SiteFooter`, and drop the tab-bar bottom padding.

- [ ] **Step 1: Implement the router and layout changes.**

- [ ] **Step 2: Run the type check.** Run `npm run build`. Expected: success.

- [ ] **Step 3: Browser check in fake app mode.** In the browser pane, run `localStorage.craftcebuFakeApp = '1'`, then reload.
  - There's no header, tab bar or footer.
  - Clicking a product card on Home pushes `{type:'openProduct', slug}` to `window.__craftcebuSent`, and the URL stays `/`.
  - The Home craft links push `openShop`.
  - Opening `/orders` while signed out pushes `{type:'login', returnTo:'/orders'}`.
  - The wishlist heart while signed out pushes `login`.
  - `window.craftcebu.navigate('/cart')` shows the cart.

  Then run `localStorage.removeItem('craftcebuFakeApp')`, reload, and confirm the normal site is back.

- [ ] **Step 4: Commit**

```bash
git add src/router/index.ts src/layouts/AppLayout.vue
git commit -m "Hand product, shop and sign-in links to the app"
```

---

### Task 5: Go live with the migration and web changes (user gate)

- [ ] **Step 1: Ask the user** in chat for a go-ahead to push the migration, then run `npx supabase db push --remote --yes` from the `craftcebu/` folder. Expected: `20261129000001_cart.sql` applied.
- [ ] **Step 2: Finish Task 3's signed-in browser checks** against the live database, using the dev server.
- [ ] **Step 3: Ask the user** for a go-ahead to `git push origin main`, which also deploys to Vercel. After the deploy, open https://craftcebu.vercel.app and confirm the normal site works: guest cart, sign-in, cart merge, checkout page loads.

---

### Task 6: Flutter foundation (Supabase, config, theme, session)

**Files:**
- Modify: `mobile/pubspec.yaml` (`flutter pub add supabase_flutter`, plus the font assets) and `mobile/.gitignore` (add `env.json`).
- Create: `mobile/env.example.json` with keys `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `HOME_URL`.
- Create: `mobile/lib/config.dart`, `mobile/lib/theme.dart` and `mobile/lib/session/app_session.dart`.
- Create: `mobile/assets/fonts/` holding Fraunces and DM Sans TTFs, from the google/fonts GitHub repository. Ask the user before downloading.
- Modify: `mobile/lib/main.dart`, keeping it as init plus `runApp`.
- Test: `mobile/test/app_session_test.dart`.

**Interfaces:**
- Produces, in `config.dart`: `const supabaseUrl = String.fromEnvironment('SUPABASE_URL')`, likewise `supabaseAnonKey`, and `homeUrl = String.fromEnvironment('HOME_URL', defaultValue: 'https://craftcebu.vercel.app')`.
- Produces, in `theme.dart`: `paper`, `ink`, `atsuete`, `mango`, and `ThemeData craftCebuTheme()`.
- Produces, in `app_session.dart`:
  - `class AppSession extends ChangeNotifier` wraps `Supabase.instance.client.auth` and exposes:
    - `User? user`
    - `Profile? profile` (role, full name, `artisanStatus`)
    - `bool get signedIn`
    - `Future<void> signIn(String email, String password)`. It throws `AuthException`, and throws `BannedException` after signing out a banned profile.
    - `Future<bool> signUp(String fullName, String email, String password)`, which returns true when email confirmation is needed.
    - `Future<void> sendPasswordReset(String email)`, with `redirectTo: '$homeUrl/reset-password'`.
    - `Future<void> signOut()`
    - `Future<Map<String, Object?>?> webSessionPayload()`. It refreshes first when 60 seconds or less are left, and returns `null` when signed out.
  - `Map<String, Object?> sessionPayloadFor(Session s)` is a top-level pure function. It returns `{access_token, expires_at, user: {id, email, user_metadata}}` and never includes `refresh_token`.

Before writing screens:
- [ ] **Step 1: Check iOS dependencies under Swift Package Manager.** Run `flutter pub add supabase_flutter`, then `flutter build ios --simulator --debug` from `mobile/` with `--dart-define-from-file=env.json`.
  - Expected: the build succeeds without CocoaPods.
  - If a plugin has no SPM support, replace the package with pure-Dart `supabase` plus `shared_preferences` for persistence (spec §4), and note it in the commit message.

- [ ] **Step 2: Write the failing tests:**
  - `payload never includes refresh_token`: build a `Session` with `refreshToken: 'r'`; `sessionPayloadFor(s)` has no `refresh_token` key and has `access_token` and `expires_at`.
  - `payload carries the user id`.

- [ ] **Step 3: Run the tests and check they fail.** Run `cd mobile && flutter test test/app_session_test.dart`. Expected: FAIL, because the function isn't defined.

- [ ] **Step 4: Implement the config, theme and `AppSession`.** `main.dart` calls `Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey)`. For now it still shows the existing WebView screen.

- [ ] **Step 5: Run the tests and analyzer.** Run `flutter test && flutter analyze`. Expected: all pass, no issues.

- [ ] **Step 6: Commit**

```bash
git add mobile/pubspec.yaml mobile/pubspec.lock mobile/.gitignore mobile/env.example.json mobile/lib mobile/test mobile/assets/fonts mobile/ios
git commit -m "Add Supabase sign-in to the Flutter app"
```

---

### Task 7: WebView factory and bridge

**Files:**
- Create: `mobile/lib/web/web_view_factory.dart`. Move the controller setup out of `ShellScreen`: the WebKit params, navigation delegate, external links, Android file picker and swipe-back.
- Create: `mobile/lib/web/bridge.dart` and `mobile/lib/web/web_page.dart` (the progress bar and offline view, moved from `main.dart`).
- Test: `mobile/test/bridge_test.dart`.

**Interfaces:**
- Consumes `AppSession` and `webSessionPayload()` from Task 6.
- Produces:
  - `Future<WebViewController> createWebController({required String initialUrl})`. It appends ` CraftCebuApp/1` to `await controller.getUserAgent()` via `setUserAgent`.
  - `sealed class BridgeMessage`, with subclasses `Ready`, `NeedToken`, `SignOutRequest`, `LoginRequest(String returnTo)`, `OpenProduct(String slug)`, `OpenShop({String? category, int? town, String? q})` and `CartChanged`.
  - `static BridgeMessage? BridgeMessage.parse(String json)` returns `null` for an unknown type or bad JSON.
  - `class WebBridge` with:
    - Constructor `WebBridge(WebViewController c, AppSession session, BridgeHandlers handlers)`. It adds the `CraftCebuNative` channel.
    - `Future<void> pushSession()`, which sends `setSession(payload)` or `clearSession()` via `runJavaScript`.
    - `Future<void> navigate(String path)`
    - `Future<void> reloadCart()`
  - `class BridgeHandlers { void Function(String returnTo) onLogin; void Function(String slug) onOpenProduct; void Function(OpenShop) onOpenShop; void Function() onCartChanged; }`
  - `Ready` and `NeedToken` are handled inside `WebBridge` by `pushSession()`. `SignOutRequest` calls `session.signOut()`.
  - `WebBridge` listens to `AppSession` and pushes on every change.
- Values go to JS with `jsonEncode`, never string concatenation.

- [ ] **Step 1: Write the failing tests:**
  - `parses openProduct`: `BridgeMessage.parse('{"type":"openProduct","slug":"banig"}')` is `OpenProduct` with slug `banig`.
  - `parses openShop with town as int`.
  - `unknown type returns null`.
  - `bad json returns null`.
  - `setSession script escapes values`: `setSessionScript({'access_token': "a'\"</script>"})` round-trips through `jsonDecode` of the argument. Expose `String setSessionScript(Map payload)` for this test.

- [ ] **Step 2: Run the tests and check they fail.** Run `flutter test test/bridge_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement the factory, bridge and `WebPage`.**

- [ ] **Step 4: Run the tests and analyzer.** Run `flutter test && flutter analyze`. Expected: pass.

- [ ] **Step 5: Commit** `mobile/lib/web` and `mobile/test/bridge_test.dart` with the message `Add the app-to-site bridge`.

---

### Task 8: Native tab shell

**Files:**
- Create: `mobile/lib/shell/tab_shell.dart` and `mobile/lib/data/cart_repo.dart`.
- Modify: `mobile/lib/main.dart`, whose home becomes `TabShell`. Delete the old `ShellScreen`.

**Interfaces:**
- Consumes `createWebController`, `WebBridge` and `WebPage` from Task 7, and `AppSession` from Task 6.
- Produces, in `cart_repo.dart`:
  - `Future<int> addToCart(String productId, int qty)`. It calls the RPC and maps `sold_out` and `not_available` to `CartException(kind)`.
  - `Future<int> cartPieceCount()`, the sum of qty, which is 0 when signed out.
  - `final cartCount = ValueNotifier<int>(0)` and `Future<void> refreshCartCount()`.
- Produces, in `tab_shell.dart`:
  - `enum AppTab { home, shop, cart, orders, account }`
  - `class TabShell extends StatefulWidget`
  - `TabShellScope.of(context)`, an InheritedWidget, exposes:
    - `void switchTo(AppTab tab)`. For home, cart and orders it calls `navigate('/')`, `navigate('/cart')` or `navigate('/orders')`; for cart it also calls `reloadCart()`.
    - `void openShop(OpenShop filters)`
    - `Future<void> openProduct(String slug)`, which pushes the Product route (Task 11). Until Task 11 lands, push a placeholder.
    - `Future<bool> requireSignIn({String? returnTo})`, which pushes the sign-in route (Task 12) and resolves true when signed in. Until Task 12, it resolves `false`.
    - `void openWebPage(String path)`, which pushes `WebPageScreen` (Task 12).
- Layout and behaviour:
  - An `IndexedStack` holds `[webTab, ShopScreen placeholder, webTab, webTab, AccountScreen placeholder]`. Show the one `WebPage` in the stack slot for whichever web tab is active.
  - Bottom `NavigationBar` labels: Home, Shop, Cart, Orders, Account. The Cart icon gets a `Badge` bound to `cartCount`.
  - Back handling: pop native routes first, then step back in the WebView when a web tab is showing, then go to Home, then leave the app.
  - When the bridge receives `LoginRequest(returnTo)`: `requireSignIn()`, then `switchTo` the tab matching `returnTo` (`/cart` → cart, `/orders…` → orders, else home), then `navigate(returnTo)`.

- [ ] **Step 1: Write the widget test** `mobile/test/tab_shell_test.dart`, with a fake web slot injected through a `webTabBuilder` constructor parameter so no platform view is needed:
  - `tapping Shop shows the shop screen`.
  - `cart badge shows cartCount`: setting `cartCount.value = 3` shows a badge with `3`.

- [ ] **Step 2: Run the test and check it fails.** Run `flutter test test/tab_shell_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement the shell and cart repo.**

- [ ] **Step 4: Run tests and analyzer, then check on the simulator.** Run `flutter test && flutter analyze`. Then:
  1. `flutter run -d 7A7203B5-BC91-4D61-AA55-E6F79488CDB0 --dart-define-from-file=env.json`.
  2. Attach the simulator panel first.
  3. Confirm Home, Cart and Orders show the site with no web header or tab bar.
  4. Confirm tab switching works.
  5. Confirm that tapping a product on Home opens the placeholder.

- [ ] **Step 5: Commit** `mobile/lib`, `mobile/test` with the message `Add the native tab bar`.

---

### Task 9: Catalog data layer

**Files:**
- Create: `mobile/lib/data/models.dart`, `mobile/lib/data/catalog_repo.dart`, `mobile/lib/data/wishlist_repo.dart` and `mobile/lib/data/stand_in_images.dart`.
- Test: `mobile/test/models_test.dart`, with a JSON fixture in the shape of `catalog.ts`'s `productSelect` row.

**Interfaces:**
- Produces, in `models.dart`:
  - `Product.fromJson`, with fields `id, name, slug, description, materials, price (double), stock, artisan (ArtisanSummary), category (CategoryRef?), images (List<String> sorted by sort_order), double? rating, int reviewCount`.
  - Getter `String coverImage`: the first image, else `standInFor(category?.slug)`.
  - `ArtisanSummary(id, shopName, slug, photoUrl, story, craftSince, town (TownRef?))`
  - `TownRef(id, name)`, `CategoryRef(id?, name, slug)` and `Review(id, rating, comment, createdAt)`.
- Produces, in `catalog_repo.dart` (each mirrors the same-named function in `src/lib/catalog.ts`):
  - `class CatalogFilters { String? q; String? category; int? townId; double? minPrice; double? maxPrice; String? artisanId; SortKey sort; }`
  - `enum SortKey { newest, priceAsc, priceDesc }`
  - `Future<({List<Product> products, int total})> fetchProducts(CatalogFilters f, {int page = 0, int pageSize = 12})`
  - `Future<({List<TownRef> towns, List<CategoryRef> categories})> fetchFacets()`
  - `Future<Product?> fetchProduct(String slug)`
  - `Future<List<Review>> fetchReviews(String productId)`
  - `Future<List<ArtisanSummary>> fetchMakers()`
  - `Future<List<Product>> fetchRelated(Product p)`, the same category excluding `p`, limit 8.
  - `Future<List<Product>> fetchFromMaker(Product p)`, the same artisan excluding `p`, limit 8.
- Produces, in `wishlist_repo.dart`: `Future<Set<String>> savedIds()` and `Future<bool> toggleSaved(String productId)`.
- Produces, in `stand_in_images.dart`: `String standInFor(String? categorySlug)`, using the same Unsplash ids and fallback as `src/lib/images.ts`.

- [ ] **Step 1: Write the failing tests:**
  - `parses a catalog row`: from the fixture, check name, price as double, town name and verified shop name.
  - `images sort by sort_order`.
  - `product with no images uses the craft stand-in`: category `pottery` gives the pottery Unsplash URL.
  - `search text drops PostgREST syntax characters`: `cleanSearch('a,(b)*%')` is `'a  b'`, trimmed the same way as the web. Expose `cleanSearch` for this.

- [ ] **Step 2: Run the tests and check they fail.** Run `flutter test test/models_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement the models and repos.**

- [ ] **Step 4: Run the tests.** Run `flutter test`. Expected: pass.

- [ ] **Step 5: Commit** `mobile/lib/data`, `mobile/test/models_test.dart` with the message `Add catalog queries to the app`.

---

### Task 10: Native Shop screen

**Files:**
- Create: `mobile/lib/screens/shop/shop_screen.dart`, `mobile/lib/screens/shop/product_card.dart` and `mobile/lib/screens/shop/filter_sheet.dart`.
- Modify: `mobile/lib/shell/tab_shell.dart`, replacing the placeholder.

**Interfaces:**
- Consumes the Task 9 repos, plus `TabShellScope` (`openProduct`, `requireSignIn`, `switchTo`, `openWebPage`) and `addToCart`/`refreshCartCount` from Task 8.
- Produces:
  - `ShopScreen({OpenShop? initialFilters})`. The shell calls `applyFilters(OpenShop)` through a `GlobalKey<ShopScreenState>`.
  - `ProductCard(product, {required onTap, required onQuickAdd})`

Layout follows the web `ShopView.vue`, top to bottom:
1. A greeting.
2. A search field (16px text).
3. A craft rail (horizontal, with a stand-in photo per category).
4. Town chips.
5. A makers rail. Tapping a maker calls `switchTo(home)` then `navigate('/artisans/<slug>')`.
6. A results heading with the count and a "Filters" button that opens the price and sort sheet.
7. A 2-column grid that loads the next page within 400px of the end.

Pull to refresh reloads. Empty results show "No pieces match" with a "Clear filters" button.

Quick add:
1. If signed out, call `requireSignIn()` first.
2. Then `addToCart(id, 1)`.
3. If the returned quantity didn't grow, show the snackbar "You already have every available piece in your cart."
4. Otherwise show "Added <name>" with a "View cart" action that calls `switchTo(cart)`.
5. Then `refreshCartCount()`.
6. A `CartException('sold_out')` shows "This piece is sold out."

- [ ] **Step 1: Write the widget tests** `mobile/test/shop_screen_test.dart`, injecting a fake repo through a constructor parameter:
  - `shows products from the repo`.
  - `quick add when signed out asks to sign in first`: the fake `requireSignIn` is called before the fake `addToCart`.
  - `second add at stock limit shows the limit message`: the fake `addToCart` returns the same quantity twice, and the snackbar text matches.
  - `empty results show clear filters`.

- [ ] **Step 2: Run the tests and check they fail.** Run `flutter test test/shop_screen_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement the screen, card and sheet.**

- [ ] **Step 4: Run the tests and analyzer, then check on the simulator.** Run `flutter test && flutter analyze`. On the simulator: search, filter by craft and town, sort, scroll to load more, and confirm a Home craft link opens Shop already filtered.

- [ ] **Step 5: Commit** with the message `Add the native Shop screen`.

---

### Task 11: Native Product screen

**Files:**
- Create: `mobile/lib/screens/product/product_screen.dart`, plus widget files as needed under `screens/product/`.
- Modify: `tab_shell.dart`, so `openProduct` pushes this screen.

**Interfaces:**
- Consumes the Task 9 repos, the Task 8 cart functions, and `TabShellScope`.
- Produces `ProductScreen({required String slug})`.

Layout follows the web `ProductView.vue`, top to bottom:
1. A swipeable gallery with page dots, with back and heart buttons over it.
2. A sheet over the photo with the name, price, town chip, and rating summary (which taps to reviews).
3. A maker card. Tapping it calls `switchTo(home)` then `navigate('/artisans/<slug>')`, and pops the product screen.
4. Highlights.
5. A Details expansion showing the description and materials.
6. Reviews: the average, a 5-to-1 star breakdown and the list.
7. A "More from <shop>" rail and a "You may also like" rail. Tapping one pushes another `ProductScreen`.

A bottom buy bar has the quantity stepper (1 to remaining stock), a running total and "Add to cart". It uses the same sign-in, limit and snackbar rules as Task 10. Sold out disables the bar and shows "Sold out". A missing product shows "This piece isn't available" with a "Back to shop" button.

- [ ] **Step 1: Write the widget tests** `mobile/test/product_screen_test.dart`, with a fake repo:
  - `shows name, price and maker`.
  - `stepper stops at remaining stock`.
  - `sold out disables add to cart`.
  - `missing product shows not available`.
  - `heart when signed out asks to sign in`.

- [ ] **Step 2: Run the tests and check they fail.** Expected: FAIL.

- [ ] **Step 3: Implement the screen.**

- [ ] **Step 4: Run the tests and analyzer, then check on the simulator.** Run `flutter test && flutter analyze`. On the simulator:
  - Open a product from Shop, and from a Home card in the web view.
  - Swipe the gallery.
  - Add 2 to the cart; the badge goes up by 2.
  - The Cart tab shows the item.

- [ ] **Step 5: Commit** with the message `Add the native Product screen`.

---

### Task 12: Native Account, sign-in, and the pushed web page

**Files:**
- Create: `mobile/lib/screens/account/account_screen.dart`, `mobile/lib/screens/account/sign_in_screen.dart` and `mobile/lib/screens/web_page_screen.dart`.
- Modify: `tab_shell.dart`, so `requireSignIn` and `openWebPage` are real and the placeholder is replaced.

**Interfaces:**
- Consumes `AppSession` (Task 6), `createWebController`/`WebBridge`/`WebPage` (Task 7) and `TabShellScope`.
- Produces:
  - `SignInScreen`, which pops `true` on success. It has modes for sign in, create account and forgot password.
  - `AccountScreen`
  - `WebPageScreen({required String path})`. It's a full-screen route with a back button and its own controller plus `WebBridge`. Its `LoginRequest` uses the same `requireSignIn`, and it's disposed on pop.

Sign-in messages:
- Errors show inline, using Supabase's message.
- For a banned account: "This account has been suspended. Email hello@craftcebu.test if you think this is a mistake."
- When sign-up needs confirmation: "Check your email to confirm your account, then sign in."
- After a reset is sent: "We sent a reset link to <email>."

Account:
- **Signed out:** a "Sign in or create an account" card.
- **Signed in:** a name and email header, then these rows:
  - Saved pieces (`/wishlist`)
  - Edit profile (`/account`)
  - Sell on CraftCebu (`/sell`), shown when the role is neither `artisan` nor `owner`.
  - Seller Centre (`/seller`), shown when the role is `owner` or `artisanStatus == 'verified'`.
  - Admin Centre (`/admin`), owner only.
  - Shop by origin (`/origins`)
  - Meet the makers (`/artisans`)
  - Sign out
- Every row opens through `openWebPage`. Sign out calls `session.signOut()` and then `refreshCartCount()`.

- [ ] **Step 1: Write the widget tests** `mobile/test/account_screen_test.dart`, with a fake session:
  - `signed out shows sign-in card`.
  - `buyer sees Sell on CraftCebu but not Seller Centre`.
  - `verified artisan sees Seller Centre, not Sell`.
  - `owner sees Admin Centre`.
  - `sign-in shows the suspended message for a banned account`.

- [ ] **Step 2: Run the tests and check they fail.** Expected: FAIL.

- [ ] **Step 3: Implement the screens and wire them into the shell.**

- [ ] **Step 4: Run the tests and analyzer, then check on the simulator.** Run `flutter test && flutter analyze`. On the simulator:
  1. While signed out, open the Orders tab; native sign-in appears.
  2. Sign in with an existing test account. Ask the user to type their own credentials if no test account is known; never enter them for the user.
  3. You land back on Orders, signed in.
  4. Account rows open the right web pages.
  5. Sign out; the web tabs show signed out.

- [ ] **Step 5: Commit** with the message `Add native sign-in and Account`.

---

### Task 13: End-to-end check and docs

**Files:**
- Modify: `README.md`, the "Mobile app" section. Cover how to make `env.json` from the example, and the run command with `--dart-define-from-file=env.json`. Note that the native screens need the cart migration.

- [ ] **Step 1: Run every automated check.** Run `npm --prefix supabase/tests test && node --test tests/web/ && npm run build && (cd mobile && flutter test && flutter analyze)`. Expected: all pass, no analyzer issues.

- [ ] **Step 2: Run the spec §5 flow on the simulator, step by step:**
  1. Browse Shop as a guest.
  2. Tap add and sign in; the item is added.
  3. The Cart tab shows it, and the badge matches.
  4. Check out with the Maya sandbox in the web view.
  5. The order appears under Orders.
  6. Sign out in Account; the web tabs are signed out.
- [ ] **Step 3: Check the token refresh.** Temporarily set `TOKEN_MARGIN_SECONDS` to `3590` locally only (don't commit it). Use the web tabs against `HOME_URL=http://localhost:5173`. Confirm `needToken` round-trips, and that the network log shows no `grant_type=refresh_token` request from the WebView. Revert the change.
- [ ] **Step 4: Commit the README** with the message `Document running the native app`.
- [ ] **Step 5: Ask the user** for a go-ahead to `git push origin main`.
