import os

import psycopg2
from psycopg2 import errors
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv
from fastapi import HTTPException

load_dotenv()

PARAMETROS = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": os.getenv("DB_PORT", "5432"),
    "dbname": os.getenv("DB_NAME", "liga_barrial"),
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD", ""),
}

def get_conexion():
    conexion = psycopg2.connect(**PARAMETROS)
    try:
        yield conexion
    finally:
        conexion.close()

LLAVES_FORANEAS = {
    "jugadores_id_equipo_fkey":          ("El equipo elegido no existe.",
                                          "Ese equipo tiene jugadores registrados, no se puede borrar."),
    "partido_equipo_id_equipo_fkey":     ("El equipo elegido no existe.",
                                          "Ese equipo está asignado a partidos, no se puede borrar."),
    "partido_equipo_id_partido_fkey":    ("El partido elegido no existe.",
                                          "Ese partido ya tiene equipos asignados, no se puede borrar."),
    "partido_id_sede_fkey":              ("La sede elegida no existe.",
                                          "Esa sede tiene partidos programados, no se puede borrar."),
    "partido_id_arbitro_fkey":           ("El árbitro elegido no existe.",
                                          "Ese árbitro tiene partidos asignados, no se puede borrar."),
    "partido_id_partido_siguiente_fkey": ("El partido siguiente elegido no existe.",
                                          "Otro partido de la llave pasa a este, no se puede borrar."),
}

MENSAJES = {
    "equipos_nombre_key": "Ya existe un equipo con ese nombre.",
    "arbitro_telefono_key": "Ya existe un árbitro con ese teléfono.",
    "sede_direccion_key": "Ya existe una sede con esa dirección.",
    "jugadores_id_equipo_numero_camiseta_key": "Ese número de camiseta ya lo tiene otro jugador del equipo.",
    "jugadores_numero_camiseta_check": "El número de camiseta debe estar entre 1 y 99.",
    "jugadores_estado_check": "El estado debe ser activo, lesionado o suspendido.",
    "partido_equipo_rol_check": "El rol debe ser local o visitante.",
}

def _error_409(e, por_defecto, sql=""):
    restriccion = e.diag.constraint_name
    if restriccion in LLAVES_FORANEAS:
        no_existe, tiene_relacionados = LLAVES_FORANEAS[restriccion]
        es_borrado = sql.lstrip().upper().startswith("DELETE")
        mensaje = tiene_relacionados if es_borrado else no_existe
    else:
        mensaje = MENSAJES.get(restriccion, por_defecto)
    return HTTPException(status_code=409, detail={"mensaje": mensaje, "restriccion": restriccion})

def ejecutar(conexion, sql, parametros=(), modo="ninguno"):
    try:
        with conexion.cursor(cursor_factory=RealDictCursor) as cursor:
            cursor.execute(sql, parametros)
            resultado = None
            if modo == "uno":
                resultado = cursor.fetchone()
            elif modo == "todos":
                resultado = cursor.fetchall()
        conexion.commit()
        return resultado
    except errors.ForeignKeyViolation as e:
        conexion.rollback()
        raise _error_409(e, "El dato hace referencia a un registro que no existe, o tiene registros relacionados.", sql)
    except errors.UniqueViolation as e:
        conexion.rollback()
        raise _error_409(e, "Ya existe un registro con esos datos.")
    except errors.CheckViolation as e:
        conexion.rollback()
        raise _error_409(e, "La base rechazó el dato porque no cumple una regla del torneo.")
    except errors.RaiseException as e:
        conexion.rollback()
        raise HTTPException(status_code=409, detail={"mensaje": e.diag.message_primary, "restriccion": "regla_del_motor"})
    except psycopg2.Error as e:
        conexion.rollback()
        raise HTTPException(status_code=500, detail={"mensaje": "Error inesperado en la base de datos.", "restriccion": None})

def no_encontrado(que):
    return HTTPException(status_code=404, detail={"mensaje": f"No existe {que}.", "restriccion": None})
