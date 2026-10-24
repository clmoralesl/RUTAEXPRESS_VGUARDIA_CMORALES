# Informe Tecnico de Anomalias y Deuda Tecnica - Plataforma RutaExpress

Este documento recopila cuatro incidencias y brechas de diseño detectadas en la integracion del Frontend y Backend de RutaExpress tras la ejecucion y prueba del Issue #57 ("Generacion Automatica de Codigo de Seguimiento y Normalizacion de Direcciones de Envio"). Su proposito es servir como insumo tecnico para analisis de arquitectura, diseno de solucion y priorizacion en el backlog colaborativo.

---

## Incidencia 1: Impresion Completa de Pantalla en Lugar de Etiqueta Termica Aislada (/envios)

- **Ubicacion:** 
  - `rutaexpress-frontend/src/app/features/shipments/components/etiqueta-modal/etiqueta-modal.component.ts`
  - `rutaexpress-frontend/src/app/features/shipments/components/etiqueta-modal/etiqueta-modal.component.scss`
- **Comportamiento Anomalo:**
  Al presionar el boton "Imprimir Etiqueta" dentro del modal de rotulado, el navegador dispara la ventana de impresion nativa (`window.print()`). Sin embargo, en la vista previa de impresion se intenta imprimir la pagina `/envios` completa (incluyendo encabezados, formulario de creacion y tabla de registros), rompiendo el formato de rotulado termico estandar de 100mm x 150mm.
- **Causa Raiz:**
  El componente Angular utiliza encapsulacion de estilos por defecto (`ViewEncapsulation.Emulated`). En `etiqueta-modal.component.scss` se definieron reglas `@media print` con el selector:
  ```scss
  @media print {
    body * {
      visibility: hidden;
    }
    .modal-overlay, .etiqueta-termica, .etiqueta-termica * {
      visibility: visible !important;
    }
  }
  ```
  Al compilarse con encapsulacion de componente, el selector `body *` no tiene alcance global fuera de `<app-etiqueta-modal>`, por lo que el DOM exterior permanece visible y desborda el lienzo de impresion.
- **Solucion Tecnica Propuesta:**
  1. Mover las directivas de `@media print` al archivo global `src/styles.scss` o configurarlas con `:host-context` / `::ng-deep`.
  2. Aplicar `display: none !important` a todos los elementos del layout principal excepto al contenedor `.etiqueta-termica`.
  3. Fijar las dimensiones exactas `@page { size: 100mm 150mm; margin: 0; }` y forzar `position: absolute; top: 0; left: 0; width: 100mm; height: 150mm;`.

---

## Incidencia 2: Inconsistencia y Fragmentacion de Barras de Navegacion (Navbars)

- **Ubicacion:** 
  - `rutaexpress-frontend/src/app/features/landing/landing.html`
  - `rutaexpress-frontend/src/app/features/catalogo/catalogo.component.html`
  - `rutaexpress-frontend/src/app/features/rastreo/rastreo.component.html`
  - `rutaexpress-frontend/src/app/features/auditoria/auditoria.component.html`
  - `rutaexpress-frontend/src/app/features/reportes/reportes.component.html`
  - `rutaexpress-frontend/src/app/features/dashboard/dashboard.html`
  - `rutaexpress-frontend/src/app/features/shipments/shipments.html`
- **Comportamiento Anomalo:**
  No existe una experiencia de navegacion coherente. Cada vista implementa su propio encabezado HTML de forma aislada, utilizando diferentes clases CSS (`.header`, `.navbar`, `.barra-superior`), diferentes combinaciones de botones y estilos visuales heterogeneos. En `/envios`, no existe barra de navegacion, solo un enlace de texto hacia `/dashboard`.
- **Causa Raiz:**
  Falta de un componente transversal de navegacion compartido (`NavbarComponent`). La logica de presentacion de sesion y los hipervinculos fueron codificados de manera ad-hoc dentro de las plantillas de cada funcionalidad.
- **Solucion Tecnica Propuesta:**
  1. Disenar e implementar un componente standalone `NavbarComponent` en `src/app/shared/components/navbar/`.
  2. Centralizar la visualizacion de enlaces institucionales (Inicio, Catalogo, Rastreo, Gestion de Envios, Reportes, Auditoria) segun el estado de autenticacion (`AuthService`) y roles RBAC (`ROLE_ADMIN`, `ROLE_DESPACHADOR`, `ROLE_CLIENTE`).
  3. Instanciar `NavbarComponent` de manera global en `app.component.html` (o en un layout maestro), eliminando los encabezados redundantes de cada componente.

