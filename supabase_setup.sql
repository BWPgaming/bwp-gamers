-- BWP GAMING database setup for Supabase
-- Run this entire file in Supabase Dashboard > SQL Editor > New query.
create extension if not exists pgcrypto;

create table if not exists public.owner_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.site_content (
  id uuid primary key default gen_random_uuid(),
  category text not null check (category in ('free_sensi','premium_sensi','tip')),
  title text not null,
  description text not null default '',
  image_url text,
  image_path text,
  published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.owner_users enable row level security;
alter table public.site_content enable row level security;

create or replace function public.is_bwp_owner()
returns boolean language sql stable security definer
set search_path = public
as $$
  select exists (select 1 from public.owner_users where user_id = auth.uid());
$$;

drop policy if exists "Owners can read owner list" on public.owner_users;
create policy "Owners can read owner list" on public.owner_users
for select to authenticated using (public.is_bwp_owner());

drop policy if exists "Public can read published content" on public.site_content;
create policy "Public can read published content" on public.site_content
for select to anon, authenticated using (published = true or public.is_bwp_owner());

drop policy if exists "Owners can insert content" on public.site_content;
create policy "Owners can insert content" on public.site_content
for insert to authenticated with check (public.is_bwp_owner());

drop policy if exists "Owners can update content" on public.site_content;
create policy "Owners can update content" on public.site_content
for update to authenticated using (public.is_bwp_owner()) with check (public.is_bwp_owner());

drop policy if exists "Owners can delete content" on public.site_content;
create policy "Owners can delete content" on public.site_content
for delete to authenticated using (public.is_bwp_owner());

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('site-images','site-images',true,5242880,array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do update set public=true, file_size_limit=5242880,
allowed_mime_types=array['image/jpeg','image/png','image/webp','image/gif'];

drop policy if exists "Public can view BWP images" on storage.objects;
create policy "Public can view BWP images" on storage.objects
for select to anon, authenticated using (bucket_id = 'site-images');

drop policy if exists "BWP owners can upload images" on storage.objects;
create policy "BWP owners can upload images" on storage.objects
for insert to authenticated with check (bucket_id = 'site-images' and public.is_bwp_owner());

drop policy if exists "BWP owners can update images" on storage.objects;
create policy "BWP owners can update images" on storage.objects
for update to authenticated using (bucket_id = 'site-images' and public.is_bwp_owner())
with check (bucket_id = 'site-images' and public.is_bwp_owner());

drop policy if exists "BWP owners can delete images" on storage.objects;
create policy "BWP owners can delete images" on storage.objects
for delete to authenticated using (bucket_id = 'site-images' and public.is_bwp_owner());

-- IMPORTANT: After creating your owner user in Authentication > Users,
-- copy that user's UUID and run this separately:
-- insert into public.owner_users (user_id) values ('PASTE-OWNER-USER-UUID-HERE');
