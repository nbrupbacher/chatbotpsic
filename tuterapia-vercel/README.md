# Asistente para Psicólogos · Tu Terapia

Asistente virtual 24/7 para la comunidad de profesionales de Tu Terapia.

## 📁 Estructura del proyecto

```
tuterapia-vercel/
├── api/
│   └── chat.js          ← Endpoint serverless que llama a Claude
├── public/
│   └── index.html       ← Frontend (login + chat)
├── vercel.json          ← Configuración de Vercel
├── package.json
└── README.md
```

## 🚀 Plan de deploy paso a paso

### 1. Conseguir la API key de Anthropic

1. Entrar a [console.anthropic.com](https://console.anthropic.com)
2. Iniciar sesión / crear cuenta
3. Ir a **API Keys** → **Create Key**
4. Copiar la key (se ve solo una vez, guardarla bien)

### 2. Configurar el límite de gasto

**Importante para evitar sorpresas con 500 profesionales:**

1. En console.anthropic.com → **Billing** → **Usage limits**
2. Poner un límite mensual (recomendado: **$30 USD** para arrancar)
3. Activar alerta por mail al 80% del límite

### 3. Subir el código a GitHub

1. Crear un nuevo repositorio en GitHub (puede ser privado)
2. Subir los archivos de esta carpeta al repositorio
3. Estructura debe respetar la mostrada arriba

### 4. Conectar con Vercel

1. Entrar a [vercel.com](https://vercel.com)
2. **Add New** → **Project**
3. Importar el repositorio de GitHub
4. **Antes de hacer deploy:** ir a **Environment Variables** y agregar:
   - **Key:** `ANTHROPIC_API_KEY` → **Value:** la API key del paso 1
   - **Key:** `SUPABASE_URL` → **Value:** `https://bnseowqysefrnzcjdqiq.supabase.co`
   - **Key:** `SUPABASE_KEY` → **Value:** la key publicable del proyecto Supabase
   - Aplicar a: Production, Preview, Development

   Las dos de Supabase son opcionales: si no están, el chat funciona igual y
   simplemente no se registran las conversaciones.
5. Click en **Deploy**

### 5. Probar el deploy

1. Vercel te da una URL tipo `https://asistente-tuterapia.vercel.app`
2. Abrir esa URL
3. Login con las credenciales:
   - **Equipo psicólogos:** `equipotuterapia` / `tute2026`
   - **Admin:** `admin` / `tuterapia2026`
4. Probar enviando una pregunta

### 6. Compartir con el equipo

Una vez que esté funcionando, compartir la URL + credenciales en los grupos de WhatsApp del equipo.

## 🔧 Mantenimiento

### Actualizar credenciales

Editar `public/index.html`, buscar la constante `CREDENTIALS` (cerca del inicio del script):

```javascript
const CREDENTIALS = [
  { user: 'equipotuterapia', pass: 'tute2026' },
  { user: 'admin', pass: 'tuterapia2026' }
];
```

Hacer push a GitHub y Vercel deployea automáticamente.

### Actualizar la base de conocimiento

Editar `api/chat.js`, buscar la variable `systemPrompt` y actualizar la información ahí.

### Consultar las conversaciones

Las consultas quedan registradas en la tabla `chat_conversaciones` del proyecto
Supabase `tuterapia-rrhh`. Para leerlas hay dos vistas que dejan todo con
numeración correlativa y hora local (la tabla cruda guarda UUIDs y UTC):

```sql
-- Para exportar a CSV: una fila por turno, charlas en orden y seguidas.
select * from chat_conversaciones_legible;

-- Para leer: una fila por conversación, con el diálogo entero en un campo.
select * from chat_transcripciones order by conversacion desc;

-- Una conversación puntual
select conversacion_completa from chat_transcripciones where conversacion = 12;

-- Lo más preguntado del último mes
select pregunta, count(*)
from chat_conversaciones
where creado_en > now() - interval '30 days'
group by pregunta
order by count(*) desc
limit 50;
```

Las vistas están revocadas para `anon` y `authenticated`: se consultan desde el
SQL Editor, que corre como `postgres`.

**Cómo se agrupan:** el frontend genera un UUID por conversación y lo manda en
cada request. Si no llega (pestaña vieja abierta), el backend cae a hashear
usuario + primer mensaje, que agrupa bien salvo que la misma persona abra dos
charlas con idéntico texto inicial.

**Cómo escribe:** el backend no inserta contra la tabla, sino que llama a la
función `chat_registrar` (SECURITY DEFINER). Así el rol `anon` solo puede
registrar: no puede leer los logs ni ninguna otra tabla del proyecto. Un insert
directo además falla, porque PostgREST usa `RETURNING` para contar filas y eso
obliga a evaluar la policy de SELECT, que a propósito no existe.

**Qué NO se guarda:** las imágenes. Las capturas suelen tener datos de pacientes
y pesan de más, así que solo queda el flag `tuvo_imagen` y el texto que las
acompañaba.

**Retención:** hoy no hay borrado automático. Conviene definir un plazo (por
ejemplo 90 días) y programar la limpieza.

### Recorrido guiado (onboarding)

**Cómo funciona:** en la bienvenida hay un botón "Soy nuevo/a: empezar
recorrido" que pide nombre, mail y país en un formulario del frontend. El primer
mensaje al modelo empieza con `[Recorrido]` e incluye nombre y país (el mail NO
va al modelo). En cada request el frontend manda `onboarding: {nombre, mail,
pais}` y el backend lo registra en Supabase.

**Marcas técnicas:** el system prompt le pide al modelo que empiece cada paso
con `[[PASO:N]]` y el cierre con `[[RECORRIDO:FIN]]`. El frontend las oculta y
las usa para la barra de progreso, los botones "Listo, siguiente paso" y el
confeti. `[[BOTON_RECORRIDO]]` muestra el botón de arranque cuando alguien
escribe "soy nueva" a mano.

**Retomar:** el paso alcanzado se guarda en `localStorage` (`tt_recorrido_v1`),
así que funciona en el mismo navegador/dispositivo.

**Link directo:** `https://chatbotpsic.vercel.app/?recorrido` abre el formulario
apenas la persona inicia sesión. Es el link para mandar en la bienvenida.

**Videos:** para mostrar un video dentro del chat en un paso, agregar en ese
paso del system prompt una línea `[[VIDEO:<link>]]` (YouTube, Loom o archivo de
Drive). El modelo la copia y el frontend la convierte en reproductor.

**Quién lo hizo:** tabla `onboarding_recorrido` (una fila por conversación),
escrita solo por la función `onboarding_registrar` (SECURITY DEFINER, igual que
`chat_registrar`). Para leer, desde el SQL Editor:

```sql
-- Una fila por persona, con lo más lejos que llegó
select * from onboarding_por_persona order by ultima_actividad desc;

-- Quiénes arrancaron y no terminaron (para hacerles seguimiento)
select nombre, mail, pais, paso_max, ultima_actividad
from onboarding_por_persona
where not completo
order by ultima_actividad desc;
```

### Recordarme en este dispositivo (opcional)

**Cómo funciona:** después de la primera respuesta (fuera del recorrido) el chat
ofrece "¿Querés que te recuerde?" con nombre y mail. Es opcional: "Ahora no" lo
oculta por 14 días. Si acepta, el navegador guarda `tt_persona_v1` y sus
consultas en `tt_historial_v1` (últimas 30, sin imágenes), que se ven al inicio
en "Tus consultas". Abrir una consulta vieja es solo lectura: no se reenvía al
modelo, así que no suma costo. "Olvidar mis datos" borra todo del dispositivo.
El formulario del recorrido trae tildado "Recordarme en este dispositivo".

**Qué se registra:** el frontend manda `persona: {nombre, mail}` y el backend
lo guarda en `chat_personas` (vía `persona_registrar`, SECURITY DEFINER), una
fila por conversación. No va al modelo ni toca `chat_conversaciones`.

```sql
-- Quién consulta y cuánto
select * from chat_uso_por_persona order by ultima_consulta desc;

-- Las consultas de una persona
select hora, pregunta, respuesta from chat_consultas_con_persona
where mail = 'alguien@mail.com' order by hora;
```

### Monitorear el costo y el caché

El system prompt son **18.440 tokens** (medido) que se reenvían en cada mensaje,
así que domina el costo. Va marcado con `cache_control` y **TTL de 1 hora** para
que se cobre a ~0.1x mientras el caché esté caliente; cada lectura reinicia el
reloj.

El TTL de 1h se eligió midiendo 371 requests reales: el 73% llega con menos de 5
minutos de diferencia, pero otro 21% cae entre 5 y 60 minutos y con el TTL corto
tenía que reescribir el caché. Escribir con 1h cuesta 2x en vez de 1.25x, y solo
el 6% queda fuera de la ventana.

Para reevaluar si el patrón de uso cambia:

```sql
with g as (
  select extract(epoch from (creado_en - lag(creado_en) over (order by creado_en)))/60 as hueco
  from chat_conversaciones
)
select count(*) filter (where hueco <= 5)                as lee_con_5min,
       count(*) filter (where hueco > 5 and hueco <= 60) as necesita_1h,
       count(*) filter (where hueco > 60)                as escribe_igual
from g where hueco is not null;
```

Para ver si está pegando:

```sql
select
  date_trunc('day', creado_en)::date            as dia,
  count(*)                                      as mensajes,
  sum(tokens_cache_leidos)                      as leidos_de_cache,
  sum(tokens_entrada + tokens_cache_escritos)   as pagados_completos,
  round(100.0 * sum(tokens_cache_leidos)
        / nullif(sum(tokens_entrada + tokens_cache_escritos
                     + tokens_cache_leidos), 0), 1) as pct_desde_cache
from chat_conversaciones
where tokens_entrada is not null
group by 1 order by 1 desc;
```

Si `pct_desde_cache` baja, el tráfico se volvió más espaciado que el TTL: correr
la consulta de huecos de arriba y reevaluar.

**Ojo con las conversaciones de un solo turno:** escriben un caché que nadie lee,
así que salen 2x. Solo convienen si otra conversación llega dentro de la hora y
aprovecha ese caché — que es lo que pasa con el volumen actual.

Costo aproximado por día, a precios de Sonnet 4.6 ($3/MTok entrada, $15 salida,
caché leído $0.30/MTok):

```sql
select
  date_trunc('day', creado_en)::date as dia,
  count(*) as mensajes,
  round((sum(tokens_entrada) * 3.0
       + sum(tokens_cache_escritos) * 3.75
       + sum(tokens_cache_leidos) * 0.30
       + sum(tokens_salida) * 15.0) / 1000000.0, 4) as usd
from chat_conversaciones
where tokens_entrada is not null
group by 1 order by 1 desc;
```

### Monitorear el uso

- **Vercel Dashboard** → ver invocaciones del endpoint `/api/chat`
- **console.anthropic.com** → ver consumo de tokens y costo

## 💰 Estimación de costos

Con 500 profesionales y uso normal (5 consultas/mes promedio):
- **Anthropic API:** ~$10-20 USD/mes
- **Vercel:** $0 (plan gratuito alcanza)
- **Total estimado:** menos de $20 USD/mes

El límite de gasto en Anthropic asegura que nunca se supere lo configurado.

## 🔒 Seguridad

- La API key NUNCA viaja al frontend
- Vive solo como variable de entorno en Vercel
- El frontend solo conoce el endpoint `/api/chat` propio
- Las credenciales del login son básicas (suficiente para uso interno del equipo)

## 📞 Soporte

Si algo falla:
1. Revisar logs en Vercel → Project → Deployments → último deploy → Functions
2. Verificar que `ANTHROPIC_API_KEY` esté configurada correctamente en Vercel
3. Verificar que no se haya alcanzado el límite de gasto en Anthropic
