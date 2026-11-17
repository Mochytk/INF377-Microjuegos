# INF377-Microjuegos (ReMechón!)

## Estructura

```
Core/                       Menú, ruleta y lógica global
  scenes/ scripts/ assets/
Microgames/<juego>/         Un microjuego por carpeta
  scenes/ scripts/ assets/
```

Microjuegos: uno por carpeta en `Microgames/`.
`Archivados/` guarda juegos retirados (por ahora, Puerta): no aparecen en la ruleta ni se exportan,
pero se pueden abrir y jugar sueltos en el editor. Para volver a usar uno, se mueve a `Microgames/` y
se registra en `Core/scripts/core.gd`, `Core/scripts/carrusel.gd` y `Core/scenes/core.tscn`.
Cada microjuego es una escena raíz hija del Core y termina llamando a `end_microgame(won)` del Core.
