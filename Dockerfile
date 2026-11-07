# syntax=docker/dockerfile:1
# Container image for selfoss. The selfoss sources come from the "selfoss" git submodule.

### Stage 1: build the web client
FROM node:24.22.2-trixie-slim AS client
WORKDIR /build
RUN --mount=type=bind,source=selfoss/client/package.json,target=client/package.json \
    --mount=type=bind,source=selfoss/client/package-lock.json,target=client/package-lock.json \
    --mount=type=cache,id=npm,target=/root/.npm \
    npm ci --include=dev --prefix client/
COPY selfoss/client/ client/
RUN npm run --prefix client/ build

### Stage 2: install the PHP dependencies
FROM composer:2.9.8 AS vendor
WORKDIR /build
COPY selfoss/composer.json selfoss/composer.lock ./
RUN --mount=type=cache,id=composer,target=/tmp/cache \
    composer install --no-dev --no-interaction --no-progress --no-scripts \
      --optimize-autoloader --ignore-platform-reqs

### Stage 3: runtime
FROM php:8.4.27-apache-trixie

# Build packages are removed after the extensions compile; only the runtime libraries stay.
# selfoss reads its SELFOSS_* settings from $_ENV. The production php.ini leaves $_ENV empty ("GPCS"):
# without "E", selfoss falls back to SQLite without any error.
# The updater needs more than the 128M of php.ini-production for large feeds.
RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      libfreetype6 libjpeg62-turbo libpng16-16t64 libwebp7 libpq5 libtidy58 \
      libfreetype-dev libjpeg62-turbo-dev libpng-dev libwebp-dev libpq-dev libtidy-dev; \
    docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp; \
    docker-php-ext-install -j"$(nproc)" gd pdo_pgsql pdo_mysql tidy; \
    apt-get purge -y libfreetype-dev libjpeg62-turbo-dev libpng-dev libwebp-dev libpq-dev libtidy-dev; \
    apt-get autoremove -y; \
    rm -rf /var/lib/apt/lists/*; \
    cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"; \
    printf 'variables_order = "EGPCS"\nmemory_limit = 512M\n' > "$PHP_INI_DIR/conf.d/selfoss.ini"

# Apache listens on 8080: the container runs as www-data, which cannot bind port 80.
# selfoss routes requests through its .htaccess rewrite rules.
RUN set -eux; \
    a2enmod headers rewrite; \
    sed -ri 's/^Listen 80$/Listen 8080/' /etc/apache2/ports.conf; \
    sed -ri 's/<VirtualHost \*:80>/<VirtualHost *:8080>/' /etc/apache2/sites-available/000-default.conf; \
    printf '<Directory /var/www/html>\n  AllowOverride All\n</Directory>\n' > /etc/apache2/conf-available/selfoss.conf; \
    a2enconf selfoss

WORKDIR /var/www/html
# Same file set as the upstream release zipball (utils/create-zipball.py).
COPY --chown=www-data:www-data selfoss/src/ src/
COPY --chown=www-data:www-data selfoss/data/ data/
COPY --chown=www-data:www-data selfoss/.htaccess selfoss/index.php selfoss/run.php selfoss/cliupdate.php ./
COPY --from=vendor --chown=www-data:www-data /build/vendor/ vendor/
COPY --from=client --chown=www-data:www-data /build/public/ public/

USER www-data
EXPOSE 8080
VOLUME /var/www/html/data
