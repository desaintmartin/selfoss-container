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
| `<upstream short commit>` | Build of that selfoss commit, for example `3f56000a` |

The image contains:

- PHP 8.4 with Apache, `mod_rewrite` and the selfoss `.htaccess` rules.
- The PHP extensions `gd` (JPEG, PNG, WebP), `pdo_sqlite`, `pdo_pgsql`, `pdo_mysql` and `tidy`.
- The web client, built with Node.js 24.
- The same file set as the upstream release zipball.

Apache listens on port 8080 and runs as `www-data` (UID 33).

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

## Build

```sh
git clone --recurse-submodules https://github.com/desaintmartin/selfoss-docker.git
cd selfoss-docker
docker buildx build -t selfoss .
```

## License

GPL-3.0, like selfoss.
