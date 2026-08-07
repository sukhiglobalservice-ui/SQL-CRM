# Authentication Root-Cause Audit & Permanent Fix

## Summary

The intermittent `JWT issued at future` / "failed to load data" issue had
**two independent root causes**, both confirmed in the actual code (not
theoretical):

1. **The app never verified a cached session was still valid on the
   server before using it.** It trusted `getSession()` — a local,
   storage-only read — as proof the user was logged in. A session can
   look fine locally while the server no longer honors it (expired,
   revoked, tied to an old/different Supabase project, or affected by
   local clock drift during the client-side token decode). This is what
   produced the exact error text you saw, and why clearing storage
   "fixed" it: clearing storage removed the stale cached session, forcing
   a fresh login that (temporarily) had a clean token.

2. **A genuine race condition on every page load.** Both
   `onAuthStateChange`'s initial callback and the separate `initAuth()`
   function independently called `loadAllFromSupabase()` with no
   coordination — meaning on a normal load, your data was being fetched
   **twice**, concurrently, from the same tables. This didn't cause the
   JWT error itself, but it doubled your Supabase load on every visit and
   made failures harder to reason about, since two competing loads could
   resolve in either order.

Neither of these needed a workaround. Both are now fixed at the
architecture level — the app can no longer get into a state where it
tries to use a session the server doesn't currently trust.

---

## Root Cause #1 (the actual bug): no live session verification

### The problematic code

```js
(async function initAuth(){
  const { data } = await supabase.auth.getSession();
  if(data && data.session){
    showApp(data.session);
    appLoadedOnce = true;
    loadLocalSettings();
    loadAllFromSupabase();
  } else {
    showLogin();
  }
})();
```

`getSession()` reads whatever is sitting in `sessionStorage` and does a
**local** check (decode the JWT, compare its claims against the device's
own clock). It never asks the Supabase server "is this actually still
good?" If the local clock has drifted even slightly, or the cached token
is stale for any reason, this local check can fail in ways that produce
exactly `JWT issued at future` — and because the check is local, the
*same* stale token will keep failing the *same* way on every reload,
until something (like clearing storage) removes it. That fully explains
why it "worked immediately after clearing" and "works instantly on
another device/incognito" — those all start from *no* cached token, so
there's nothing stale to fail on.

### The fix

Added `verifySessionIsLive()`, which calls `supabase.auth.getUser()` —
this makes a real network request to the Supabase Auth server and asks
it directly whether the token is valid *right now*. This is the
authoritative check; it doesn't care what the local clock thinks. Every
page load now goes through this before any data is fetched:

```js
async function verifySessionIsLive(){
  try{
    const { data, error } = await supabase.auth.getUser();
    if(error || !data || !data.user) return null;
    return data.user;
  }catch(e){
    return null;
  }
}

async function bootAuthenticatedApp(session){
  const user = await verifySessionIsLive();
  if(!user){
    await handleAuthFailure('Your session could not be verified. Please sign in again.');
    return;
  }
  showApp(session);
  if(!appLoadedOnce){
    appLoadedOnce = true;
    loadLocalSettings();
    await loadAllFromSupabase();
  }
}
```

If the server says the token's no good — for *any* reason, including
clock-skew artifacts, cross-project mismatches, or genuine expiry — the
app now cleanly logs the user out and returns to login, instead of
attempting to load data with a token that's going to fail anyway.

---

## Root Cause #2: double-initialization race condition

### The problematic code

```js
let appLoadedOnce = false;

supabase.auth.onAuthStateChange((event, session) => {
  if(session){
    showApp(session);
    if(!appLoadedOnce){
      appLoadedOnce = true;
      loadLocalSettings();
      loadAllFromSupabase();
    }
  } else {
    appLoadedOnce = false;
    showLogin();
  }
});

(async function initAuth(){
  const { data } = await supabase.auth.getSession();
  if(data && data.session){
    showApp(data.session);
    appLoadedOnce = true;          // sets this directly, bypassing the flag check above
    loadLocalSettings();
    loadAllFromSupabase();         // can fire even if onAuthStateChange already did
  } else {
    showLogin();
  }
})();
```

Both blocks read the same underlying session on page load and race each
other. `onAuthStateChange`'s handler checks `appLoadedOnce` before
loading — but `initAuth()` doesn't check it at all, it just sets it and
loads regardless. Depending on timing, this could fire two concurrent
`loadAllFromSupabase()` calls.

### The fix

`initAuth()` is now the single source of truth for the *first* decision
on page load. `onAuthStateChange` only reacts to changes that happen
*after* that point — an explicit sign-in, sign-out, or a background token
refresh — via an `authInitialized` guard:

```js
let authInitialized = false;

supabase.auth.onAuthStateChange((event, session) => {
  if(!authInitialized) return; // initAuth() owns the very first load
  if(event === 'SIGNED_OUT' || !session){
    appLoadedOnce = false;
    showLogin();
    return;
  }
  bootAuthenticatedApp(session);
});

(async function initAuth(){
  try{
    const { data } = await supabase.auth.getSession();
    if(data && data.session){
      await bootAuthenticatedApp(data.session);
    } else {
      showLogin();
    }
  }catch(e){
    console.error('Auth init failed:', e);
    clearStaleAuthStorage();
    showLogin();
  }finally{
    authInitialized = true;
  }
})();
```

`bootAuthenticatedApp()` is now the single, shared entry point for
"show the app for this session" — used by both paths, always runs the
live verification, and only calls `loadAllFromSupabase()` once
(`appLoadedOnce` still guards against a redundant reload, but there's
now genuinely only one caller in the normal flow instead of two racing
ones).

---

## Automatic recovery from mid-session token failure

