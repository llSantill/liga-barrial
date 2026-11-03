CREATE TABLE equipos (
    id_equipo   SERIAL       PRIMARY KEY,
    nombre      VARCHAR(100) NOT NULL UNIQUE,
    barrio      VARCHAR(100) NOT NULL
);

CREATE TABLE jugadores (
    id_jugador      SERIAL       PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    numero_camiseta SMALLINT     NOT NULL CHECK (numero_camiseta BETWEEN 1 AND 99),
    telefono        VARCHAR(20),
    estado          VARCHAR(20)  NOT NULL DEFAULT 'activo'
                    CHECK (estado IN ('activo', 'lesionado', 'suspendido')),
    id_equipo       INTEGER      NOT NULL REFERENCES equipos(id_equipo),
    UNIQUE (id_equipo, numero_camiseta)
);

CREATE TABLE arbitro (
    id_arbitro  SERIAL       PRIMARY KEY,
    nombre      VARCHAR(100) NOT NULL,
    telefono    VARCHAR(20)  NOT NULL UNIQUE
);

CREATE TABLE sede (
    id_sede     SERIAL       PRIMARY KEY,
    nombre      VARCHAR(100) NOT NULL,
    direccion   VARCHAR(150) NOT NULL UNIQUE
);

CREATE TABLE partido (
    id_partido           SERIAL      PRIMARY KEY,
    fecha                DATE        NOT NULL,
    hora                 TIME        NOT NULL,
    resultado            VARCHAR(10),
    id_sede              INTEGER     NOT NULL REFERENCES sede(id_sede),
    id_arbitro           INTEGER              REFERENCES arbitro(id_arbitro),
    fase                 VARCHAR(20),
    id_partido_siguiente INTEGER              REFERENCES partido(id_partido)
);

CREATE TABLE partido_equipo (
    id_partido  INTEGER     NOT NULL REFERENCES partido(id_partido),
    id_equipo   INTEGER     NOT NULL REFERENCES equipos(id_equipo),
    rol         VARCHAR(10) NOT NULL CHECK (rol IN ('local', 'visitante')),
    PRIMARY KEY (id_partido, id_equipo)
);

CREATE INDEX idx_jugadores_equipo      ON jugadores (id_equipo);
CREATE INDEX idx_jugadores_estado      ON jugadores (estado);
CREATE INDEX idx_partido_sede          ON partido (id_sede);
CREATE INDEX idx_partido_arbitro_fecha ON partido (id_arbitro, fecha, hora);
CREATE INDEX idx_partido_equipo_equipo ON partido_equipo (id_equipo);

CREATE OR REPLACE FUNCTION registrar_partido(
    IN  p_fecha       DATE,
    IN  p_hora        TIME,
    IN  p_id_sede     INT,
    IN  p_id_arbitro  INT,
    OUT p_id_partido_creado INT,
    OUT p_mensaje     VARCHAR
)
AS $$
DECLARE
    v_existe_sede    INT;
    v_existe_arbitro INT;
BEGIN
    SELECT COUNT(*) INTO v_existe_sede FROM sede WHERE id_sede = p_id_sede;
    IF v_existe_sede = 0 THEN
        RAISE EXCEPTION 'La sede con ID % no existe en el sistema.', p_id_sede;
    END IF;

    SELECT COUNT(*) INTO v_existe_arbitro FROM arbitro WHERE id_arbitro = p_id_arbitro;
    IF v_existe_arbitro = 0 THEN
        RAISE EXCEPTION 'El árbitro con ID % no existe en el sistema.', p_id_arbitro;
    END IF;

    INSERT INTO partido (fecha, hora, resultado, id_sede, id_arbitro)
    VALUES (p_fecha, p_hora, NULL, p_id_sede, p_id_arbitro)
    RETURNING id_partido INTO p_id_partido_creado;

    p_mensaje := 'Partido registrado correctamente.';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION rehabilitar_jugadores_equipo(
    IN  p_id_equipo INT,
    OUT p_total_rehabilitados INT
)
AS $$
DECLARE
    r_jugador RECORD;
