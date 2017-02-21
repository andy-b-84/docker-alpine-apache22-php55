FROM httpd:2.2-alpine

# "source" : https://github.com/docker-library/php/blob/e573f8f7fda5d7378bae9c6a936a298b850c4076/5.6/apache/Dockerfile
RUN apk update
RUN apk add 'autoconf<2.70' \
            'file<5.28' \
            'g++<5.4.0' \
            'make<4.2' \
            're2c<1.25.0' \
            'ca-certificates<20161201' \
            'curl<7.53.0' \
            'libedit<20150325.4.0' \
            'sqlite-libs<3.14.0' \
            'libxml2<2.10.0' \
            'xz<5.3.0'

ENV PHP_INI_DIR /usr/local/etc/php
RUN mkdir -p $PHP_INI_DIR/conf.d

ENV APACHE_CONFDIR /usr/local/apache2/conf

RUN touch "$APACHE_CONFDIR/extra/httpd-php.conf"

RUN { \
        echo '<FilesMatch \.php$>'; \
        echo '    SetHandler application/x-httpd-php'; \
        echo '</FilesMatch>'; \
        echo; \
        echo 'DirectoryIndex disabled'; \
        echo 'DirectoryIndex index.php index.html'; \
        echo; \
        echo '<Directory /var/www/>'; \
        echo '    Options Indexes FollowSymLinks Includes ExecCGI'; \
        echo '    AllowOverride All'; \
        echo '    Require all granted'; \
        echo '</Directory>'; \
    } | tee "$APACHE_CONFDIR/extra/httpd-php.conf"

ENV PHP_EXTRA_BUILD_DEPS apache2-dev
ENV PHP_EXTRA_CONFIGURE_ARGS --with-apxs2

ENV PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2"
ENV PHP_CPPFLAGS="$PHP_CFLAGS"
ENV PHP_LDFLAGS="-Wl,-O1 -Wl,--hash-style=both -pie"

ENV GPG_KEYS 0BD78B5F97500D450838F95DFE857D9A90D90EC1 6E4F6AB321FDC07F2C332E3AC2BF0BC433CFC8B3

ENV PHP_VERSION 5.6.30
ENV PHP_URL="http://secure.php.net/get/php-5.5.38.tar.xz/from/this/mirror" PHP_ASC_URL="https://secure.php.net/get/php-5.5.38.tar.xz.asc/from/this/mirror"
ENV PHP_SHA256="cb527c44b48343c8557fe2446464ff1d4695155a95601083e5d1f175df95580f" PHP_MD5="72302e26f153687e2ca922909f927443"


