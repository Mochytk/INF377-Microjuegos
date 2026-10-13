# INF377-Microjuegos (ReMechón!)

## Estructura

```
Core/                       Menú, ruleta y lógica global
  scenes/ scripts/ assets/
Microgames/<juego>/         Un microjuego por carpeta
  scenes/ scripts/ assets/
```

Microjuegos: `simon_says`, `lluvia_de_notas`, `puerta`, `microondas`.
Cada microjuego es una escena raíz hija del Core y termina llamando a `end_microgame(won)` del Core.