BEGIN
    p_total_rehabilitados := 0;
    FOR r_jugador IN
        SELECT id_jugador, nombre, estado FROM jugadores WHERE id_equipo = p_id_equipo
    LOOP
        IF r_jugador.estado = 'suspendido' THEN
            UPDATE jugadores SET estado = 'activo' WHERE id_jugador = r_jugador.id_jugador;
            p_total_rehabilitados := p_total_rehabilitados + 1;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION asignar_equipos_partido(
    IN p_id_partido   INT,
    IN p_id_local     INT,
    IN p_id_visitante INT
)
RETURNS VARCHAR AS $$
BEGIN
    IF p_id_local = p_id_visitante THEN
        RAISE EXCEPTION 'El equipo local y visitante no pueden ser el mismo (ID: %).', p_id_local;
    END IF;

    INSERT INTO partido_equipo (id_partido, id_equipo, rol) VALUES (p_id_partido, p_id_local, 'local');
    INSERT INTO partido_equipo (id_partido, id_equipo, rol) VALUES (p_id_partido, p_id_visitante, 'visitante');

    RETURN 'Equipos asignados exitosamente al partido ' || p_id_partido;
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'Uno o ambos equipos ya están asignados a este partido.';
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'El partido o uno de los equipos ingresados no existe en la base de datos.';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION obtener_estado_plantilla(
    IN  p_id_equipo INT,
    OUT p_total_jugadores INT,
    OUT p_activos INT,
    OUT p_disponibilidad VARCHAR
)
AS $$
DECLARE
    v_porcentaje NUMERIC;
BEGIN
    SELECT COUNT(*) INTO p_total_jugadores FROM jugadores WHERE id_equipo = p_id_equipo;
    IF p_total_jugadores = 0 THEN
        RAISE EXCEPTION 'El equipo con ID % no tiene jugadores registrados.', p_id_equipo;
    END IF;

    SELECT COUNT(*) INTO p_activos FROM jugadores WHERE id_equipo = p_id_equipo AND estado = 'activo';
    v_porcentaje := (p_activos::NUMERIC / p_total_jugadores::NUMERIC) * 100;

    IF v_porcentaje >= 80 THEN
        p_disponibilidad := 'Plantilla Óptima (' || ROUND(v_porcentaje, 1) || '% activos)';
    ELSIF v_porcentaje >= 50 THEN
        p_disponibilidad := 'Plantilla Aceptable (' || ROUND(v_porcentaje, 1) || '% activos)';
    ELSE
        p_disponibilidad := 'Plantilla Crítica (' || ROUND(v_porcentaje, 1) || '% activos)';
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_trg_validar_max_equipos_partido()
RETURNS TRIGGER AS $$
DECLARE
    v_conteo INT;
BEGIN
    SELECT COUNT(*) INTO v_conteo FROM partido_equipo WHERE id_partido = NEW.id_partido;
    IF v_conteo >= 2 THEN
        RAISE EXCEPTION 'El partido con ID % ya tiene asignados los 2 equipos requeridos (local y visitante).', NEW.id_partido;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_max_equipos_partido
BEFORE INSERT ON partido_equipo
FOR EACH ROW EXECUTE FUNCTION fn_trg_validar_max_equipos_partido();

CREATE OR REPLACE FUNCTION fn_trg_validar_estado_jugador()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.estado = 'suspendido' OR OLD.estado = 'lesionado') AND NEW.estado = 'activo' THEN
        RAISE NOTICE 'Rehabilitando al jugador % (ID: %) para la liga.', NEW.nombre, NEW.id_jugador;
    END IF;
    IF NEW.numero_camiseta < 1 OR NEW.numero_camiseta > 99 THEN
        RAISE EXCEPTION 'El número de camiseta debe estar entre 1 y 99.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_estado_jugador
