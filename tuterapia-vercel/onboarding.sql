-- Seguimiento del recorrido guiado (onboarding) del asistente de psicólogos.
-- Una fila por conversación de recorrido. La escribe solo la función
-- onboarding_registrar (SECURITY DEFINER), igual que chat_registrar: el rol
-- anon puede registrar pero no leer nada.

create table if not exists public.onboarding_recorrido (
  id              bigint generated always as identity primary key,
  conversacion_id text not null unique,
  nombre          text,
  mail            text,
  pais            text,
  paso_max        integer not null default 0,
  completo        boolean not null default false,
  iniciado_en     timestamptz not null default now(),
  actualizado_en  timestamptz not null default now(),
  completado_en   timestamptz
);

comment on table public.onboarding_recorrido is
  'Recorrido guiado del asistente de psicólogos: quién lo arrancó (nombre y mail que ponen en el chat), hasta qué paso llegó y si lo terminó. Una fila por conversación.';

alter table public.onboarding_recorrido enable row level security;
revoke all on public.onboarding_recorrido from anon, authenticated;

create or replace function public.onboarding_registrar(
  p_conversacion_id text,
  p_nombre text,
  p_mail text,
  p_pais text,
  p_paso integer,
  p_completo boolean
) returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
begin
  insert into public.onboarding_recorrido as o
    (conversacion_id, nombre, mail, pais, paso_max, completo, completado_en)
  values (
    left(p_conversacion_id, 64),
    left(p_nombre, 120),
    lower(left(p_mail, 200)),
    left(p_pais, 20),
    least(greatest(coalesce(p_paso, 0), 0), 9),
    coalesce(p_completo, false),
    case when coalesce(p_completo, false) then now() end
  )
  on conflict (conversacion_id) do update set
    nombre         = coalesce(excluded.nombre, o.nombre),
    mail           = coalesce(excluded.mail, o.mail),
    pais           = coalesce(excluded.pais, o.pais),
    paso_max       = greatest(o.paso_max, excluded.paso_max),
    completo       = o.completo or excluded.completo,
    completado_en  = coalesce(o.completado_en, excluded.completado_en),
    actualizado_en = now();
end;
$$;

revoke all on function public.onboarding_registrar(text, text, text, text, integer, boolean) from public;
grant execute on function public.onboarding_registrar(text, text, text, text, integer, boolean) to anon, authenticated, service_role;

-- Vista para el equipo: una fila por persona (mail), con lo más lejos que llegó.
create or replace view public.onboarding_por_persona
with (security_invoker = true) as
select
  mail,
  (array_agg(nombre order by actualizado_en desc))[1] as nombre,
  (array_agg(pais   order by actualizado_en desc))[1] as pais,
  max(paso_max)                                       as paso_max,
  bool_or(completo)                                   as completo,
  min(iniciado_en  at time zone 'America/Montevideo') as arranco,
  max(actualizado_en at time zone 'America/Montevideo') as ultima_actividad,
  count(*)                                            as sesiones
from public.onboarding_recorrido
group by mail;

revoke all on public.onboarding_por_persona from anon, authenticated;
