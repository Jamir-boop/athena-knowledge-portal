# Athena Knowledge Portal

Portal interno, estático y protegido con Cloudflare Access. Los documentos y archivos de descarga siguen bajo control de `C:\Users\superuser\OneDrive\dev\framework`.

## Uso

```powershell
npm install
.\deploy.ps1
```

Para habilitar una descarga, cree un vínculo anónimo de OneDrive y guárdelo por su clave:

```powershell
.\scripts\set-link.ps1 -Key "clave-del-catalogo" -Url "https://1drv.ms/..."
.\deploy.ps1
```

El archivo `.secrets\onedrive-links.json` nunca se publica. El despliegue lo carga como el secreto `ONEDRIVE_LINKS` de Pages.

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

- No hay base de datos, CMS, autenticación de lectores ni almacenamiento R2.
- Athena protege el acceso al portal. Un vínculo de OneDrive filtrado conserva sus permisos propios.
- Los vínculos de OneDrive se crean y revocan manualmente en OneDrive.
