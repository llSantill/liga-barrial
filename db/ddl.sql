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
