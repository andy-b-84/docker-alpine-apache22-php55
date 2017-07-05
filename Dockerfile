FROM httpd:2.4-alpine

# persistent / runtime deps
ENV PHPIZE_DEPS \
        autoconf \
        file \
        g++ \
        gcc \
        libc-dev \
        make \
        pkgconf \
        re2c \
        icu-dev \
        icu-libs
ENV APACHE2_CONF_FILE /usr/local/apache2/conf/httpd.conf
ENV PHP_INI_DIR /usr/local/etc/php
ENV PHP_SRC_DIR /usr/src/php
ENV PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2"
ENV PHP_CPPFLAGS="$PHP_CFLAGS"
ENV PHP_LDFLAGS="-Wl,-O1 -Wl,--hash-style=both -pie"

ENV PHP_VERSION 5.6.30
ENV PHP_URL="https://secure.php.net/get/php-$PHP_VERSION.tar.xz/from/this/mirror"
ENV PHP_SHA256="a363185c786432f75e3c7ff956b49c3369c3f6906a6b10459f8d1ddc22f70805" PHP_MD5="68753955a8964ae49064c6424f81eb3e"

COPY root /
COPY docker-php-source /usr/local/bin/

RUN apk add --no-cache --virtual .persistent-deps \
        ca-certificates \
        curl \
        tar \
        xz \
        \
    && mkdir -p $PHP_INI_DIR/conf.d \
    \
    && set -xe; \
    \
    apk add --no-cache --virtual .fetch-deps \
        gnupg \
        openssl \
    ; \
    \
    mkdir -p /usr/src; \
    cd /usr/src; \
    \
    wget -O php.tar.xz "$PHP_URL"; \
    \
    if [ -n "$PHP_SHA256" ]; then \
        echo "$PHP_SHA256 *php.tar.xz" | sha256sum -c -; \
    fi; \
    if [ -n "$PHP_MD5" ]; then \
        echo "$PHP_MD5 *php.tar.xz" | md5sum -c -; \
    fi; \
    \
    apk del .fetch-deps \
    && set -xe \
    && apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        curl-dev \
        libedit-dev \
        libxml2-dev \
        libressl-dev \
        sqlite-dev \
    \
    && export CFLAGS="$PHP_CFLAGS" \
        CPPFLAGS="$PHP_CPPFLAGS" \
        LDFLAGS="$PHP_LDFLAGS" \
    && docker-php-source extract \
    && cd /usr/src/php \
    && ./configure \
        --with-config-file-path="$PHP_INI_DIR" \
        --with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
        \
        --disable-cgi \
        --with-apxs2=/usr/local/apache2/bin/apxs \
        \
# --enable-ftp is included here because ftp_ssl_connect() needs ftp to be compiled statically (see https://github.com/docker-library/php/issues/236)
        --enable-ftp \
# --enable-mbstring is included here because otherwise there's no way to get pecl to use it properly (see https://github.com/docker-library/php/issues/195)
        --enable-mbstring \
        --enable-intl \
# --enable-mysqlnd is included here because it's harder to compile after the fact than extensions are (since it's a plugin for several extensions, not an extension in itself)
        --enable-mysqlnd \
        --enable-mysql=mysqlnd \
        --enable-mysqli=mysqlnd \
        --enable-pdo-mysql=mysqlnd \
        --with-pdo-mysql=mysqlnd \
        \
        --with-curl \
        --with-libedit \
        --with-openssl \
        --with-zlib \
        \
        $PHP_EXTRA_CONFIGURE_ARGS \
    && make -j "$(getconf _NPROCESSORS_ONLN)" \
    && make install \
    && { find /usr/local/bin /usr/local/sbin -type f -perm +0111 -exec strip --strip-all '{}' + || true; } \
    && make clean \
    && cp $PHP_SRC_DIR/php.ini-production $PHP_INI_DIR/php.ini \
    && mkdir -p $PHP_SRC_DIR/sapi \
    && cp -r $PHP_SRC_DIR/sapi/fpm $PHP_INI_DIR/sapi/ \
    && docker-php-source delete \
    \
    && runDeps="$( \
        scanelf --needed --nobanner --recursive /usr/local \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | sort -u \
            | xargs -r apk info --installed \
            | sort -u \
    )" \
    && apk add --no-cache --virtual .php-rundeps $runDeps \
    && pecl install apcu-4.0.11 \
    \
    && apk del .build-deps \
    \
    && sh -c "echo ''; echo ''; echo '<FilesMatch \.php$>'; echo '    SetHandler application/x-httpd-php'; echo '</FilesMatch>'; echo '';" >> $APACHE2_CONF_FILE

COPY docker-php-ext-* docker-php-entrypoint /usr/local/bin/

RUN sed -i -- 's/#LoadModule rewrite_module/LoadModule rewrite_module/' $APACHE2_CONF_FILE \
    && sed -i -- 's/#LoadModule headers_module/LoadModule headers_module/' $APACHE2_CONF_FILE \
    && sed -i -- 's/#LoadModule expires_module/LoadModule expires_module/' $APACHE2_CONF_FILE \
    && sed -i -- 's/#LoadModule deflate_module/LoadModule deflate_module/' $APACHE2_CONF_FILE

EXPOSE 80

CMD ["httpd-foreground"]
