-- Tabla de turnos del consultorio
CREATE TABLE IF NOT EXISTS turnos (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  telefono VARCHAR(30),
  fecha DATE NOT NULL,
  hora TIME NOT NULL,
  motivo VARCHAR(200),
  profesional VARCHAR(100),
  obra_social VARCHAR(100),
  estado VARCHAR(30) DEFAULT 'confirmado',
  observaciones TEXT,
  creado_en TIMESTAMP DEFAULT NOW()
);