---

## Incidencia 3: Ausencia de Validacion del Algoritmo Modulo 11 en RUTs Chilenos

- **Ubicacion:**
  - Frontend: `rutaexpress-frontend/src/app/features/shipments/shipments.ts`
  - Backend: `ms-rutaexpress-envios/src/main/java/cl/rutaexpress/envios/dto/CrearEnvioRequest.java`
  - Base de Datos: Esquema `USER_ENVIOS`, tabla `ENVIOS`
- **Comportamiento Anomalo:**
  El sistema permite registrar envios con RUTs de remitente y destinatario sintactica o matematicamente invalidos (ej: `11111111-1`, `99999999-9`, caracteres arbitrarios), siempre y cuando el campo no se envie en blanco.
- **Causa Raiz:**
  - En el formulario reactivo de Angular, los controles solo tienen `Validators.required`.
  - En el DTO de Spring Boot, los campos solo cuentan con la anotacion `@NotBlank`.
  - No existe implementacion del algoritmo ponderado modulo 11 (factores 2 al 7) para corroborar la validez del digito verificador.
- **Solucion Tecnica Propuesta:**
  1. **Frontend:** Crear una funcion `rutChilenoValidator(): ValidatorFn` en `src/app/shared/validators/rut.validator.ts` que normalice el texto (eliminacion de puntos y guion), verifique longitud y calcule el digito verificador esperado (`0-9` o `K`), alertando visualmente en el formulario.
  2. **Backend:** Crear una anotacion Jakarta `@RutChileno` y su correspondiente `ConstraintValidator<RutChileno, String>` en `ms-rutaexpress-envios` que retorne HTTP 400 Bad Request si el RUT no supera el calculo de verificacion previo a la persistencia.

---

## Incidencia 4: Fuga de Informacion / Vulnerabilidad BOLA en Listado de Envios (/envios)

- **Ubicacion:**
  - Frontend: `rutaexpress-frontend/src/app/features/shipments/shipments.ts`
  - Backend BFF: `ms-rutaexpress-bff/src/main/java/cl/duoc/rutaexpress/bff/controller/EnviosBffController.java`
  - Microservicio Envios: `ms-rutaexpress-envios/src/main/java/cl/rutaexpress/envios/service/EnvioService.java`
- **Comportamiento Anomalo:**
  Cualquier usuario autenticado que ingrese a la ruta `/envios` (incluyendo usuarios estandar o clientes que pulsan "Crear Envio con este Servicio" en `/catalogo`) visualiza en la tabla inferior la totalidad de los envios de todos los clientes de la plataforma, incluyendo nombres de comunas, pesos, fechas y codigos de seguimiento ajenos.
- **Causa Raiz:**
  - La pantalla fue concebida en el Sprint 1 como consola interna para despachadores y administradores.
  - La entidad `Envio` solo almacena `rutRemitente` y `rutDestinatario`, sin guardar el identificador del usuario autenticado en Microsoft Entra ID (email / `preferred_username` / `oid`).
  - El metodo `EnvioService.listar()` ejecuta `Specification.where(null)`, entregando todos los registros sin aplicar un filtro de autorizacion a nivel de objeto (vulnerabilidad OWASP BOLA / Broken Object Level Authorization).
- **Solucion Tecnica Propuesta:**
  1. **Mitigacion Front:** Condicionar la renderizacion de la tabla de envios a roles de despacho (`*ngIf="puedeGestionarEstados()"`). Para clientes estandar, presentar unicamente el formulario de creacion y, tras enviar, mostrar una tarjeta de exito con su codigo institucional y un boton de redireccion hacia `/rastreo/:codigo`.
  2. **Solucion Estructural:**
     - Agregar la columna `CREADO_POR_EMAIL VARCHAR2(100)` en la tabla `ENVIOS` y en la entidad JPA.
     - Extraer el claim de identidad del JWT en el BFF y propagarlo a `ms-rutaexpress-envios`.
     - Si el usuario cuenta con `ROLE_CLIENTE`, aplicar filtro obligatorio `WHERE creado_por_email = :email`. Si cuenta con `ROLE_ADMIN` o `ROLE_DESPACHADOR`, permitir la consulta global.
