FROM debian:jessie-slim

MAINTAINER Andreas Krüger <ak@patientsky.com>

ENV php_conf /etc/php/7.1/cli/php.ini
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update \
    && apt-get install -y -q --no-install-recommends \
    apt-transport-https \
    lsb-release \
    wget \
    apt-utils \
    ca-certificates

RUN echo "deb http://packages.dotdeb.org jessie all" > /etc/apt/sources.list.d/dotdeb.list && \
    echo "deb-src http://packages.dotdeb.org jessie all" >> /etc/apt/sources.list.d/dotdeb.list && \
    wget https://www.dotdeb.org/dotdeb.gpg && apt-key add dotdeb.gpg

RUN wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg && \
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list

RUN echo 'deb http://apt.newrelic.com/debian/ newrelic non-free' | tee /etc/apt/sources.list.d/newrelic.list && \
    wget -O- https://download.newrelic.com/548C16BF.gpg | apt-key add - && \
    echo newrelic-php5 newrelic-php5/license-key string ${NEW_RELIC_LICENSE_KEY} | debconf-set-selections

RUN apt-get update \
    && apt-get install -y -q --no-install-recommends \
    php7.1-cli \
    php7.1-mysql \
    php7.1-bcmath \
    php7.1-gd \
    php7.1-curl \
    php7.1-json \
    php7.1-mcrypt \
    php7.1-cli \
    php7.1-apcu \
    php7.1-imagick \
    php7.1-intl \
    php7.1-opcache \
    php7.1-mongodb \
    php7.1-mbstring \
    php7.1-xml \
    php7.1-zip \
    php-igbinary \
    supervisor \
    openssh-client \
    git \
    && apt-get clean \
    && rm -r /var/lib/apt/lists/*

RUN [ -n "${NEW_RELIC_LICENSE_KEY}" ] && apt-get install -y -q --no-install-recommends newrelic-php5 newrelic-sysmond && apt-get clean && rm -r /var/lib/apt/lists/* || exit 0

RUN mkdir -p /var/log/supervisor

ADD conf/supervisord.conf /etc/supervisord.conf

RUN useradd -ms /bin/bash worker

# tweak php and php-cli config
RUN sed -i \
        -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" \
        -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" \
        -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" \
        -e "s/variables_order = \"GPCS\"/variables_order = \"EGPCS\"/g" \
        -e "s/;error_log\s*=\s*syslog/error_log = \/dev\/stderr/g" \
        -e "s/memory_limit\s*=\s*128M/memory_limit = 3072M/g" \
        -e "s/;date.timezone\s*=/date.timezone = Europe\/Oslo/g" \
        -e "s/max_execution_time\s*=\s*30/max_execution_time = 300/g" \
        -e "s/max_input_time\s*=\s*60/max_input_time = 300/g" \
        -e "s/default_socket_timeout\s*=\s*60/default_socket_timeout = 300/g" \
        ${php_conf}

# Cleanup some files and remove comments
RUN find /etc/php/7.1/cli/conf.d -name "*.ini" -exec sed -i -re '/^[[:blank:]]*(\/\/|#|;)/d;s/#.*//' {} \; && \
    find /etc/php/7.1/cli/conf.d -name "*.ini" -exec sed -i -re '/^$/d' {} \;

# Configure php opcode cache
RUN echo "opcache.enable=1" >> /etc/php/7.1/cli/conf.d/10-opcache.ini && \
    echo "opcache.enable_cli=1" >> /etc/php/7.1/cli/conf.d/10-opcache.ini && \
    echo "opcache.validate_timestamps=0" >> /etc/php/7.1/cli/conf.d/10-opcache.ini && \
    echo "opcache.max_accelerated_files=1000000" >> /etc/php/7.1/cli/conf.d/10-opcache.ini && \
    echo "opcache.memory_consumption=1024" >> /etc/php/7.1/cli/conf.d/10-opcache.ini && \
    echo "opcache.interned_strings_buffer=8" >> /etc/php/7.1/cli/conf.d/10-opcache.ini && \
    echo "opcache.revalidate_freq=60" >> /etc/php/7.1/cli/conf.d/10-opcache.ini

RUN [ -n "${NEW_RELIC_LICENSE_KEY}" ] && newrelic-install install || exit 0
RUN [ -n "${NEW_RELIC_LICENSE_KEY}" ] && nrsysmond-config --set license_key=${NEW_RELIC_LICENSE_KEY} || exit 0

# Add Scripts
ADD scripts/start.sh /start.sh
RUN chmod 755 /start.sh

CMD ["/start.sh"]