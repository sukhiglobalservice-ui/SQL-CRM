-- =====================================================================
-- Sukhi Global CRM — Storage buckets
-- Run this AFTER 01_schema.sql and 02_rls_policies.sql.
--
-- Two buckets replace the old base64-in-JSON file storage:
--   candidate-documents  → CVs and other candidate documents
--   deal-agreements      → signed agreements for Deals and Contracts
--
-- Both are created as PUBLIC buckets so uploaded files can be opened /
-- downloaded directly via their public URL from the app (matching the
-- old behaviour, where clicking a file just opened it). If you'd rather
-- files be private and only downloadable through signed URLs, see the
-- commented alternative at the bottom.
-- =====================================================================

insert into storage.buckets (id, name, public)
values ('candidate-documents', 'candidate-documents', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('deal-agreements', 'deal-agreements', true)
on conflict (id) do nothing;

-- Policies: same anon-friendly access model as the database tables above,
-- for the same reason (no login screen in the current UI). See the
-- security note in 02_rls_policies.sql — the same caveat applies here.

create policy "candidate_documents_select"
  on storage.objects for select to anon, authenticated
  using (bucket_id = 'candidate-documents');

create policy "candidate_documents_insert"
  on storage.objects for insert to anon, authenticated
  with check (bucket_id = 'candidate-documents');

create policy "candidate_documents_update"
  on storage.objects for update to anon, authenticated
  using (bucket_id = 'candidate-documents')
  with check (bucket_id = 'candidate-documents');

create policy "candidate_documents_delete"
  on storage.objects for delete to anon, authenticated
  using (bucket_id = 'candidate-documents');

create policy "deal_agreements_select"
  on storage.objects for select to anon, authenticated
  using (bucket_id = 'deal-agreements');

create policy "deal_agreements_insert"
  on storage.objects for insert to anon, authenticated
  with check (bucket_id = 'deal-agreements');

create policy "deal_agreements_update"
  on storage.objects for update to anon, authenticated
  using (bucket_id = 'deal-agreements')
  with check (bucket_id = 'deal-agreements');

create policy "deal_agreements_delete"
  on storage.objects for delete to anon, authenticated
  using (bucket_id = 'deal-agreements');

-- =====================================================================
-- OPTIONAL, FOR LATER — private buckets instead of public:
--
--   update storage.buckets set public = false where id in
--     ('candidate-documents', 'deal-agreements');
--
-- Then in the JS, replace getPublicUrl(...) calls with:
--   await supabase.storage.from(bucket).createSignedUrl(path, 3600)
-- which returns a URL that expires after the given number of seconds
-- (3600 = 1 hour) instead of being permanently public.
-- =====================================================================