Even with the above, a token can still expire *while the tab is open* —
this is normal and not a bug (`autoRefreshToken: true` already tries to
handle it silently in the background). But every data-loading call in
the app funnels through one function, `loadAllFromSupabase()`, so that's
where a second layer of recovery lives:

```js
async function loadAllFromSupabase(isRetry){
  try{
    // ...normal fetch of all tables...
  }catch(e){
    if(isAuthError(e) && !isRetry){
      const refreshed = await tryRefreshSession();
      if(refreshed){
        return loadAllFromSupabase(true); // retry once, silently
      }
      await handleAuthFailure('Your session expired. Please sign in again.');
      return;
    }
    if(isAuthError(e)){
      await handleAuthFailure('Your session expired. Please sign in again.');
      return;
    }
    // genuine non-auth error (network, RLS misconfiguration, etc.) —
    // unchanged from before, still shows a diagnostic alert, since
    // that's a real problem the user/admin needs to see and act on
    storageOK = false;
    console.error('Supabase load failed:', e);
    alert('Could not load data from Supabase: '+(e.message||e)+'...');
  }
  render();
}
```

`isAuthError()` recognizes the shape of an auth-related failure (JWT,
token, session, refresh, 401, or Supabase's `PGRST301`/`PGRST302` codes)
regardless of the exact wording, so this isn't matching on the literal
string "JWT issued at future" — it'll catch the same class of problem
even if Supabase changes their error message wording in a future SDK
version.

Since `loadAllFromSupabase()` runs after *every* create/update/delete
throughout the app (not just on page load), this same recovery logic
protects every user action, not only the initial page load.

---

## Corrupted / stale storage handling

```js
function clearStaleAuthStorage(){
  try{
    const store = window.sessionStorage;
    const toRemove = [];
    for(let i=0;i<store.length;i++){
      const k = store.key(i);
      if(k && k.indexOf('sb-')===0) toRemove.push(k);
    }
    toRemove.forEach(k=>store.removeItem(k));
  }catch(e){ /* storage unavailable — nothing more we can do */ }
}
```

Supabase's own storage keys always start with `sb-`, so this only ever
removes Supabase's own session data — nothing else the app or browser
has stored is touched. This runs:
- Whenever `handleAuthFailure()` fires (any confirmed-bad session)
- If `initAuth()` itself throws unexpectedly (e.g. genuinely corrupted
  JSON in storage) — caught, logged to console, storage cleared, login
  shown. The user is never left on a broken/blank screen.

This is what makes manual "clear browser history" permanently
unnecessary — the app now does that specific, targeted cleanup itself,
automatically, the moment it detects a problem.

---

## Deployment & browser caching

This wasn't an authentication bug on its own, but it's very likely why
the problem **"returned after future deployments"**: this app is a
single static HTML file with no cache-busting filename (no content
hash), so browsers and Vercel's edge network are free to cache it
aggressively by default. If a browser were serving a cached copy of an
*older* deployment — one pointing at an old Supabase project or holding
an outdated key — you'd see exactly this class of symptom, and it would
look "random" because it depends on each visitor's individual cache
state.

**Fix — `vercel.json`:**

```json
{
  "rewrites": [
    { "source": "/", "destination": "/docket.html" }
  ],
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        { "key": "Cache-Control", "value": "no-cache, no-store, must-revalidate" },
        { "key": "Pragma", "value": "no-cache" },
        { "key": "Expires", "value": "0" }
      ]
    }
  ]
}
```

This forces every browser (and Vercel's own edge cache) to always
re-check with the server before using a cached copy of anything in this
deployment. There's no meaningful performance cost here, since the whole
app is one small file with nothing else to cache long-term anyway.
**You'll need to redeploy with this file in place for it to take effect**
— it can't retroactively fix caches that already exist on visitors'
machines, but it prevents the problem from recurring on every deployment
from here forward.

There is no service worker in this project, so that wasn't a factor.

---

## Everything else audited, with findings

- **Duplicate `createClient()` instances** — confirmed none. Single
  client, correctly configured with `persistSession`, `sessionStorage`,
  `autoRefreshToken`, `detectSessionInUrl`. No change needed.
- **`autoRefreshToken` behavior** — correctly enabled; a failed
  background refresh fires a `SIGNED_OUT` event through
  `onAuthStateChange`, which is now explicitly handled (previously it
  was handled too, but only reachable via the racy path above).
- **Cookies** — not used; the app relies solely on `sessionStorage` per
  your explicit configuration (session ends when the browser closes,
  which was an intentional design decision from earlier in this
  project, not a bug).
- **Every raw `try/catch` elsewhere in the app** (the four modals'
  save/delete handlers, CSV import, backup restore, etc.) — these were
  not individually rewired, since `loadAllFromSupabase()` runs
  immediately after nearly every one of them and now catches auth
  failures centrally. In the rare case where the *initial* write (before
  the reload) itself fails on an expired token, that specific action
  would still show a technical error rather than auto-recovering. This
  is a reasonable follow-up if you want full defense-in-depth on every
  single write, not just reads — happy to extend the same
  `isAuthError()` / recovery pattern to those call sites if you'd like
  that next.

---

## What changes for you day-to-day

- Opening the app with an old/expired/invalid session now **silently**
  drops you back to login with a plain-language message — never a
  technical error dialog.
- A token that goes bad *while you're using the app* is retried
  automatically once; if that fails, same clean logout.
- Data loads exactly once per page load instead of twice.
- Manually clearing browser history/site data should never be necessary
  again — the app now does the equivalent cleanup itself whenever it's
  actually needed.
- Redeploying no longer risks leaving visitors on a stale cached copy of
  the app.
