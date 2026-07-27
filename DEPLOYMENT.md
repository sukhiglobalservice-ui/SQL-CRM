# Sukhi Global CRM — Supabase Deployment Guide

This guide walks through turning the file(s) in this delivery into a live,
Supabase-backed CRM. Nothing about the UI changed — every form, button,
table, tab, and chart looks and behaves exactly as before. What changed is
*where the data lives*: instead of the browser's local storage, it now
lives in your Supabase project, in real Postgres tables.

## What's included

| File                      | Purpose                                              |
|---------------------------|-------------------------------------------------------|
| `01_schema.sql`           | All tables, indexes, and `updated_at` triggers        |
| `02_rls_policies.sql`     | Original RLS policies (public anon key — no login)    |
| `03_storage_buckets.sql`  | Storage buckets for uploaded CVs and agreements       |
| `04_auth_rls_update.sql`  | **Run this instead of/after 02** — now that the app has a real login, this locks every table and bucket to signed-in users only |
| `docket.html`             | The complete, updated app, now with email/password login |

## Step 1 — Run the SQL, in order

1. Open your Supabase project → **SQL Editor**.
2. Paste the full contents of `01_schema.sql` → **Run**.
3. Paste the full contents of `02_rls_policies.sql` → **Run**.
4. Paste the full contents of `03_storage_buckets.sql` → **Run**.
5. Paste the full contents of `04_auth_rls_update.sql` → **Run**.
   This drops the public-anon-key policies from step 3 and replaces them
   with authenticated-only versions, since the app now has a real login
   screen — see "About security" below for why this matters.

After this, check **Table Editor** — you should see 7 tables: `companies`,
`meetings`, `deals`, `deal_files`, `candidates`, `candidate_files`,
`interviews`. Check **Storage** — you should see 2 buckets:
`candidate-documents` and `deal-agreements`.

## Step 1b — Create user accounts

There's no public sign-up form in the app — that's intentional, so only
people you've explicitly approved can get in. Create each person's login:

1. Supabase Dashboard → **Authentication → Users → Add user**.
2. Enter their email and a password (or choose "send invite" to let them
   set their own password by email).
3. That's it — they can sign in through the app immediately with those
   credentials.

To remove someone's access later, delete their user in that same screen.

## Step 2 — Add your Publishable (anon) key

1. In Supabase, go to **Project Settings → API**.
2. Copy the key labeled **anon / public** (this is what you called the
   "Publishable Key").
3. Open `docket.html` in a text editor and find this line near the top of
   the `<script>` block:

   ```js
   const SUPABASE_ANON_KEY = 'YOUR_PUBLISHABLE_KEY_HERE';
   ```

4. Replace `YOUR_PUBLISHABLE_KEY_HERE` with your actual key, keeping the
   quotes:

   ```js
   const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
   ```

5. Save the file.

The project URL is already filled in for you
(`https://nycslfearepksdujknyf.supabase.co`).

## Step 3 — Open the app

Double-click `docket.html`, or host it anywhere (see "Hosting options"
below). You'll now see a **sign-in screen** first — enter the email and
password you created in Step 1b. Once signed in:

- Your email address shows in the sidebar, with a **Logout** button next
  to it.
