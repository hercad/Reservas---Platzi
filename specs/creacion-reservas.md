# Spec: Módulo de Creación de Reservas
> **Estado:** Draft | **Última actualización:** 2026-09-30
> **Ubicación de Arquitectura:** Bounded Context / Módulo de Reservas

---

## 1. Contexto y Delimitación del Dominio

### 1.1 Visión General

Permitir a los usuarios autenticados agendar bloques de tiempo de forma síncrona, garantizando la integridad de la agenda y previniendo colisiones por concurrencia a nivel de persistencia.

### 1.2 Objetivos (Goals) vs. No-Objetivos (Non-Goals)

* **In-Scope:** Agendamiento de bloques enteros de 1 hora, validación de disponibilidad y prevención estricta de colisiones (condiciones de carrera).
* **Out-of-Scope:** Pasarela de pagos integrada (se paga directamente en el club) y envío de correos o SMS de confirmación.

### 1.3 Lenguaje Ubicuo

| Término | Definición | Ejemplo / Comentario |
| --- | --- | --- |
| **Bloque Disponible** | Franja horaria de 1 hora libre de asignaciones previas en la grilla. | Slot de 14:00 a 15:00 |
| **Colisión de Concurrencia** | Intento simultáneo de dos o más usuarios por reservar la misma franja al mismo milisegundo. | Resuelto mediante restricción de unicidad en base de datos. |

---

## 2. Especificación Funcional y Reglas de Negocio

### 2.1 Reglas de Negocio

* **[RN-001] Restricción Temporal:** El sistema DEBE rechazar cualquier intento de reserva en fechas u horarios pasados respecto al timestamp actual del servidor.
* **[RN-002] Granularidad:** Las reservas se estructuran estrictamente en bloques enteros de 1 hora.
* **[RN-003] Prevención de Colisión:** El sistema validará la disponibilidad en la base de datos de forma atómica. Si ocurre una condición de carrera, la base de datos lanzará un error de unicidad que la aplicación interceptará para retornar un código de error de conflicto HTTP 409.

### 2.2 Flujo Principal

```mermaid
graph TD
    A[Usuario selecciona Bloque Disponible] --> B{¿Es fecha/hora futura?}
    B -- No --> C[Rechazar: Error de Tiempo]
    B -- Si --> D[Intentar persistir asignación en DB]
    D -- Éxito de Unicidad --> E[Asignar bloque y actualizar grilla]
    D -- Fallo por Colisión --> F[Retornar Conflicto HTTP 409]