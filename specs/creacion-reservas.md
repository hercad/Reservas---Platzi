# Spec: Módulo de Creación y Gestión de Reservas

> **Estado:** Draft | **Última actualización:** 2026-09-30
> **Ubicación de Arquitectura:** Bounded Context / Módulo de Reservas y Gestión

## 1. Contexto y Delimitación del Dominio

### 1.1 Visión General

Permitir a los usuarios autenticados explorar la disponibilidad y gestionar reservas de turnos de 1 hora en un catálogo cerrado de 5 canchas de pádel, garantizando la integridad de la agenda, la prevención estricta de colisiones (*double-booking*) a nivel de persistencia y el control de una única reserva activa por usuario.

### 1.2 Objetivos (Goals) vs. No-Objetivos (Non-Goals)

* **In-Scope:**

  * Autenticación básica de usuarios.

  * Exploración de grilla de 24 horas (bloques de 1 hora) para las 5 canchas fijas.

  * Creación atómica de reservas con prevención de condiciones de carrera.

  * Panel de gestión de reservas propias (visualización y cancelación de turnos futuros).

  * Restricción de una sola reserva activa por usuario de forma simultánea.

* **Out-of-Scope:**

  * Pasarela de pagos integrada (pago presencial en sede).

  * Panel de administración web para modificar canchas (catálogo inmutable en código).

  * Notificaciones externas (SMS, WhatsApp o correos electrónicos).

  * Reservas continuas de más de 1 solo clic o sistemas de matchmaking.

### 1.3 Lenguaje Ubicuo

| **Término** | **Definición** | **Ejemplo / Comentario** | 
| --- | --- | --- |
| **Catálogo Cerrado** | Conjunto inmutable de 5 canchas físicas predefinidas en el sistema. | Cancha Laureles, El Poblado, Belén, Robledo, Envigado. | 
| **Bloque Disponible** | Franja horaria de 1 hora libre de asignaciones previas en la grilla. | Slot de 14:00 a 15:00 en Cancha Laureles. | 
| **Colisión de Concurrencia** | Intento simultáneo de dos usuarios por reservar el mismo slot al mismo milisegundo. | Resuelto mediante índice único compuesto en base de datos (`409 Conflict`). | 
| **Reserva Activa** | Turno futuro confirmado que actualmente detenta el usuario en el sistema. | El usuario solo puede tener una a la vez; expira automáticamente si el turno ya transcurrió. | 

## 2. Especificación Funcional y Reglas de Negocio

### 2.1 Reglas de Negocio (Clarificadas)

* **[RN-001] Catálogo Inmutable:** El sistema opera estrictamente sobre las 5 canchas definidas en el código (`Cancha Laureles`, `Cancha El Poblado`, `Cancha Belén`, `Cancha Robledo`, `Cancha Envigado`).

* **[RN-002] Restricción Temporal y Zona Horaria:** Todas las validaciones temporales se evalúan estrictamente contra el servidor en formato UTC y hora local del sistema (ISO 8601). El sistema DEBE rechazar cualquier intento de reserva en fechas u horarios pasados.

* **[RN-003] Granularidad y Ciclo de Vida de Reserva Activa:** Las reservas se estructuran en bloques enteros de 1 hora. Un usuario solo puede tener una (1) reserva activa simultáneamente. Una reserva se considera "activa" de forma estricta si su fecha y hora de finalización son mayores a la hora actual del servidor (`reservation_date >= hoy AND end_hour > hora_actual`). Si el turno transcurre, deja de ser activa automáticamente.

* **[RN-004] Prevención de Colisión y Manejo de Errores:** El sistema validará la disponibilidad en la base de datos de forma atómica. Si ocurre una condición de carrera, el backend interceptará el error de restricción única y retornará un código HTTP `409 Conflict` con un JSON estructurado indicando que el turno acaba de ser ocupado.

### 2.2 Flujo Principal de Creación

```
graph TD
    A[Usuario autenticado selecciona Cancha, Fecha y Hora] --> B{¿Tiene reserva activa futura vigente?}
    B -- Sí --> C[Rechazar: Límite de 1 reserva activa]
    B -- No --> D{¿Es fecha/hora futura (UTC)?}
    D -- No --> E[Rechazar: Error de Tiempo]
    D -- Sí --> F[Intentar persistir en DB con Índice Único]
    F -- Éxito --> G[Confirmar Reserva: 201 Created]
    F -- Fallo por Colisión --> H[Retornar Conflicto estructurado: HTTP 409]

```

## 3. Historias de Usuario y Criterios de Aceptación

### US-01: Restricción de Única Reserva Activa

> **Como** usuario autenticado,
>
> **quiero** que el sistema impida registrar un nuevo turno si ya poseo una reserva futura activa,
>
> **para** garantizar la equidad de uso de las canchas entre todos los miembros.

* **Criterios de Aceptación (EARS):**

  * *Mientras* el usuario tenga una reserva activa vigente (con fecha y hora de finalización futuras), *el sistema deberá* rechazar cualquier solicitud de nueva reserva y retornar un código HTTP `400`.

* **Criterios de Aceptación (Given-When-Then):**

  * **Given** que el usuario "Carlos" tiene una reserva confirmada para el próximo sábado en la Cancha Laureles.

  * **When** intenta crear una segunda reserva para el domingo en la Cancha El Poblado.

  * **Then** el sistema rechaza la operación y muestra el mensaje amigable: *"Ya posees una reserva activa. Debes cancelarla antes de crear una nueva"*.

### US-02: Prevención Atómica de Concurrencia (Double-Booking)

> **Como** sistema de reservas,
>
> **debo** validar la unicidad del bloque horario a nivel de motor de base de datos,
>
> **para** evitar condiciones de carrera (*race conditions*) cuando dos usuarios intenten apartar el mismo slot simultáneamente.

* **Criterios de Aceptación (Given-When-Then):**

  * **Given** que el slot de las 14:00 del día 2026-10-01 en la Cancha Robledo se encuentra disponible.

  * **When** dos usuarios diferentes envían una petición HTTP POST para reservarlo exactamente al mismo milisegundo.

  * **Then** el motor de base de datos aplica la restricción de índice único, permitiendo la transacción del primer usuario (HTTP `201 Created`) y rechazando la del segundo con un código HTTP `409 Conflict` y un mensaje claro para que elija otro turno.