- The app loads whatever's in your tables — since they're empty right
  now, every tab will simply show its empty state ("Nothing here yet —
  Use '+ Add' to log the first entry"). That's expected; there's no
  demo/seed data anymore, since seeding a real production database
  automatically isn't appropriate.
- **Refresh the page** — you'll stay signed in. Supabase keeps your
  session in the browser and silently renews it, so you don't have to
  log in again every time you reload (this is what "session persistence"
  and "auto-login after refresh" mean in practice).
- Click **Logout** — you're immediately returned to the sign-in screen,
  and the CRM data disappears from view until you sign in again.

Try adding a company, then a candidate, then check **Table Editor** in
Supabase — you should see the row appear there immediately.

## About security — now much better, one thing still to know

**This has changed from the previous delivery.** The app now has a real
email/password login screen (Supabase Auth), and — as long as you ran
`04_auth_rls_update.sql` — every table and Storage bucket requires a
valid signed-in session. The public anon key alone can no longer read or
write anything; RLS rejects it. This is the real access control that was
flagged as missing before.

**What this means in practice:**
- Only people you've created an account for (Step 1b) can see or change
  any data.
- Anyone else hitting the page just sees the login screen — no data
  loads, no buttons do anything, until they sign in.

**The one thing still worth knowing:** anyone with a valid account has
full access to *everything* — every company, candidate, and interview,
not just their own. There's no per-user or per-role restriction (e.g. "a
recruiter can only see their own candidates"). If that kind of separation
matters to you, it's a further step from here — each table would need a
`created_by` column and a tighter policy checking `auth.uid()` — happy to
build that if you need it.

## Where things are, technically

- **Companies, Meetings, Deals and Contracts, Candidates, Interviews** —
  each has its own Postgres table, listed above.
- **Deadlines** — still has no table. It's computed live in the browser
  from Meetings + still-scheduled Interviews, exactly as before.
- **Reports** — still computed live in the browser from the other tables.
- **Uploaded files** (candidate CVs, deal agreements) — the actual file
  bytes go into Supabase Storage (`candidate-documents` /
  `deal-agreements` buckets); only the filename, size, type, and storage
  path are kept in the `candidate_files` / `deal_files` tables.
- **Google Drive Client ID and GitHub backup settings** (repo, branch,
  path, token) are the one thing that intentionally **stays in the
  browser's localStorage**, not Supabase. These are per-device integration
  credentials, not CRM business data — and storing a GitHub Personal
  Access Token in a database governed by a public anon-key policy would
  let any visitor read it. If you'd like these centralized too, that's
  possible but needs its own, more restrictive policy (e.g. tied to a
  signed-in user), which again implies adding login.

## Every button, mapped to what it now does

| Action                                  | What happens                                                        |
|------------------------------------------|----------------------------------------------------------------------|
| Page load (no session)                    | Shows the sign-in screen; nothing is fetched until you sign in       |
| Sign in                                   | `supabase.auth.signInWithPassword(...)`, then fetches all tables      |
| Refresh the page (already signed in)      | Session is restored automatically from the browser — no re-login     |
| Logout                                    | `supabase.auth.signOut()`, returns to the sign-in screen              |
| Add / Edit (any modal) → Save             | `insert` or `update` on the relevant table, then reloads all data    |
| Delete (any record)                       | `delete` on the relevant table (cascades handle related rows), reload|
| Upload a file                             | Uploaded to Storage on Save; a metadata row is inserted linking it   |
| Remove a file                             | Deleted from Storage **and** its metadata row, immediately           |
| CSV Import (Candidates tab)               | Bulk `insert` into the relevant table(s)                              |
| Export CSV / Export .ics / Export JSON    | Reads from the already-loaded in-memory data — no extra database call|
| Restore backup (JSON)                     | **Wipes every table** and re-inserts from the file, remapping IDs     |
| Push Backup to GitHub                     | Unchanged — still reads the in-memory data, unrelated to Supabase    |

## Hosting options

- **Keep it as a local file** — works fine; every visitor's browser talks
  directly to Supabase over HTTPS, no server required.
- **Any static host** (Netlify, Vercel, GitHub Pages, S3, etc.) — just
  upload `docket.html`. No build step, no server code needed.
- If you later add Google Drive or Calendar integration and want *those*
  to work too, you'll need a fixed hosted URL anyway (see the in-app
  "Why?" notes on those features) — so hosting this on a real domain is a
  reasonable next step regardless.

## Troubleshooting

- **"Could not load data from Supabase"** on open → almost always the
  Publishable Key wasn't pasted in, or the SQL files weren't run yet.
  Open the browser console (F12) for the exact error.
- **Everything loads but Save fails** → check that RLS policies were
  actually applied (Step 1.3) — without them, Supabase blocks all access
  by default even with a valid key.
- **File uploads fail** → confirm the two Storage buckets exist (Step 1
  final check) and that `03_storage_buckets.sql` ran without errors.
- **A cascading delete didn't remove what you expected** → this is
  intentional and matches the original app's behavior: deleting a company
  removes its meetings, deals, candidates, and interviews too. There's no
  "soft delete" — it's permanent, same as before.
