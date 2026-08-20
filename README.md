# DDT

Сторонний web-клиент для Exchange. Backend работает на FastAPI, данные
хранятся в MySQL, frontend собран на Flutter Web.

## Как устроен production

- Caddy принимает публичный HTTP/HTTPS-трафик и автоматически получает TLS-
  сертификат Let's Encrypt.
- Nginx раздаёт локально собранный Flutter bundle и проксирует `/api/` в
  FastAPI.
- Backend и MySQL доступны только во внутренней Docker-сети.
- MySQL хранит данные в именованном Docker volume `ddt_mysql_data`.
- Перед каждым обновлением создаётся сжатый `mysqldump`, затем применяются
  только ещё не выполненные SQL-миграции.
- GitHub Actions разворачивает только commit, появившийся после merge pull
  request в `production`. Открытие и обновление PR запускает проверки, но не
  меняет работающий сервер.

Production-конфигурация находится в `compose.production.yml`. Локальная
разработка продолжает использовать `docker-compose.yml`.

## Локальная сборка frontend

Production bundle намеренно не собирается на GitHub runner или VPS. Его нужно
создавать на компьютере разработчика:

```bash
./scripts/build-frontend-release.sh
git add deploy/artifacts frontend
git commit -m "Update production frontend bundle"
```

Скрипт:

1. выполняет `flutter pub get`;
2. собирает web release с same-origin API (`API_URL` пустой, запросы идут на
   `/api/...`);
3. сохраняет `deploy/artifacts/frontend-web.tar.gz` в GitHub-репозитории;
4. сохраняет checksum архива и hash всех отслеживаемых frontend-исходников.

Если исходники frontend изменились, а bundle не обновлён, PR и deployment
завершатся ошибкой. Проверить bundle вручную можно командой:

```bash
./scripts/verify-frontend-release.sh
```

Архив должен оставаться меньше лимита одного файла GitHub (100 MiB). Если он
приблизится к лимиту, следует перенести этот файл в Git LFS, не меняя путь
артефакта.

Для локального `flutter run`, когда backend слушает порт 3000:

```bash
cd frontend
flutter run -d chrome --dart-define=API_URL=http://localhost:3000
```

## Подготовка VPS

Ниже приведён пример для чистого Ubuntu 24.04. Нужны публичный IPv4/IPv6,
домен и пользователь с `sudo`.

### 1. DNS и firewall

Создайте A-запись домена, например `ddt.example.com`, указывающую на IPv4 VPS.
Если используется IPv6, добавьте AAAA-запись. Дождитесь обновления DNS.

Откройте только SSH, HTTP и HTTPS:

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 443/udp
sudo ufw enable
```

Порты MySQL и FastAPI наружу production Compose не публикует.

### 2. Docker Engine и Compose plugin

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo docker run --rm hello-world
```

### 3. Отдельный пользователь деплоя

```bash
sudo adduser --disabled-password --gecos "" deploy
sudo usermod -aG docker deploy
sudo mkdir -p /opt/ddt/{incoming,releases,shared/backups}
sudo chown -R deploy:deploy /opt/ddt
```

Членство в группе `docker` фактически даёт root-доступ. Поэтому ключ этого
пользователя должен быть отдельным и использоваться только данным repository.

На компьютере разработчика создайте ключ без passphrase для GitHub Actions:

```bash
ssh-keygen -t ed25519 -C "github-actions-ddt" \
  -f ~/.ssh/ddt_github_actions
ssh-copy-id -i ~/.ssh/ddt_github_actions.pub deploy@VPS_IP
```

Проверьте вход:

```bash
ssh -i ~/.ssh/ddt_github_actions deploy@VPS_IP \
  'docker version && docker compose version'
```

### 4. Production environment

Скопируйте шаблон на сервер:

```bash
scp deploy/.env.production.example deploy@VPS_IP:/opt/ddt/shared/.env
ssh deploy@VPS_IP 'chmod 600 /opt/ddt/shared/.env'
```

Откройте `/opt/ddt/shared/.env` на VPS и обязательно замените:

- `APP_DOMAIN` — домен без `https://`;
- `MYSQL_PASSWORD` и `MYSQL_ROOT_PASSWORD` — разные длинные случайные пароли;
- `EWS_CREDENTIALS_KEY` — постоянный Fernet key.

Ключ можно создать так:

```bash
openssl rand 32 | openssl base64 -A | tr '+/' '-_'
```

`EWS_CREDENTIALS_KEY` нельзя менять после появления сохранённых EWS-аккаунтов:
старые логины и пароли перестанут расшифровываться. Файл `.env` не следует
добавлять в git или GitHub Secrets целиком; он хранится только на VPS и
переживает смену release.

## Настройка GitHub

В repository откройте **Settings → Environments → New environment** и создайте
environment `production`. При необходимости включите required reviewers — это
добавит ручное подтверждение перед реальным деплоем.

В environment `production` добавьте secrets:

