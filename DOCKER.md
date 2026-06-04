# Docker Compose Reproduction

This setup keeps EvoCrawl's crawler implementation unchanged and adds a Docker Compose runtime around it. The repository's `experiments/` directory is excluded from the Docker build context.

## Prepare Configuration

Copy the example environment file and edit the target/login values:

```bash
cp .env.example .env
```

The Compose entrypoint renders `utils-evo/login_information.json` inside the container from these variables:

- `APPNAME`: application key used by EvoCrawl, for example `kanboard`
- `TARGET_URL`: login/start URL for that application
- `LOGIN_CRAWLER_USER`: main crawler user, usually admin
- `LOGIN_PASSWORD`: shared password used by the configured users
- `LOGIN_FILTER_USER`: first low-privilege user for IDOR mode
- `LOGIN_USER_B`: second low-privilege user for IDOR mode
- `LOGIN_TOKEN_USER`, `LOGIN_DETECTOR_USER`, `LOGIN_TOKEN_NAME`, `LOGIN_FOLDER`: optional EvoCrawl login fields

This keeps the repository's original `utils-evo/login_information.json` unchanged.

## Configure Login Selectors

EvoCrawl still keeps the original hardcoded login branches in `utils-evo/login.js`. For Docker Compose reproduction, you can now define a simple login profile from `.env` without editing that file:

```env
LOGIN_USERNAME_SELECTOR=input[type="text"]
LOGIN_PASSWORD_SELECTOR=input[type="password"]
LOGIN_SUBMIT_SELECTOR=button.btn-primary
LOGIN_POST_WAIT_MS=1000
```

Set all three selector variables together. Optional `LOGIN_USERNAME_NTH`, `LOGIN_PASSWORD_NTH`, and `LOGIN_SUBMIT_NTH` select the nth matched element using TestCafe's zero-based `.nth()` behavior.

When these variables are set, the entrypoint renders this profile for `APPNAME`:

1. navigate to `TARGET_URL`
2. type `LOGIN_CRAWLER_USER`, `LOGIN_FILTER_USER`, or `LOGIN_USER_B` into the username selector, depending on the current EvoCrawl user mode
3. type `LOGIN_PASSWORD` into the password selector
4. click the submit selector
5. optionally wait `LOGIN_POST_WAIT_MS`

If the selector variables are not set, EvoCrawl falls back to the existing application-specific login logic.

For multi-step logins, mount a custom JSON config and define `login_profiles`:

If you need full JSON control instead of environment-variable overrides, mount your own base file and point the renderer at it:

```yaml
services:
  evocrawl:
    environment:
      EVOCRAWL_LOGIN_CONFIG_SOURCE: /opt/evocrawl/config/login_information.json
    volumes:
      - ./config/login_information.json:/opt/evocrawl/config/login_information.json:ro
```

Example `login_profiles` section:

```json
{
  "memos": "http://host.docker.internal:5230/",
  "crawler": "admin",
  "filter": "userA",
  "userB": "userB",
  "password": "admin",
  "login_profiles": {
    "memos": {
      "steps": [
        { "action": "navigate", "url": "$url" },
        { "action": "type", "selector": "input[type=\"text\"]", "value": "$username" },
        { "action": "type", "selector": "input[type=\"password\"]", "value": "$password" },
        { "action": "click", "selector": "button.btn-primary" },
        { "action": "wait", "ms": 1000 }
      ]
    }
  }
}
```

Supported actions are `navigate`, `type`, `click`, and `wait`. Supported variable placeholders are `$url`, `$username`, and `$password`.

Do not use `localhost` for a target application unless the application runs inside the EvoCrawl container. Use one of these instead:

- `host.docker.internal` for an application running on the Docker host.
- A Compose service name, such as `http://kanboard/`, for an application attached to the same Docker network.

The default Compose file provides the MySQL 5.7 container expected by the original input-insertion detection scripts.

## Build

```bash
mkdir -p data inputs_detection/data mysql_storage
docker compose build
```

The image only needs to be rebuilt after changing the Dockerfile, dependency files, or source code copied into the image. Runtime target/login settings come from `.env`; after editing `.env`, restart with:

```bash
docker compose up -d
```

## Create A Database

For Kanboard, matching the original README example:

```bash
docker compose up -d mysql-test
docker compose exec mysql-test mysql -uroot -proot -e "CREATE DATABASE IF NOT EXISTS kanboard;"
```

Configure your target application to use:

- host: `mysql-test` when it is in the same Compose network
- user: `root`
- password: `root`
- database: the database you created

## Run EvoCrawl

```bash
docker compose up -d
```

Modes accepted by the original scripts are `Crawler`, `XSS`, and `IDOR`.

Results are written to `./data/<appname>/`. Input insertion logs are written under `./inputs_detection/data/`.

HTTP request logs are split by crawler process:

- `a_request_logs.json`: legacy simple-crawler request log.
- `a_sim_request_logs.json`: simple-crawler request log, including method, URL, headers, body, response status, response headers, and response body.
- `a_ev_request_logs.json`: evolutionary-crawler request log. State-changing traffic such as discovered POST submissions is usually here.

## Useful Commands

```bash
docker compose exec evocrawl pm2 ls
docker compose exec evocrawl screen -ls
docker compose exec evocrawl bash
docker compose up -d --force-recreate evocrawl
docker compose down
```

To disable MySQL binlog input-insertion detection:

```bash
INPUT=0 docker compose up -d
```

When `INPUT=1`, the EvoCrawl container mounts `/var/run/docker.sock` so the original `inputs_detection/c_insert.sh` can run `docker exec mysql-test` and `docker cp`. This preserves the original workflow but grants the container Docker-host control. Use `INPUT=0` if that is not acceptable.
