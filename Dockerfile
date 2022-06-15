FROM php:8.1-apache

# Install Required Depedencies
RUN apt-get update && apt-get install -y --force-yes \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libicu-dev \
    imagemagick \
    libmagickwand-dev \
    libexif-dev \
    ssl-cert \
    build-essential \
    libzip-dev \
    supervisor \
    wget \
    git \
    cron \
    vim \
    zstd \
    libzstd-dev \
    autossh \
    xfonts-base \
    xfonts-75dpi

RUN curl -L#o wkhtmltox_0.12.6-1.deb https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.stretch_amd64.deb && \
    dpkg -i wkhtmltox_0.12.6-1.deb && \
    rm -f wkhtmltox_0.12.6-1.deb

RUN mkdir -p /usr/src/php/ext/imagick \
    && git clone https://github.com/Imagick/imagick.git /usr/src/php/ext/imagick \
    && docker-php-ext-install -j$(nproc) imagick

RUN cd /usr/src/php/ext \
    && curl -fsSL https://github.com/igbinary/igbinary/archive/master.tar.gz -o igbinary.tar.gz \
    && mkdir -p igbinary \
    && tar -xf igbinary.tar.gz -C igbinary --strip-components=1 \
    && rm igbinary.tar.gz \
    && docker-php-ext-install -j$(nproc) igbinary

RUN cd /usr/src/php/ext \
    && curl -fsSL https://github.com/phpredis/phpredis/archive/5.3.4.tar.gz -o redis.tar.gz \
    && mkdir -p redis \
    && tar -xf redis.tar.gz -C redis --strip-components=1 \
    && rm redis.tar.gz \
    && docker-php-ext-configure redis --enable-redis-igbinary --enable-redis-zstd \
    && docker-php-ext-install -j$(nproc) redis \
    && docker-php-ext-enable redis

RUN cd /usr/src/php/ext \
    && git clone --recursive --depth=1 https://github.com/kjdev/php-ext-zstd.git zstd \
    && docker-php-ext-configure zstd \
    && docker-php-ext-install -j$(nproc) zstd \
    && docker-php-ext-enable zstd

RUN docker-php-ext-install -j$(nproc) gd zip pdo pdo_mysql bcmath intl pcntl \
    && curl -sS https://getcomposer.org/installer | php && mv composer.phar /usr/local/bin/composer

RUN git clone https://github.com/NoiseByNorthwest/php-spx.git \
    && cd php-spx \
    && phpize \
    && ./configure \
    && make \
    && make install \
    && echo "extension=spx.so\n\
    spx.http_enabled=1\n\
    spx.http_ip_whitelist=*\n\
    spx.http_key=\"dev\"\n\
    " >> /usr/local/etc/php/php.ini

# Configure PHP & Enabled Apache Modules
COPY .user.ini /usr/local/etc/php/
RUN cat /usr/local/etc/php/.user.ini >> /usr/local/etc/php/php.ini \
    && rm -f /usr/local/etc/php/.user.ini

RUN echo "date.timezone = Europe/London\n\
    memory_limit = 2048M\n\
    upload_max_filesize = 100M\n\
    post_max_size = 100M\n\
    max_execution_time = 120\n\
    max_input_time = 120\n\
    log_errors = On\n\
    realpath_cache_size = 4M\n\
    realpath_cache_ttl = 300\n\
    " >> /usr/local/etc/php/php.ini

ADD crontab /etc/cron.d/laravel-scheduler
RUN chmod 0644 /etc/cron.d/laravel-scheduler && \
    touch /var/log/cron.log

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

COPY supervisor/horizon.conf /etc/supervisor/conf.d/
COPY supervisor/supervisord.conf /etc/supervisor

RUN usermod -u 1000 www-data && chown -R www-data:www-data /var/www
RUN a2enmod rewrite \
    && a2enmod ssl \
    && a2enmod headers \
    && a2enmod expires \
    && a2ensite default-ssl

ENV COMPOSER_HOME=/opt/composer/config
ENV COMPOSER_CACHE_DIR=/opt/composer/cache

RUN mkdir -p /opt/composer/config \
    && mkdir /opt/composer/cache \
    && chown -R www-data:www-data /opt/composer

WORKDIR /var/www

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
