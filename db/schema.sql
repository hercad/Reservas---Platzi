-- =========================================================================
-- Esquema de Persistencia: Sistema de Reservas de Pádel
-- Motor: SQLite (better-sqlite3)
-- =========================================================================

-- 1. Catálogo Cerrado de Canchas (Inmutable según Constitución)
CREATE TABLE IF NOT EXISTS courts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    location TEXT NOT NULL
);

-- Inserción estática de las 5 canchas oficiales
INSERT OR IGNORE INTO courts (id, name, location) VALUES 
(1, 'Cancha Laureles', 'Sede Principal'),
(2, 'Cancha El Poblado', 'Sede Principal'),
(3, 'Cancha Belén', 'Sede Norte'),
(4, 'Cancha Robledo', 'Sede Norte'),
(5, 'Cancha Envigado', 'Sede Sur');

-- 2. Tabla de Usuarios (Autenticación Básica)
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    created_at DATETIME DEFAULT (datetime('now', 'utc'))
);

-- 3. Tabla de Reservas
CREATE TABLE IF NOT EXISTS reservations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    court_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    reservation_date TEXT NOT NULL,         -- Formato ISO YYYY-MM-DD (UTC)
    start_hour INTEGER NOT NULL,            -- Bloques enteros de 0 a 23
    status TEXT NOT NULL DEFAULT 'CONFIRMED', -- CONFIRMED | CANCELLED
    created_at DATETIME DEFAULT (datetime('now', 'utc')),
    
    FOREIGN KEY (court_id) REFERENCES courts(id),
    FOREIGN KEY (user_id) REFERENCES users(id),

    -- REGLA DE ORO DE PERSISTENCIA: Índice único compuesto anti-colisión (Double-Booking)
    CONSTRAINT unique_court_slot UNIQUE (court_id, reservation_date, start_hour)
);

-- 4. Índice auxiliar para consultas rápidas de reservas activas por usuario
CREATE INDEX IF NOT EXISTS idx_user_active_reservations 
ON reservations (user_id, status, reservation_date, start_hour);