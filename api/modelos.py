"""Forma que debe tener el cuerpo (JSON) de cada solicitud.

Si llega un cuerpo que no cumple estas reglas, FastAPI responde 422
automáticamente, antes de tocar la base.
"""
from datetime import date, time
from typing import Literal, Optional

from pydantic import BaseModel, Field


class EquipoIn(BaseModel):
    nombre: str = Field(min_length=1, max_length=100)
    barrio: str = Field(min_length=1, max_length=100)


class JugadorIn(BaseModel):
    nombre: str = Field(min_length=1, max_length=100)
    numero_camiseta: int = Field(ge=1, le=99)
    telefono: Optional[str] = Field(default=None, max_length=20)
    estado: Literal["activo", "lesionado", "suspendido"] = "activo"
    id_equipo: int


class SedeIn(BaseModel):
    nombre: str = Field(min_length=1, max_length=100)
    direccion: str = Field(min_length=1, max_length=150)


class ArbitroIn(BaseModel):
    nombre: str = Field(min_length=1, max_length=100)
    telefono: str = Field(min_length=7, max_length=20)


class PartidoIn(BaseModel):
    fecha: date
    hora: time
    resultado: Optional[str] = Field(default=None, pattern=r"^\d{1,2}-\d{1,2}$")
    id_sede: int
    id_arbitro: Optional[int] = None
    fase: Optional[Literal["Cuartos", "Semifinal", "Final"]] = None
    id_partido_siguiente: Optional[int] = None


class AsignarEquiposIn(BaseModel):
    id_local: int
    id_visitante: int
