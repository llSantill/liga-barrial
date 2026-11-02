"""Consultas de negocio (JOIN y GROUP BY), reutilizadas del Trabajo de Unidad 4."""
from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends

from database import ejecutar, get_conexion

router = APIRouter(prefix="/consultas", tags=["Consultas de negocio"])


@router.get("/jugadores-activos-por-equipo")
def jugadores_activos_por_equipo(conexion=Depends(get_conexion)):
    """¿Cuántos jugadores habilitados tiene cada equipo para el próximo partido?"""
    sql = """
        SELECT e.nombre AS equipo, e.barrio,
               COUNT(j.id_jugador) AS total_jugadores_activos
        FROM equipos e
        JOIN jugadores j ON e.id_equipo = j.id_equipo
        WHERE j.estado = 'activo'
        GROUP BY e.id_equipo, e.nombre, e.barrio
        ORDER BY total_jugadores_activos DESC, e.nombre
    """
    return ejecutar(conexion, sql, modo="todos")


@router.get("/partidos-por-arbitro")
def partidos_por_arbitro(conexion=Depends(get_conexion)):
    """¿Cuántos partidos ya jugados ha dirigido cada árbitro? (para repartir y pagar)"""
    sql = """
        SELECT a.nombre AS arbitro, a.telefono,
               COUNT(p.id_partido) AS partidos_dirigidos
        FROM arbitro a
        JOIN partido p ON a.id_arbitro = p.id_arbitro
        WHERE p.resultado IS NOT NULL
        GROUP BY a.id_arbitro, a.nombre, a.telefono
        ORDER BY partidos_dirigidos DESC
    """
    return ejecutar(conexion, sql, modo="todos")


@router.get("/partidos-por-sede")
def partidos_por_sede(desde: Optional[date] = None, conexion=Depends(get_conexion)):
    """¿Cuántos partidos se juegan en cada sede desde una fecha? /consultas/partidos-por-sede?desde=2026-12-01"""
    sql = """
        SELECT s.nombre AS sede, s.direccion,
               COUNT(p.id_partido) AS total_partidos
        FROM sede s
        JOIN partido p ON s.id_sede = p.id_sede
        WHERE p.fecha >= %s
        GROUP BY s.id_sede, s.nombre, s.direccion
        ORDER BY total_partidos DESC
    """
    return ejecutar(conexion, sql, (desde or date(2000, 1, 1),), "todos")


@router.get("/llave")
def llave_del_torneo(conexion=Depends(get_conexion)):
    """Self-join sobre la relación recursiva: cada partido de cuartos, su semifinal y la final."""
    sql = """
        SELECT p1.id_partido AS partido_cuartos, p1.fecha AS fecha_cuartos,
               p2.id_partido AS pasa_a_semifinal, p2.fecha AS fecha_semifinal,
               p3.id_partido AS pasa_a_final,     p3.fecha AS fecha_final,
               s.nombre AS sede_final
        FROM partido p1
        JOIN partido p2 ON p1.id_partido_siguiente = p2.id_partido
        JOIN partido p3 ON p2.id_partido_siguiente = p3.id_partido
        JOIN sede s     ON p3.id_sede = s.id_sede
        WHERE p1.fase = 'Cuartos'
        ORDER BY p1.fecha, p1.hora
    """
    return ejecutar(conexion, sql, modo="todos")


@router.get("/resumen-equipos")
def resumen_equipos(conexion=Depends(get_conexion)):
    """Lee la vista vista_resumen_equipos (bono 2)."""
    return ejecutar(conexion, "SELECT * FROM vista_resumen_equipos ORDER BY activos DESC", modo="todos")