| Secret | Значение |
| --- | --- |
| `VPS_HOST` | IP или DNS-имя VPS |
| `VPS_USER` | `deploy` |
| `VPS_SSH_PRIVATE_KEY` | полное содержимое `~/.ssh/ddt_github_actions` |
| `VPS_SSH_KNOWN_HOSTS` | проверенная строка host key VPS |

Получить строку known hosts можно на локальном компьютере:

```bash
ssh-keyscan -H -p 22 VPS_IP
```

Перед сохранением сравните fingerprint с результатом
`ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub` в консоли VPS-провайдера.
Не используйте `StrictHostKeyChecking=no`.

Добавьте environment variables:

| Variable | Значение |
| --- | --- |
| `DEPLOY_PATH` | `/opt/ddt` |
| `VPS_SSH_PORT` | `22` или фактический SSH-порт |
| `APP_URL` | публичный URL, например `https://ddt.example.com` |

GitHub обрабатывает событие `pull_request` только для workflow, который уже
есть в default branch. Поэтому перед включением обязательных PR-проверок один
раз добавьте `.github/workflows/pull-request.yml` в default branch (`main`) —
например, отдельным bootstrap PR. Workflow deployment должен находиться в
`production`; первый push, который добавит его в эту ветку, уже сможет
запуститься.

После bootstrap в **Settings → Branches → Branch protection rules** защитите
`production`:

1. разрешите изменения только через pull request;
2. потребуйте успешный status check `validate`;
3. запретите force push;
4. при необходимости потребуйте review.

## Процесс релиза

1. Обновите код в рабочей ветке.
2. Если затронут frontend, выполните
   `./scripts/build-frontend-release.sh` и добавьте все три файла из
   `deploy/artifacts/` в commit.
3. Создайте PR в `production`.
4. Workflow **Pull request checks** проверит Python, Flutter, bundle и Compose.
5. После merge workflow **Deploy production** упакует merged commit, передаст
   его по SSH и запустит deployment.
6. Caddy получит/обновит TLS-сертификат; приложение станет доступно по
   `https://APP_DOMAIN`.

Повторный `synchronize` PR не деплоит незаревьюенный код. Технический триггер
deployment — `push` в защищённую `production`: merge PR создаёт именно такой
push. Прямые push запрещаются branch protection, поэтому незаревьюенный код
не попадёт на VPS. После запуска контейнеров workflow дополнительно проверяет
`APP_URL` снаружи сервера.

## Миграции базы данных

Миграции лежат в `database/migrations` и выполняются в порядке версий:

```text
V1__initial_schema.sql
V2__reconcile_legacy_schema.sql
V3__next_change.sql
```

Правила:

- уже применённый файл нельзя изменять: checksum хранится в таблице
  `schema_migrations`, и deployment остановится при несовпадении;
- каждое изменение схемы создаёт новый `V<N>__description.sql`;
- migration должна быть совместима и со старой, и с новой версией backend;
- удаление/переименование колонок выполняется отдельным поздним релизом по
  схеме expand → migrate data → switch code → contract;
- MySQL DDL не гарантирует полный transaction rollback, поэтому deployment
  всегда делает backup **до** миграций.

При локальном `docker compose up` используется тот же migration runner.
Миграции больше не выполняются неявно при запуске FastAPI.

Backup хранится 14 дней:

```text
/opt/ddt/shared/backups/ddt-YYYYMMDDTHHMMSSZ.sql.gz
```

Если migration завершилась ошибкой, новая версия приложения не запускается.
Скрипт пытается вернуть предыдущие контейнеры, но схему автоматически назад не
откатывает. Сначала изучите ошибку и только при необходимости восстанавливайте
backup в maintenance window:

```bash
cd /opt/ddt/current
docker compose --project-name ddt \
  --env-file /opt/ddt/shared/.env \
  -f compose.production.yml stop backend

gunzip -c /opt/ddt/shared/backups/BACKUP.sql.gz | \
  docker compose --project-name ddt \
    --env-file /opt/ddt/shared/.env \
    -f compose.production.yml exec -T mysql \
    sh -c 'exec mysql --user=root --password="$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"'

docker compose --project-name ddt \
  --env-file /opt/ddt/shared/.env \
  -f compose.production.yml up -d backend frontend caddy
```

Восстановление backup удаляет данные, появившиеся после его создания; перед
этим обязательно сохраните текущую БД отдельным dump.

## Диагностика на VPS

```bash
cd /opt/ddt/current
docker compose --project-name ddt \
  --env-file /opt/ddt/shared/.env \
  -f compose.production.yml ps

docker compose --project-name ddt \
  --env-file /opt/ddt/shared/.env \
  -f compose.production.yml logs --tail=200 backend frontend caddy mysql

curl -fsS https://YOUR_DOMAIN/api/health
```

Rollback кода можно выполнить запуском Compose из предыдущей директории
`/opt/ddt/releases/<commit>`. Перед rollback убедитесь, что старая версия
backend совместима с уже применённой схемой.
