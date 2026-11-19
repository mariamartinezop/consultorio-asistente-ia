# Asistente virtual de turnos para consultorio médico

Chatbot con inteligencia artificial que atiende a los pacientes de un consultorio médico: responde consultas frecuentes (horarios, ubicación, obras sociales) y **gestiona turnos** consultando y guardando en una base de datos. Todo el sistema corre en **contenedores Docker** dentro de una máquina virtual.

> Proyecto académico. El asistente no brinda diagnósticos ni recomienda medicación.

## Qué hace

1. El paciente escribe en una página web con un chat integrado.
2. Un agente de IA (Gemini) interpreta el mensaje y le pide los datos que faltan (nombre, motivo, día y hora, obra social).
3. Antes de confirmar, el agente **consulta en Postgres** qué horarios ya están ocupados.
4. Si el horario está libre, **guarda el turno** en la base de datos y se lo confirma al paciente.

## Arquitectura

```
Paciente ──> Página web (index.html + chat)
                    │  webhook (HTTP)
                    ▼
        ┌───────────────────────── Docker Compose ──────────────────────────┐
        │   n8n (flujo + agente IA) ──── red interna ────> PostgreSQL       │
        │         │                                          (tabla turnos) │
        └─────────┼──────────────────────────────────────────────────────────┘
                  ▼
           Gemini (API en la nube)
```

Corre sobre una VM **DietPi** en **VirtualBox**.

## Tecnologías

| Componente | Para qué se usa |
|---|---|
| VirtualBox + DietPi | Máquina virtual Linux liviana donde corre todo |
| Docker + Docker Compose | Empaquetar y levantar los servicios con un solo comando |
| n8n | Orquestación: recibe el chat, ejecuta el agente y sus herramientas |
| PostgreSQL 16 | Base de datos relacional con los turnos |
| Google Gemini | Modelo de lenguaje del agente (en la nube, no consume RAM de la VM) |
| HTML + CSS + JS | Página del consultorio con el chat embebido |

## Estructura del repositorio

```
.
├── docker-compose.yml        # Servicios: postgres y n8n
├── .env.example              # Plantilla de variables (copiar a .env)
├── schema.sql                # Crea la tabla turnos
├── workflow/
│   └── Agente consultorio.json   # Flujo de n8n exportado
├── index.html                # Página con el chat
└── README.md
```

## Cómo reproducir el proyecto

### Requisitos
- VirtualBox con una VM DietPi (imagen "VirtualBox" de dietpi.com), con 2 GB de RAM o más.
- Red de la VM en **NAT** con reenvío de puertos: `2222 -> 22` (SSH) y `5678 -> 5678` (n8n).
- Una API key de Google Gemini (aistudio.google.com).

### 1. Instalar Docker en la VM
Dentro de la VM ejecutar `dietpi-software`, buscar **Docker** y **Docker Compose**, marcarlos e instalar. Verificar:

```bash
docker --version
docker compose version
```

### 2. Clonar el repositorio y configurar las variables
```bash
git clone https://github.com/mariamartinezop/consultorio-asistente-ia.git consultorio
cd consultorio
cp .env.example .env
nano .env        # completar POSTGRES_PASSWORD y N8N_ENCRYPTION_KEY
```
Para generar una clave de cifrado aleatoria:
```bash
head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9'
```

### 3. Levantar los servicios
```bash
docker compose up -d
docker compose ps        # postgres_turnos (healthy) y n8n (Up)
```

### 4. Crear la tabla de turnos
```bash
docker exec -i postgres_turnos psql -U consultorio -d turnos_db < schema.sql
```

### 5. Configurar n8n
1. Abrir `http://localhost:5678` y crear la cuenta de administrador.
2. Crear las credenciales:
   - **Google Gemini(PaLM) Api**: pegar la API key propia.
   - **Postgres**: host `postgres`, base `turnos_db`, usuario `consultorio`, la contraseña del `.env`, puerto `5432`, SSL `disable`.
3. Importar el flujo `workflow/Agente consultorio.json` (menú `...` del flujo > Import from file) y asignar las credenciales propias a los nodos de Gemini y Postgres.
4. Verificar el nodo **Webhook**: método `POST`, path `consultorio`, respuesta mediante el nodo *Respond to Webhook* y, en **Options > Allowed Origins (CORS)**, el valor `*`.
5. Presionar **Publish**.

### 6. Abrir la página
`index.html` envía cada mensaje a `http://localhost:5678/webhook/consultorio` (POST con JSON: `chatInput` y `sessionId`). Si el path del webhook es `consultorio`, no hace falta cambiar nada: abrir `index.html` en el navegador.

Prueba rápida del webhook sin la página (PowerShell):
```powershell
Invoke-RestMethod -Method Post -Uri "http://localhost:5678/webhook/consultorio" -ContentType "application/json" -Body '{"chatInput":"Que horario atienden?","sessionId":"prueba1"}'
```

## Decisiones técnicas

- **Docker Compose en lugar de instalar todo en la VM:** el entorno es reproducible y no se ensucia el sistema. Un solo archivo levanta todo.
- **Dos servicios y una red propia:** n8n encuentra a Postgres por el nombre del servicio (`postgres`). Postgres **no expone puertos al exterior**.
- **Volúmenes:** los contenedores son efímeros; los volúmenes conservan los turnos y los flujos al reiniciar.
- **`healthcheck` + `depends_on`:** n8n arranca recién cuando Postgres está listo.
- **Variables en `.env`:** las contraseñas quedan fuera del código y del repositorio.
- **Gemini en la nube en vez de un modelo local (Ollama):** la VM tiene poca RAM y un modelo local sería lento sin GPU.
- **Postgres para los datos del negocio:** n8n guarda sus propios flujos en su base interna; los turnos van en una base separada.
- **Webhook como punto de entrada:** la página (frontend) y n8n (backend) quedan desacoplados; la página solo necesita conocer una URL y el formato del mensaje.
- **Agente con herramientas (tool calling):** el modelo decide cuándo consultar la tabla y cuándo guardar un turno. Es una forma simple de **RAG**: recupera información de Postgres antes de responder.

## Seguridad

- El archivo `.env` **no se sube** al repositorio (está en `.gitignore`).
- Las API keys se guardan cifradas en las credenciales de n8n.
- `Allowed Origins: *` es aceptable para una demo local; en producción se limita al dominio de la página.

## Mejoras futuras

Integración con WhatsApp, recordatorios automáticos 24 h antes, verificación de pacientes por DNI, historia clínica, agenda para el personal y derivación a una persona cuando el bot no pueda resolver la consulta.
