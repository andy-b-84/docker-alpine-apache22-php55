FROM httpd:2.2-alpine

RUN /usr/local/apache2/bin/apachectl stop

# persistent / runtime deps
ENV PHPIZE_DEPS \
		autoconf \
		file \
		g++ \
		gcc \
		libc-dev \
		make \
		pkgconf \
		re2c
RUN apk add --no-cache --virtual .persistent-deps \
		ca-certificates \
		curl \
		tar \
		xz

ENV PHP_INI_DIR /etc/php5/apache2
RUN mkdir -p $PHP_INI_DIR/conf.d

##<autogenerated>##
##</autogenerated>##

# Apply stack smash protection to functions using local buffers and alloca()
# Make PHP's main executable position-independent (improves ASLR security mechanism, and has no performance impact on x86_64)
# Enable optimization (-O2)
# Enable linker optimization (this sorts the hash buckets to improve cache locality, and is non-default)
# Adds GNU HASH segments to generated executables (this is used if present, and is much faster than sysv hash; in this configuration, sysv hash is also generated)
# https://github.com/docker-library/php/issues/272
ENV PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2"
ENV PHP_CPPFLAGS="$PHP_CFLAGS"
ENV PHP_LDFLAGS="-Wl,-O1 -Wl,--hash-style=both -pie"

ENV GPG_KEYS 0BD78B5F97500D450838F95DFE857D9A90D90EC1 6E4F6AB321FDC07F2C332E3AC2BF0BC433CFC8B3

ENV PHP_VERSION 5.5.38
ENV PHP_URL="https://secure.php.net/get/php-$PHP_VERSION.tar.xz/from/this/mirror" PHP_ASC_URL="https://secure.php.net/get/php-$PHP_VERSION.tar.xz.asc/from/this/mirror"
ENV PHP_SHA256="cb527c44b48343c8557fe2446464ff1d4695155a95601083e5d1f175df95580f" PHP_MD5="72302e26f153687e2ca922909f927443"

RUN set -xe; \
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
	if [ -n "$PHP_ASC_URL" ]; then \
		wget -O php.tar.xz.asc "$PHP_ASC_URL"; \
		export GNUPGHOME="$(mktemp -d)"; \
		for key in $GPG_KEYS; do \
			gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
		done; \
		gpg --batch --verify php.tar.xz.asc php.tar.xz; \
		rm -r "$GNUPGHOME"; \
	fi; \
	\
	apk del .fetch-deps

COPY docker-php-source /usr/local/bin/

RUN set -xe \
	&& apk add --no-cache --virtual .build-deps \
		$PHPIZE_DEPS \
		curl-dev \
		libedit-dev \
		libxml2-dev \
		openssl-dev \
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
		\
# --enable-ftp is included here because ftp_ssl_connect() needs ftp to be compiled statically (see https://github.com/docker-library/php/issues/236)
		--enable-ftp \
# --enable-mbstring is included here because otherwise there's no way to get pecl to use it properly (see https://github.com/docker-library/php/issues/195)
		--enable-mbstring \
# --enable-mysqlnd is included here because it's harder to compile after the fact than extensions are (since it's a plugin for several extensions, not an extension in itself)
		--enable-mysqlnd \
		\
		--with-curl \
		--with-libedit \
		--with-openssl \
		--with-zlib \
		\
        --with-mysql \
        --with-mysqli \
        --with-pdo-mysql \
        \
        --with-apxs2=/usr/local/apache2/bin/apxs \
        \
		$PHP_EXTRA_CONFIGURE_ARGS \
	&& make -j "$(getconf _NPROCESSORS_ONLN)" \
	&& make install \
	&& { find /usr/local/bin /usr/local/sbin -type f -perm +0111 -exec strip --strip-all '{}' + || true; } \
	&& make clean \
	&& docker-php-source delete \
	\
	&& runDeps="$( \
		scanelf --needed --nobanner --recursive /usr/local \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| sort -u \
			| xargs -r apk info --installed \
			| sort -u \
	)" \
	&& apk add --no-cache --virtual .php-rundeps $runDeps

RUN yes "" | pecl install apcu-4.0.11 -R /usr/local/lib/php/extensions/no-debug-non-zts-20121212
RUN yes "" | pecl install mongodb -R /usr/local/lib/php/extensions/no-debug-non-zts-20121212
	
RUN apk del .build-deps

COPY docker-php-ext-* docker-php-entrypoint /usr/local/bin/

ADD root /

#RUN ln -sf /dev/stdout /var/log/apache2/access.log && \
#    ln -sf /dev/stderr /var/log/apache2/error.log

EXPOSE 80
CMD ["httpd-foreground"]
