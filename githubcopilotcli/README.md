# Cupgemini — Plugin Marketplace

> Colección de plugins para **GitHub Copilot CLI** organizados por área tecnológica. Instala el plugin de tu stack y empieza a trabajar con agentes y skills especializados desde el primer día.


## ¿Qué es esto?

Un **marketplace de plugins** desarrollado por Cupgemini que extiende las capacidades de GitHub Copilot CLI con agentes, skills e instrucciones especializadas para cada stack tecnológico.

Cada plugin agrupa en una sola unidad instalable:
- 🤖 **Custom Agents** con roles definidos (arquitecto, desarrollador, documentador...)
- 🛠️ **Skills** especializadas que se activan automáticamente según el contexto
- 📚 **References** con guías, convenciones y patrones de cada dominio

Un plugin instalado una vez está disponible en GitHub Copilot CLI y en VS Code en modo agente.


## Plugins disponibles

| Plugin | Stack | Agentes | Skills |
|--------|-------|---------|--------|
| [power-platform-dataverse](plugins/power-platform-dataverse/README.md) | Power Platform · Dataverse · Dynamics 365 | 3 | 9 |
| [salesforce](plugins/salesforce/README.md) | Salesforce · Apex · LWC · SFDX | — | — |

> ¿Tu stack no está aquí? Consulta la sección [Contribuir](#contribuir) para añadir un plugin.

---

## Instalación rápida

```bash
# 1. Registrar el marketplace
copilot
> /plugin marketplace add FranFdezColoma/Cupgemini-marketplace

# 2. Instalar el plugin de tu stack
> /plugin install power-platform-dataverse@Cupgemini-marketplace

# 3. Verificar
> /plugin list
```

## ¿Nuevo en GitHub Copilot CLI?

Si es tu primera vez usando el CLI como agente autónomo, empieza por la guía de developers:

**[📖 Guía de Developers →](guia-developers/README.md)**

La guía cubre desde la instalación hasta la configuración de MCP servers, con ejemplos reales para cada concepto.


## Contribuir

¿Quieres añadir un plugin para tu stack?

1. Crea una carpeta en `plugins/<nombre-del-stack>/`
2. Sigue la estructura del [plugin de referencia](plugins/power-platform-dataverse/)
3. Añade tu plugin a la tabla de esta página
4. Abre un Pull Request

**Estructura mínima de un plugin:**

```
plugins/mi-stack/
├── .claude-plugin/
│   └── plugin.json          ← Metadata (name, version, keywords)
├── agents/                  ← Custom Agents (.agent.md)
├── skills/                  ← Skills (subdirectorios con SKILL.md)
├── references/              ← Documentación de referencia
└── README.md                ← Descripción del plugin
```

---

## Licencia

MIT License — Cupgemini
