-- 在 Supabase 的 SQL Editor 里整段粘贴运行一次即可。
create table if not exists public.books (
  id text primary key,
  title text not null,
  author text,
  descr text,
  cover text,
  chapters jsonb not null,
  chapter_count int not null default 0,
  created_at bigint,
  updated_at timestamptz not null default now()
);

alter table public.books enable row level security;

-- 所有人(不用登录)都能看书库
drop policy if exists "public read" on public.books;
create policy "public read" on public.books for select using (true);

-- 只有登录的管理员能上传、修改、删除
drop policy if exists "admin write" on public.books;
create policy "admin write" on public.books for all to authenticated using (true) with check (true);
