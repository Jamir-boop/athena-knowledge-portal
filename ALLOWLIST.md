# Lista permitida de Athena

La regla es simple: una solicitud entra solo cuando su IP pública coincide con una entrada de esta lista. No se solicita inicio de sesión.

| Red | Uso | Estado |
| --- | --- | --- |
| `38.253.151.170/32` | Administración desde casa | Activa |
| IP pública fija de la oficina | Personal en la red de trabajo | Pendiente |
| IP pública de la red de invitados | Visitantes | Pendiente |

## Operación

1. Agregue únicamente IP públicas o redes CIDR confirmadas.
2. Use una entrada separada para oficina y visitantes.
3. Quite una entrada cuando deje de ser necesaria.
4. Proteja tanto `athena-knowledge-portal.pages.dev` como sus vistas previas.
5. Una dirección dinámica deja de funcionar cuando cambia. Actualice la entrada; no amplíe la red para compensarlo.

Cloudflare Access usa una política **Bypass** limitada a estas IP. Toda IP que no coincida queda bloqueada por la aplicación Access.
