from typing import Literal, Optional

from fastapi import APIRouter, Depends

from database import ejecutar, get_conexion, no_encontrado
from modelos import AsignarEquiposIn, PartidoIn

router = APIRouter(prefix="/partidos", tags=["Partidos"])

SELECT_PARTIDO = """
    SELECT p.*,
           s.nombre AS sede,
           a.nombre AS arbitro,
           (SELECT e.nombre FROM partido_equipo pe JOIN equipos e ON e.id_equipo = pe.id_equipo
             WHERE pe.id_partido = p.id_partido AND pe.rol = 'local')     AS local,
           (SELECT e.nombre FROM partido_equipo pe JOIN equipos e ON e.id_equipo = pe.id_equipo
             WHERE pe.id_partido = p.id_partido AND pe.rol = 'visitante') AS visitante
    FROM partido p
    JOIN sede s         ON s.id_sede = p.id_sede
    LEFT JOIN arbitro a ON a.id_arbitro = p.id_arbitro
"""

CAMPOS = "fecha, hora, resultado, id_sede, id_arbitro, fase, id_partido_siguiente"

def _valores(p: PartidoIn):
    return (p.fecha, p.hora, p.resultado, p.id_sede, p.id_arbitro, p.fase, p.id_partido_siguiente)

@router.get("")
def listar_partidos(fase: Optional[Literal["Cuartos", "Semifinal", "Final"]] = None,
                    conexion=Depends(get_conexion)):
    if fase:
        return ejecutar(conexion, SELECT_PARTIDO + " WHERE p.fase = %s ORDER BY p.fecha, p.hora",
                        (fase,), "todos")
    return ejecutar(conexion, SELECT_PARTIDO + " ORDER BY p.fecha, p.hora", modo="todos")

@router.get("/{id_partido}")
def obtener_partido(id_partido: int, conexion=Depends(get_conexion)):
    fila = ejecutar(conexion, SELECT_PARTIDO + " WHERE p.id_partido = %s", (id_partido,), "uno")
    if fila is None:
        raise no_encontrado(f"un partido con ID {id_partido}")
    return fila

@router.post("", status_code=201)
def crear_partido(p: PartidoIn, conexion=Depends(get_conexion)):
    return ejecutar(conexion,
                    f"INSERT INTO partido ({CAMPOS}) VALUES (%s, %s, %s, %s, %s, %s, %s) RETURNING *",
                    _valores(p), "uno")

@router.put("/{id_partido}")
def actualizar_partido(id_partido: int, p: PartidoIn, conexion=Depends(get_conexion)):
    fila = ejecutar(conexion,
                    """UPDATE partido SET fecha = %s, hora = %s, resultado = %s, id_sede = %s,
                       id_arbitro = %s, fase = %s, id_partido_siguiente = %s
                       WHERE id_partido = %s RETURNING *""",
                    _valores(p) + (id_partido,), "uno")
    if fila is None:
        raise no_encontrado(f"un partido con ID {id_partido}")
    return fila

@router.delete("/{id_partido}")
def borrar_partido(id_partido: int, conexion=Depends(get_conexion)):
    fila = ejecutar(conexion, "DELETE FROM partido WHERE id_partido = %s RETURNING *", (id_partido,), "uno")
    if fila is None:
        raise no_encontrado(f"un partido con ID {id_partido}")
    return {"mensaje": f"Partido {id_partido} borrado."}

@router.post("/{id_partido}/equipos")
def asignar_equipos(id_partido: int, datos: AsignarEquiposIn, conexion=Depends(get_conexion)):
    obtener_partido(id_partido, conexion)
    fila = ejecutar(conexion, "SELECT asignar_equipos_partido(%s, %s, %s) AS mensaje",
                    (id_partido, datos.id_local, datos.id_visitante), "uno")
    return fila