BEFORE UPDATE ON jugadores
FOR EACH ROW EXECUTE FUNCTION fn_trg_validar_estado_jugador();

CREATE OR REPLACE FUNCTION fn_trg_validar_disponibilidad_arbitro()
RETURNS TRIGGER AS $$
DECLARE
    v_cruces INT;
BEGIN
    SELECT COUNT(*) INTO v_cruces
    FROM partido
    WHERE id_arbitro = NEW.id_arbitro
      AND fecha = NEW.fecha
      AND hora = NEW.hora
      AND id_partido <> COALESCE(NEW.id_partido, -1);

    IF v_cruces > 0 THEN
        RAISE EXCEPTION 'El árbitro con ID % ya tiene un partido programado el % a las %.',
                        NEW.id_arbitro, NEW.fecha, NEW.hora;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_disponibilidad_arbitro
BEFORE INSERT OR UPDATE ON partido
FOR EACH ROW EXECUTE FUNCTION fn_trg_validar_disponibilidad_arbitro();

CREATE OR REPLACE VIEW vista_resumen_equipos AS
SELECT
    e.id_equipo,
    e.nombre AS equipo,
    e.barrio,
    COUNT(j.id_jugador) AS total_jugadores,
    COUNT(j.id_jugador) FILTER (WHERE j.estado = 'activo')     AS activos,
    COUNT(j.id_jugador) FILTER (WHERE j.estado = 'lesionado')  AS lesionados,
    COUNT(j.id_jugador) FILTER (WHERE j.estado = 'suspendido') AS suspendidos,
    (SELECT COUNT(*) FROM partido_equipo pe WHERE pe.id_equipo = e.id_equipo) AS partidos_asignados
FROM equipos e
LEFT JOIN jugadores j ON j.id_equipo = e.id_equipo
GROUP BY e.id_equipo, e.nombre, e.barrio;
BEGIN;

INSERT INTO equipos (id_equipo, nombre, barrio) VALUES
  (1, 'Leones de Belén', 'Belén'),
  (2, 'Halcones de Robledo', 'Robledo'),
  (3, 'Tigres de Manrique', 'Manrique'),
  (4, 'Águilas de Laureles', 'Laureles'),
  (5, 'Pumas de Castilla', 'Castilla'),
  (6, 'Toros de Buenos Aires', 'Buenos Aires'),
  (7, 'Lobos de Aranjuez', 'Aranjuez'),
  (8, 'Cóndores de La América', 'La América');

INSERT INTO sede (id_sede, nombre, direccion) VALUES
  (1, 'Unidad Deportiva de Belén', 'Cra 76 #22B-30, Belén'),
  (2, 'Polideportivo Sur', 'Cl 30A #80-15, Belén'),
  (3, 'Cancha Sintética Robledo', 'Cl 65 #88-20, Robledo');

INSERT INTO arbitro (id_arbitro, nombre, telefono) VALUES
  (1, 'Carlos Restrepo', '3019998877'),
  (2, 'Luisa Gómez', '3104445566'),
  (3, 'Andrés Cardona', '3157771122');

