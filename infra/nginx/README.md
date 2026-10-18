# Infraestructura de Proxy Inverso Nginx con HTTPS (RutaExpress)

## Descripcion General
Este componente (`infra/nginx`) implementa una fachada unificada de entrada (Reverse Proxy) basada en Nginx 1.27 con soporte nativo de HTTPS/TLSv1.3, resolucion de preflights CORS centralizada y contexto seguro para la aplicacion web Angular y la libreria MSAL.

---

## Resolucion del Error `crypto_nonexistent` de MSAL Angular

### Diagnostico Tecnico
En versiones modernas de navegadores basados en Chromium (Google Chrome, Microsoft Edge) y Firefox, la especificacion W3C Web Cryptography API restringe de forma estricta el acceso a `window.crypto.subtle` unicamente a entornos considerados **Contextos Seguros** (`window.isSecureContext === true`).

Cuando el frontend era accedido mediante HTTP plano (`http://localhost:4200` o direcciones IP), el motor del navegador deshabilitaba `window.crypto.subtle`, lo cual provocaba que `@azure/msal-browser` fallara al inicializarse con la excepcion:
```
BrowserAuthError: crypto_nonexistent: The crypto object or function is not available.
Ensure that you are running in a secure context (https://).
```
Para mitigar esto temporalmente, se requeria activar banderas internas de desarrollo (`chrome://flags/#unsafely-treat-insecure-origin-as-secure`), lo cual resulta inaceptable en un entorno comercial y fue formalmente observado en la evaluacion.

### Solucion Definitiva con Nginx HTTPS
Al canalizar el trafico a traves de Nginx bajo HTTPS en el puerto `443` con certificados SSL X.509:
1. El navegador reconoce la sesion bajo protocolo seguro (`https://localhost`).
2. Se otorga automaticamente `window.isSecureContext = true`.
3. La API `window.crypto.subtle` queda disponible de forma nativa e inmediata.
4. El flujo de autenticacion de Azure AD (MSAL) opera al 100% sin requerir configuraciones de flags en ningun navegador.

---

## Arquitectura de Fachada Same-Origin y Manejo de CORS

El proxy inverso elimina los problemas de CORS mediante una estrategia de **Mismo Origen (Same-Origin)**:

```
[ Cliente Web / Navegador ]
            │
            ▼ (HTTPS :443)
┌───────────────────────────────────────┐
│        Nginx Reverse Proxy            │
│   (Fachada Unificada de Dominio)      │
└───────┬───────────────────────┬───────┘
        │                       │
        │ /api/*                │ /* (Frontend SPA)
        ▼                       ▼
┌──────────────────┐    ┌────────────────────────┐
│ms-rutaexpress-bff│    │  rutaexpress-frontend  │
│   (Puerto 8080)  │    │      (Puerto 80)       │
└──────────────────┘    └────────────────────────┘
```

1. **Preflights CORS Centralizados**: Las peticiones `OPTIONS` emitidas por los navegadores son interceptadas de forma instantanea por Nginx, respondiendo con código HTTP `204 No Content` y cabeceras permisivas (`Access-Control-Allow-Origin`, `Access-Control-Allow-Methods`, `Access-Control-Allow-Headers`), sin generar carga computacional ni latencia en los microservicios de Spring Boot.
2. **Redireccion HTTP Forzosa**: Todo trafico entrante por el puerto `80` (HTTP) es redirigido permanentemente mediante HTTP `301 Moved Permanently` hacia `https://$host$request_uri`.

---

## Estructura de Archivos

- `nginx.conf`: Configuracion principal del proxy inverso, directivas SSL, upstream dinamico mediante el resolver DNS interno de Docker (`127.0.0.11`) y reglas de enrutamiento.
- `certs/`: Certificados X.509 de desarrollo local (`localhost.crt` y `localhost.key`) con extensiones Subject Alternative Name (SAN: `DNS:localhost`, `IP:127.0.0.1`).
- `certs/generar_certificados.ps1`: Script automatizado para regenerar certificados SSL mediante OpenSSL.
- `compose.yml`: Definicion de orquestacion Docker Compose para levantar el proxy como servicio independiente.
- `verificar_nginx.ps1`: Suite automatizada de comprobacion de sintaxis, arranque de contenedor, redireccion 301, validez SSL y preflights CORS 204.

---

## Verificacion de Operatividad

Para ejecutar la verificacion automatizada:
```powershell
powershell -ExecutionPolicy Bypass -File infra/nginx/verificar_nginx.ps1
```
