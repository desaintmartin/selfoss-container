# selfoss container image

Container image for [selfoss](https://github.com/fossar/selfoss), the multipurpose RSS reader.
This repository holds the packaging only. The selfoss sources come from the `selfoss` git submodule, pinned to a commit of the upstream `master` branch.
Renovate moves the submodule to the latest upstream commit every week.

The upstream discussion is in [fossar/selfoss#1433](https://github.com/fossar/selfoss/pull/1433): the maintainer prefers a separate packaging repository.

## Image

`ghcr.io/desaintmartin/selfoss`, for `linux/amd64` and `linux/arm64`.

| Tag | Content |
|---|---|
| `latest` | Last build of the `main` branch |
| `<upstream short commit>` | Last build of that selfoss commit, for example `3f56000a` |
| `<upstream short commit>-<run>` | One build, immutable, for example `3f56000a-3`. The chart uses it as `appVersion`. |

The image contains:

- PHP 8.4 with Apache, `mod_rewrite` and the selfoss `.htaccess` rules. `memory_limit` is 512M: large feeds need more than 128M.
- The PHP extensions `gd` (JPEG, PNG, WebP), `pdo_sqlite`, `pdo_pgsql`, `pdo_mysql` and `tidy`.
- The web client, built with Node.js 24.
- The same file set as the upstream release zipball.

Apache listens on port 8080 and runs as `www-data` (UID 33).

## Patches

`patches/` holds fixes for selfoss bugs that are not yet in upstream `master`. The build applies them to `src/` with `patch -p1`.
Remove a patch when upstream has the fix.

| Patch | Bug |
|---|---|
| `0001-mark-empty-list.patch` | `POST /mark` with an empty list fails on PostgreSQL and MySQL: `IN ()` is invalid SQL. |

## Configuration

selfoss reads every setting from environment variables with the `SELFOSS_` prefix.
The variable name is the setting name in upper case, for example `db_type` becomes `SELFOSS_DB_TYPE`.
See the [configuration documentation](https://selfoss.aditu.de/docs/administration/options/) for the full list.

PostgreSQL example:

```sh
docker run -p 8080:8080 \
  -e SELFOSS_DB_TYPE=pgsql \
  -e SELFOSS_DB_HOST=postgres \
  -e SELFOSS_DB_DATABASE=selfoss \
  -e SELFOSS_DB_USERNAME=selfoss \
  -e SELFOSS_DB_PASSWORD=secret \
  -e SELFOSS_USERNAME=me \
  -e SELFOSS_PASSWORD='<hash from /password>' \
  -v selfoss-data:/var/www/html/data \
  ghcr.io/desaintmartin/selfoss:latest
```

With the default SQLite storage, the database file is in the `/var/www/html/data` volume.

## Feed updates

The image does not run cron. Run the updater on a schedule with the same image and the same configuration:

```sh
php /var/www/html/cliupdate.php
```

On Kubernetes, use a sidecar container that runs the updater in a loop, or a CronJob.
The updater writes favicons and thumbnails in `/var/www/html/data`: it needs the same volume as the web container.
The Helm chart below uses a sidecar.

## Helm chart

`oci://ghcr.io/desaintmartin/charts/selfoss`. Each build of `main` publishes a chart version `<major>.<minor>.<run number>`, with the image of the same build as `appVersion`.

The chart deploys:

- a Deployment with the web container and an updater sidecar that runs `cliupdate.php` every 15 minutes (`updater.intervalSeconds`);
- a Service, a PersistentVolumeClaim for `data/`, and an optional HTTPRoute or Ingress.

The chart has no database. Use SQLite on the volume, or point selfoss to your own PostgreSQL or MySQL server:

```yaml
config:
  db_type: pgsql
  db_host: selfoss-db-rw
  db_database: selfoss
  db_username: selfoss
# Secret with SELFOSS_DB_PASSWORD, SELFOSS_USERNAME and SELFOSS_PASSWORD.
existingSecret: selfoss
httpRoute:
  enabled: true
  parentRefs:
    - name: main
      namespace: gateway
  hostnames:
    - rss.example.com
```

```sh
helm install selfoss oci://ghcr.io/desaintmartin/charts/selfoss -f values.yaml
```

## Build

```sh
git clone --recurse-submodules https://github.com/desaintmartin/selfoss-container.git
cd selfoss-container
docker buildx build -t selfoss .
```

## License

GPL-3.0, like selfoss.