INSERT INTO jugadores (nombre, numero_camiseta, telefono, estado, id_equipo) VALUES
  ('Jorge Hincapié', 10, '3000007919', 'activo', 1),
  ('Mateo Ríos', 1, NULL, 'activo', 1),
  ('Samuel Vélez', 5, NULL, 'suspendido', 1),
  ('Juan Camilo Cardona', 11, '3000031676', 'activo', 1),
  ('Óscar Montoya', 15, NULL, 'activo', 1),
  ('Juan David Zapata', 16, NULL, 'activo', 1),
  ('Samuel Montoya', 7, '3000055433', 'activo', 1),
  ('Kevin Ramírez', 9, NULL, 'activo', 1),
  ('Diego Ospina', 3, NULL, 'activo', 1),
  ('Ricardo Cano', 4, '3000079190', 'activo', 1),
  ('Martín Duque', 27, NULL, 'activo', 1),
  ('Fabián García', 30, NULL, 'activo', 1),
  ('Sebastián Quintero', 20, '3000102947', 'activo', 1),
  ('Mateo Duque', 26, NULL, 'activo', 1),
  ('Iván Londoño', 28, NULL, 'activo', 1),
  ('Jhon Betancur', 14, '3000126704', 'activo', 1),
  ('Fabián Ramírez', 2, NULL, 'activo', 1),
  ('Luis Escobar', 22, NULL, 'activo', 1),
  ('Juan José Quintero', 19, '3000150461', 'activo', 1),
  ('Jerónimo Arango', 29, NULL, 'activo', 1),
  ('Simón Giraldo', 21, NULL, 'activo', 1),
  ('Samuel Correa', 18, '3000174218', 'lesionado', 1),
  ('Miguel Restrepo', 6, NULL, 'activo', 1),
  ('Juan Giraldo', 13, NULL, 'activo', 1),
  ('Julián López', 12, '3000197975', 'activo', 1),
  ('Andrés Muñoz', 9, '3000205894', 'activo', 2),
  ('Kevin Arango', 8, NULL, 'lesionado', 2),
  ('Tomás Gil', 1, NULL, 'activo', 2),
  ('Matías Duque', 16, '3000229651', 'activo', 2),
  ('Luis Miguel Ramírez', 13, NULL, 'activo', 2),
  ('Juan David Ramírez', 26, NULL, 'activo', 2),
  ('Simón Uribe', 17, '3000253408', 'activo', 2),
  ('Manuel Quintero', 7, NULL, 'activo', 2),
  ('Jerónimo Rodríguez', 25, NULL, 'lesionado', 2),
  ('Diego Montoya', 30, '3000277165', 'activo', 2),
  ('Daniel Posada', 5, NULL, 'activo', 2),
  ('Luis Uribe', 28, NULL, 'activo', 2),
  ('Ricardo Jaramillo', 2, '3000300922', 'activo', 2),
  ('Hernán López', 10, NULL, 'lesionado', 2),
  ('Iván Castro', 22, NULL, 'activo', 2),
  ('Wilmar Londoño', 6, '3000324679', 'activo', 2),
  ('Jerónimo Patiño', 3, NULL, 'activo', 2),
  ('Óscar Díaz', 21, NULL, 'activo', 2),
  ('Steven Cano', 20, '3000348436', 'activo', 2),
  ('Steven Correa', 19, NULL, 'activo', 2),
  ('Luis Miguel Osorio', 4, NULL, 'activo', 2),
  ('Brayan Rendón', 15, '3000372193', 'activo', 2),
  ('Jerónimo Martínez', 23, NULL, 'activo', 2),
  ('Nicolás Jaramillo', 27, NULL, 'activo', 2),
  ('Luis Miguel Patiño', 11, '3000395950', 'activo', 2),
  ('Brayan Zapata', 7, '3000403869', 'activo', 3),
  ('Felipe Cano', 4, NULL, 'activo', 3),
  ('Juan Pablo Giraldo', 1, NULL, 'activo', 3),
  ('Yeison Posada', 23, '3000427626', 'activo', 3),
  ('Luis Echeverri', 14, NULL, 'activo', 3),
  ('Jhon Giraldo', 16, NULL, 'activo', 3),
  ('Nicolás Moreno', 19, '3000451383', 'activo', 3),
  ('Kevin Duque', 3, NULL, 'activo', 3),
  ('Carlos Jaramillo', 22, NULL, 'activo', 3),
  ('Hernán Montoya', 26, '3000475140', 'activo', 3),
  ('Juan Esteban Echeverri', 21, NULL, 'lesionado', 3),
  ('Jhon Salazar', 9, NULL, 'activo', 3),
  ('Brayan Salazar', 29, '3000498897', 'activo', 3),
  ('Ricardo Echeverri', 10, NULL, 'activo', 3),
  ('Matías Cardona', 13, NULL, 'activo', 3),
  ('Ricardo Gaviria', 11, '3000522654', 'activo', 3),
  ('Yeison Bedoya', 24, NULL, 'activo', 3),
  ('Julián Giraldo', 28, NULL, 'activo', 3),
  ('Manuel Cardona', 17, '3000546411', 'activo', 3),
  ('Juan Pablo Valencia', 18, NULL, 'activo', 3),
  ('Felipe Ospina', 5, NULL, 'activo', 3),
  ('Cristian Ospina', 30, '3000570168', 'activo', 3),
  ('Fabián Echeverri', 6, NULL, 'activo', 3),
  ('Brayan Quintero', 20, NULL, 'activo', 3),
  ('Daniel Montoya', 25, '3000593925', 'activo', 3),
  ('Daniel Restrepo', 11, '3000601844', 'activo', 4),
  ('Simón Mejía', 3, NULL, 'activo', 4),
  ('David Cano', 7, NULL, 'activo', 4),
  ('Samuel Restrepo', 27, '3000625601', 'activo', 4),
  ('Fabián Henao', 21, NULL, 'activo', 4),
  ('Jhon Henao', 16, NULL, 'activo', 4),
  ('Daniel Gaviria', 2, '3000649358', 'activo', 4),
  ('Wilmar Vargas', 6, NULL, 'activo', 4),
  ('Kevin Díaz', 1, NULL, 'activo', 4),
  ('Samuel Ramírez', 22, '3000673115', 'activo', 4),
  ('Matías Giraldo', 8, NULL, 'lesionado', 4),
  ('Diego Posada', 10, NULL, 'activo', 4),
  ('Alejandro Martínez', 4, '3000696872', 'activo', 4),
  ('Emmanuel Vargas', 5, NULL, 'activo', 4),
  ('Luis Giraldo', 17, NULL, 'lesionado', 4),
  ('Manuel Osorio', 9, '3000720629', 'activo', 4),
  ('Luis Miguel Hernández', 29, NULL, 'suspendido', 4),
  ('David Restrepo', 13, NULL, 'activo', 4),
  ('Yeison Castro', 25, '3000744386', 'activo', 4),
  ('Steven Martínez', 12, NULL, 'activo', 4),
  ('Steven Duque', 26, NULL, 'activo', 4),
  ('Esteban Valencia', 20, '3000768143', 'activo', 4),
  ('Wilmar Duque', 30, NULL, 'activo', 4),
  ('Brayan Escobar', 23, NULL, 'activo', 4),
  ('Luis Miguel Quintero', 18, '3000791900', 'activo', 4),
  ('Esteban Ruiz', 10, '3000799819', 'activo', 5),
  ('Miguel Ochoa', 2, NULL, 'suspendido', 5),
  ('Manuel Giraldo', 26, NULL, 'activo', 5),
  ('Juan Camilo Rodríguez', 27, '3000823576', 'activo', 5),
  ('Mateo Escobar', 19, NULL, 'activo', 5),
  ('Emmanuel Londoño', 7, NULL, 'activo', 5),
  ('David Bedoya', 12, '3000847333', 'suspendido', 5),
  ('Wilmar Vélez', 11, NULL, 'activo', 5),
  ('Nicolás Uribe', 24, NULL, 'suspendido', 5),
  ('Sebastián Patiño', 18, '3000871090', 'activo', 5),
  ('Brayan Álvarez', 6, NULL, 'activo', 5),
  ('Luis Cano', 25, NULL, 'activo', 5),
  ('Tomás Cano', 23, '3000894847', 'activo', 5),
  ('Brayan Vélez', 28, NULL, 'activo', 5),
  ('Brayan Ruiz', 30, NULL, 'activo', 5),
  ('Brayan Posada', 15, '3000918604', 'activo', 5),
  ('Sebastián Posada', 5, NULL, 'activo', 5),
  ('Luis Miguel Arboleda', 20, NULL, 'lesionado', 5),
  ('Luis Martínez', 21, '3000942361', 'activo', 5),
  ('Andrés Correa', 8, NULL, 'activo', 5),
  ('Brayan Osorio', 4, NULL, 'activo', 5),
  ('Carlos Torres', 9, '3000966118', 'activo', 5),
  ('Santiago Londoño', 14, NULL, 'activo', 5),
  ('Iván Salazar', 1, NULL, 'activo', 5),
  ('Esteban Giraldo', 17, '3000989875', 'activo', 5),
  ('Julián Torres', 9, '3000997794', 'activo', 6),
  ('Óscar Patiño', 1, NULL, 'activo', 6),
  ('Martín Díaz', 18, NULL, 'activo', 6),
  ('Camilo Moreno', 17, '3001021551', 'suspendido', 6),
  ('Juan López', 24, NULL, 'activo', 6),
  ('Martín Henao', 23, NULL, 'activo', 6),
  ('Juan Posada', 4, '3001045308', 'activo', 6),
  ('David Vélez', 30, NULL, 'activo', 6),
  ('Carlos Gómez', 27, NULL, 'activo', 6),
  ('Martín Mejía', 29, '3001069065', 'activo', 6),
  ('Matías Valencia', 13, NULL, 'activo', 6),
  ('Juan Salazar', 6, NULL, 'activo', 6),
  ('Manuel Moreno', 5, '3001092822', 'activo', 6),
  ('Luis Miguel Valencia', 14, NULL, 'lesionado', 6),
  ('Wilmar Correa', 28, NULL, 'activo', 6),
  ('Mateo Arboleda', 7, '3001116579', 'activo', 6),
  ('Juan David Tamayo', 10, NULL, 'activo', 6),
  ('Fabián Betancur', 12, NULL, 'activo', 6),
  ('Camilo Valencia', 8, '3001140336', 'activo', 6),
  ('Esteban García', 20, NULL, 'activo', 6),
  ('Tomás Restrepo', 11, NULL, 'activo', 6),
  ('Juan Camilo Arango', 15, '3001164093', 'activo', 6),
  ('Simón Cardona', 26, NULL, 'activo', 6),
  ('Duván Jaramillo', 19, NULL, 'activo', 6),
  ('Juan Camilo Escobar', 3, '3001187850', 'activo', 6),
  ('Cristian López', 6, '3001195769', 'activo', 7),
  ('Iván Correa', 5, NULL, 'lesionado', 7),
  ('Jacobo Ospina', 4, NULL, 'lesionado', 7),
  ('Wilmar Gaviria', 28, '3001219526', 'activo', 7),
  ('Jerónimo Mejía', 27, NULL, 'activo', 7),
  ('Maximiliano Bedoya', 23, NULL, 'activo', 7),
  ('Steven Henao', 18, '3001243283', 'suspendido', 7),
  ('Felipe Gaviria', 7, NULL, 'activo', 7),
  ('Santiago Henao', 13, NULL, 'activo', 7),
  ('Carlos Sánchez', 10, '3001267040', 'activo', 7),
  ('Juan Esteban Arboleda', 3, NULL, 'activo', 7),
  ('Yeison Patiño', 16, NULL, 'activo', 7),
  ('Diego Ríos', 14, '3001290797', 'activo', 7),
  ('Juan Tamayo', 19, NULL, 'activo', 7),
  ('Manuel Henao', 26, NULL, 'activo', 7),
  ('Óscar Duque', 17, '3001314554', 'activo', 7),
  ('Emmanuel Sánchez', 29, NULL, 'activo', 7),
  ('Steven Cardona', 12, NULL, 'activo', 7),
  ('Santiago Moreno', 8, '3001338311', 'activo', 7),
  ('Samuel Martínez', 15, NULL, 'activo', 7),
  ('Kevin Tamayo', 22, NULL, 'activo', 7),
  ('Ricardo Patiño', 24, '3001362068', 'activo', 7),
  ('Ricardo Posada', 21, NULL, 'activo', 7),
  ('Juan Pablo Martínez', 1, NULL, 'activo', 7),
  ('Cristian Duque', 2, '3001385825', 'activo', 7),
  ('Nicolás Duque', 7, '3001393744', 'activo', 8),
  ('Pablo Henao', 4, NULL, 'activo', 8),
  ('Jhon Álvarez', 28, NULL, 'activo', 8),
  ('Juan Esteban Agudelo', 20, '3001417501', 'activo', 8),
  ('Julián García', 24, NULL, 'lesionado', 8),
  ('Jacobo Tamayo', 25, NULL, 'suspendido', 8),
  ('Óscar Londoño', 2, '3001441258', 'activo', 8),
  ('Jerónimo Osorio', 19, NULL, 'activo', 8),
  ('Juan José García', 27, NULL, 'activo', 8),
  ('Emmanuel Agudelo', 23, '3001465015', 'activo', 8),
  ('Daniel Castro', 15, NULL, 'activo', 8),
  ('Ricardo Henao', 17, NULL, 'activo', 8),
  ('Luis Miguel Moreno', 30, '3001488772', 'activo', 8),
  ('Kevin Rodríguez', 18, NULL, 'activo', 8),
  ('Simón Echeverri', 8, NULL, 'activo', 8),
  ('Sebastián Duque', 26, '3001512529', 'activo', 8),
  ('Diego Ramírez', 12, NULL, 'activo', 8),
  ('Ricardo Betancur', 16, NULL, 'activo', 8),
  ('Nicolás Escobar', 11, '3001536286', 'activo', 8),
  ('Santiago Álvarez', 3, NULL, 'activo', 8),
  ('Steven Mejía', 29, NULL, 'activo', 8),
  ('Juan Camilo Betancur', 6, '3001560043', 'activo', 8),
  ('Kevin Osorio', 9, NULL, 'suspendido', 8),
  ('Samuel Gaviria', 14, NULL, 'activo', 8),
  ('Steven Moreno', 1, '3001583800', 'activo', 8);

