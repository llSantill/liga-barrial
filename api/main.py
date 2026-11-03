import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from rutas import consultas, equipos, jugadores, partidos
from rutas.sedes_arbitros import arbitros, sedes

app = FastAPI(
    title="API Liga Barrial",
    description="Torneo eliminatorio de fútbol barrial: equipos, jugadores, sedes, árbitros y partidos.",
    version="1.0.0",
)

origenes = os.getenv("CORS_ORIGINS", "http://localhost:5500,http://127.0.0.1:5500").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in origenes],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(equipos.router)
app.include_router(jugadores.router)
app.include_router(sedes)
app.include_router(arbitros)
app.include_router(partidos.router)
app.include_router(consultas.router)

@app.get("/", tags=["Inicio"])
def inicio():
    return {"mensaje": "API Liga Barrial funcionando. Documentación en /docs"}
