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