INSERT INTO partido (id_partido, fecha, hora, resultado, id_sede, id_arbitro, fase, id_partido_siguiente) VALUES
  (7, '2026-12-20', '15:00', NULL,  1, 1, 'Final',     NULL),
  (5, '2026-12-13', '10:00', NULL,  1, 1, 'Semifinal', 7),
  (6, '2026-12-13', '15:00', NULL,  2, 2, 'Semifinal', 7),
  (1, '2026-12-06', '08:00', '2-1', 1, 1, 'Cuartos',   5),
  (2, '2026-12-06', '10:00', '0-1', 2, 2, 'Cuartos',   5),
  (3, '2026-12-06', '14:00', NULL,  1, 1, 'Cuartos',   6),
  (4, '2026-12-06', '16:00', NULL,  3, 3, 'Cuartos',   6);

INSERT INTO partido_equipo (id_partido, id_equipo, rol) VALUES
  (1, 1, 'local'), (1, 2, 'visitante'),
  (2, 3, 'local'), (2, 4, 'visitante'),
  (3, 5, 'local'), (3, 6, 'visitante'),
  (4, 7, 'local'), (4, 8, 'visitante');

SELECT setval('equipos_id_equipo_seq',   (SELECT MAX(id_equipo)  FROM equipos));
SELECT setval('sede_id_sede_seq',         (SELECT MAX(id_sede)    FROM sede));
SELECT setval('arbitro_id_arbitro_seq',   (SELECT MAX(id_arbitro) FROM arbitro));
SELECT setval('partido_id_partido_seq',   (SELECT MAX(id_partido) FROM partido));

COMMIT;
