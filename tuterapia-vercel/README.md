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
   - **Key:** `ANTHROPIC_API_KEY`
   - **Value:** la API key del paso 1
   - Aplicar a: Production, Preview, Development
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
