# .colab-connect/

Puente de conexión SSH y ejecución remota entre tu máquina local / agente IA y tu instancia de **Google Colab** utilizando **Cloudflare Tunnel (`cloudflared`)**.

Permite acceder a la GPU/CPU de Google Colab directamente desde tu terminal local o permitir que el agente ejecute comandos remotos con permisos de root sobre el entorno de Colab.

---

## Cómo funciona

```
┌─────────────────────────────────┐           Cloudflare Tunnel            ┌───────────────────────────────────┐
│        Tu Mac / Agente          │      (trycloudflare.com, libre)        │           Google Colab            │
│                                 │ ─────────────────────────────────────► │                                   │
│ • scripts/.colab-connect/       │                                        │ • notebooks/utils/                │
│   ├── setup.sh                  │                                        │   colab-connect.ipynb             │
│   ├── connect.sh (ssh interact.)│                                        │ • OpenSSH Server (puerto 22)      │
│   └── run.sh (comandos remotos) │                                        │ • cloudflared daemon              │
└─────────────────────────────────┘                                        └───────────────────────────────────┘
```

1. **Google Colab** no tiene una API pública directa para encender VMs automáticamente desde la CLI (Google requiere abrir la sesión en su web).
2. Abres el notebook `notebooks/utils/colab-connect.ipynb` en Google Colab con un clic (`make open-colab-connect`).
3. Pegas tu clave pública SSH (`~/.ssh/id_rsa.pub`) en el widget y ejecutas el notebook.
4. Colab arranca OpenSSH en el puerto 22 y crea un túnel seguro con Cloudflare (`trycloudflare.com`), devolviendo una URL/hostname efímero.
5. Te conectas al instante desde tu Mac con `make connect-colab` o ejecutas comandos con `./run.sh`.

---

## Archivos

| Archivo | Propósito |
|---|---|
| `setup.sh` | Comprueba `cloudflared`, genera/detecta par de claves SSH y copia tu clave pública al portapapeles (`pbcopy`). |
| `connect.sh` | Inicia una sesión interactiva SSH en Colab mediante el túnel de Cloudflare. |
| `run.sh` | Ejecuta un comando o script remoto no interactivo en Colab (usado por ti o por el agente). |
| `.env.example` | Plantilla de configuración (rastreada en git). |
| `.env` | Credenciales locales y host activo (ignorado por git). |

---

## Guía paso a paso

### Paso 1: Configuración inicial en local

Ejecuta desde la raíz del repositorio:

```bash
make setup-colab
```

Esto:
- Instala `cloudflared` vía Homebrew si no está instalado.
- Comprueba tu par de claves SSH en `~/.ssh/id_rsa` / `~/.ssh/id_rsa.pub`.
- Copia automáticamente tu clave pública al portapapeles de macOS.
- Crea `scripts/.colab-connect/.env`.

### Paso 2: Iniciar el puente en Google Colab

Abre el notebook en Google Colab con:

```bash
make open-colab-connect
```

O ábrelo directamente en tu navegador desde GitHub.

En Colab:
1. Ejecuta la **Celda 1** (instala OpenSSH y widgets).
2. En la **Celda 3**, pega tu clave pública en el cuadro de texto y pulsa **Save Key**.
3. Ejecuta las celdas restantes (monta Drive, configura OpenSSH y levanta el túnel en la **Celda 6**).
4. Verás un mensaje como:
   ```
   🚀 COLAB SSH BRIDGE IS ACTIVE!
   Hostname: random-words-1234.trycloudflare.com
   ```
5. La **Celda 7** guardará la sesión en Google Drive (`CollabMedia/utils/colab-connect/session.json`) y mantendrá el túnel activo.

### Paso 3: Conectarse desde tu Mac

#### Opción A: Sesión interactiva en terminal (Make)

```bash
make connect-colab
```
Pega el hostname (`random-words-1234.trycloudflare.com`) cuando te lo pida. ¡Ya estás dentro de Colab con permisos de `root`!

#### Opción B: Script directo con argumento

```bash
./scripts/.colab-connect/connect.sh random-words-1234.trycloudflare.com
```

#### Opción C: Ejecutar un comando puntual (para ti o para el Agente)

```bash
# Guardando el host en scripts/.colab-connect/.env (COLAB_HOST=random-words-1234.trycloudflare.com):
./scripts/.colab-connect/run.sh "nvidia-smi"

# O pasando el host como argumento:
./scripts/.colab-connect/run.sh random-words-1234.trycloudflare.com "python3 -c 'import torch; print(torch.cuda.is_available())'"
```

---

## Integración con VS Code Remote SSH

Si deseas abrir el entorno de Colab como una ventana completa de VS Code:

Añade esto a tu `~/.ssh/config`:

```ssh-config
Host colab
    HostName random-words-1234.trycloudflare.com
    User root
    IdentityFile ~/.ssh/id_rsa
    ProxyCommand /opt/homebrew/bin/cloudflared access ssh --hostname %h
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
```

Luego en VS Code: `Cmd + Shift + P` → `Remote-SSH: Connect to Host...` → `colab`.

---

## Limitaciones conocidas

- **Persistencia:** Las sesiones de Google Colab se desconectan tras periodos prolongados de inactividad o si se cierra la pestaña del navegador. Mantén la pestaña del notebook abierta mientras trabajas.
- **Hostname efímero:** Cada vez que el runtime de Colab se reinicia, Cloudflare genera un nuevo subdominio `.trycloudflare.com`. Solo debes actualizar el hostname al reconectar.
