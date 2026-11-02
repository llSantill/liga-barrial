"""CRUD de jugadores (tabla con llave foránea hacia equipos)."""
from typing import Literal, Optional

from fastapi import APIRouter, Depends

from database import ejecutar, get_conexion, no_encontrado
from modelos import JugadorIn

router = APIRouter(prefix="/jugadores", tags=["Jugadores"])

SELECT_JUGADOR = """
    SELECT j.*, e.nombre AS equipo
    FROM jugadores j
    JOIN equipos e ON e.id_equipo = j.id_equipo
"""


@router.get("")
def listar_jugadores(id_equipo: Optional[int] = None,
                     estado: Optional[Literal["activo", "lesionado", "suspendido"]] = None,
                     conexion=Depends(get_conexion)):
    """Lista jugadores. Filtros opcionales: /jugadores?id_equipo=1&estado=activo"""
    condiciones, parametros = [], []
    if id_equipo is not None:
        condiciones.append("j.id_equipo = %s")
        parametros.append(id_equipo)
    if estado is not None:
        condiciones.append("j.estado = %s")
        parametros.append(estado)
    where = (" WHERE " + " AND ".join(condiciones)) if condiciones else ""
    return ejecutar(conexion, SELECT_JUGADOR + where + " ORDER BY e.nombre, j.numero_camiseta",
                    tuple(parametros), "todos")


@router.get("/{id_jugador}")
def obtener_jugador(id_jugador: int, conexion=Depends(get_conexion)):
    fila = ejecutar(conexion, SELECT_JUGADOR + " WHERE j.id_jugador = %s", (id_jugador,), "uno")
    if fila is None:
        raise no_encontrado(f"un jugador con ID {id_jugador}")
    return fila


@router.post("", status_code=201)
def crear_jugador(j: JugadorIn, conexion=Depends(get_conexion)):
    return ejecutar(conexion,
                    """INSERT INTO jugadores (nombre, numero_camiseta, telefono, estado, id_equipo)
                       VALUES (%s, %s, %s, %s, %s) RETURNING *""",
                    (j.nombre, j.numero_camiseta, j.telefono, j.estado, j.id_equipo), "uno")


@router.put("/{id_jugador}")
def actualizar_jugador(id_jugador: int, j: JugadorIn, conexion=Depends(get_conexion)):
    # Este UPDATE dispara el trigger trg_validar_estado_jugador
    fila = ejecutar(conexion,
                    """UPDATE jugadores
                       SET nombre = %s, numero_camiseta = %s, telefono = %s, estado = %s, id_equipo = %s
                       WHERE id_jugador = %s RETURNING *""",
                    (j.nombre, j.numero_camiseta, j.telefono, j.estado, j.id_equipo, id_jugador), "uno")
    if fila is None:
        raise no_encontrado(f"un jugador con ID {id_jugador}")
    return fila


@router.delete("/{id_jugador}")
def borrar_jugador(id_jugador: int, conexion=Depends(get_conexion)):
    fila = ejecutar(conexion, "DELETE FROM jugadores WHERE id_jugador = %s RETURNING *", (id_jugador,), "uno")
    if fila is None:
        raise no_encontrado(f"un jugador con ID {id_jugador}")
    return {"mensaje": f"Jugador {fila['nombre']} borrado."}
