FROM debian:jessie
MAINTAINER "jyokyoku" <jyokyoku@gmail.com>

# persistent / runtime deps
RUN set -xe \
	&& DEBIAN_FRONTEND=noninteractive apt-get update -qq \
	&& DEBIAN_FRONTEND=noninteractive apt-get install -qq -y --no-install-recommends --no-install-suggests \
		ca-certificates \
		curl \
		patch \
		libpcre3 \
		librecode0 \
		libmysqlclient-dev \
		libsqlite3-0 \
		libxml2 \
		libevent-dev \
	&& DEBIAN_FRONTEND=noninteractive apt-get purge -qq -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
	&& rm -rf /var/lib/apt/lists/*

# phpize deps
RUN set -xe \
	&& DEBIAN_FRONTEND=noninteractive apt-get update -qq \
	&& DEBIAN_FRONTEND=noninteractive apt-get install -qq -y --no-install-recommends --no-install-suggests \
		autoconf \
		file \
		g++ \
		gcc \
		libc-dev \
		make \
		pkg-config \
		re2c \
		xz-utils \
	&& DEBIAN_FRONTEND=noninteractive apt-get purge -qq -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
	&& rm -rf /var/lib/apt/lists/*

ENV PHP_INI_DIR /usr/local/etc/php
RUN mkdir -p $PHP_INI_DIR/conf.d

# compile openssl, otherwise --with-openssl won't work
RUN set -xe \
	&& OPENSSL_VERSION="1.0.2e" \
	&& cd /tmp \
	&& mkdir openssl \
	&& curl -sL "https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz" -o openssl.tar.gz \
	&& curl -sL "https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz.asc" -o openssl.tar.gz.asc \
	&& tar -xzf openssl.tar.gz -C openssl --strip-components=1 \
	&& cd /tmp/openssl \
	&& ./config \
	&& make depend \
	&& make -j"$(nproc)" \
	&& make install \
	&& rm -rf /tmp/*

ENV PHP_VERSION 5.3.3
COPY data/docker-php-source /usr/local/bin/
COPY data/php.patch /usr/src/

# php 5.3 needs older autoconf
# --enable-mysqlnd is included below because it's harder to compile after the fact the extensions are (since it's a plugin for several extensions, not an extension in itself)
RUN set -xe \
	&& buildDeps=" \
		autoconf2.13 \
		libcurl4-openssl-dev \
		libpcre3-dev \
		libreadline6-dev \
		librecode-dev \
		libsqlite3-dev \
		libssl-dev \
		libxml2-dev \
	" \
	&& DEBIAN_FRONTEND=noninteractive apt-get update -qq \
	&& DEBIAN_FRONTEND=noninteractive apt-get install -qq -y --no-install-recommends --no-install-suggests \
		${buildDeps} \
	&& DEBIAN_FRONTEND=noninteractive apt-get purge -qq -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
	&& rm -rf /var/lib/apt/lists/* \
	\
	&& mkdir -p /usr/src/php \
	&& curl -SL "https://museum.php.net/php5/php-$PHP_VERSION.tar.gz" -o /usr/src/php.tar.gz \
	&& cd /usr/src \
	&& docker-php-source extract \
	&& cd /usr/src/php \
	&& patch -p0 < ../php.patch \
	&& ./configure \
		--with-config-file-path="$PHP_INI_DIR" \
		--with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
		--enable-fpm \
		--with-fpm-user=www-data \
		--with-fpm-group=www-data \
		--disable-cgi \
		--enable-mysqlnd \
		--with-mysql=mysqlnd \
		--with-pdo-mysql=mysqlnd \
		--with-curl \
		--with-openssl=/usr/local/ssl \
		--with-readline \
		--with-recode \
		--with-zlib \
	&& make -j"$(nproc)" \
	&& make install \
	&& make clean \
	\
	&& { find /usr/local/bin /usr/local/sbin -type f -executable -exec strip --strip-all '{}' + || true; } \
	\
	&& cd / \
	&& docker-php-source delete \
	\
	&& DEBIAN_FRONTEND=noninteractive apt-get purge -qq -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false ${buildDeps} \
	&& rm -rf /var/lib/apt/lists/*

COPY data/docker-php-* /usr/local/bin/

WORKDIR /var/www/html
COPY data/php-fpm.conf /usr/local/etc/

EXPOSE 9000
CMD ["php-fpm"]
