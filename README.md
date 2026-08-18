# Athena Knowledge Portal

Portal interno, estático y protegido con Cloudflare Access. Los documentos y archivos de descarga siguen bajo control de `C:\Users\superuser\OneDrive\dev\framework`.

## Uso

```powershell
npm install
.\deploy.ps1
```

Para crear o actualizar todos los enlaces de descarga aprobados, ejecute un solo comando:

```powershell
.\scripts\sync-onedrive-links.ps1
.\deploy.ps1
```

El primer uso puede abrir una autorización de Microsoft. Después, el contexto queda asociado al usuario actual. El script descubre de forma recursiva los `.zip`, `.jar` y `.exe`, crea enlaces anónimos de solo lectura y reemplaza la lista blanca privada. No imprime las URLs.

El módulo oficial `Microsoft.Graph.Authentication` se descarga en `.tools\` y no se instala de forma global. El archivo `.secrets\onedrive-links.json` no entra en Git. El build usa sus claves como lista blanca y escribe los enlaces aprobados en las páginas estáticas protegidas por Cloudflare Access. Cualquier otro tipo de archivo permanece como **Pendiente**.

Athena no oculta el destino después del clic: un usuario autorizado puede ver y copiar el enlace anónimo de OneDrive. Revóquelo en OneDrive si deja de ser válido.

`deploy.ps1` comprueba el acceso anónimo antes del build. Si Cloudflare no redirige al inicio de sesión de Access, se detiene sin publicar los enlaces.

`set-link.ps1` queda disponible solo como alternativa para corregir un enlace individual desde el portapapeles.

## Artículos

Los Markdown canónicos viven en `C:\Users\superuser\OneDrive\dev\framework\docs`. Para agregar un artículo, cree un archivo `.md` con un título `#` en esa carpeta y ejecute `.\deploy.ps1`. El build descubre todos los Markdown, genera su ruta, lo agrega a **Guías** y lo incluye en la búsqueda.

Para actualizar un artículo, edite el mismo archivo y vuelva a desplegar. OneDrive conserva la copia sincronizada; `dist\` es solo el resultado publicable y se puede regenerar.

Las reglas editoriales están en `docs\contributing.md` dentro de la carpeta canónica y se publican como **Cómo contribuir**.

## Impeccable

Impeccable está instalado solo para este proyecto en `.agents\skills\impeccable\`. Verifique la instalación con:

```powershell
npx -y impeccable check --providers=codex --scope=project
```

## Límites deliberados

- No hay base de datos, CMS, Pages Functions, Workers ni almacenamiento R2.
- El costo permitido de Cloudflare es USD 0. Consulte `AGENTS.md` antes de cambiar cualquier servicio de Cloudflare.
- Athena protege el acceso al portal. Un vínculo de OneDrive filtrado conserva sus permisos propios.
- Los vínculos de OneDrive se crean de forma automática con Microsoft Graph y el permiso delegado `Files.ReadWrite`.
