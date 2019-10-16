FROM centos:centos7.6.1810

ENV LB_VERSION 2.0.2

ENV NGINX_VERSION 1.17.4
ENV VTS_VERSION 0.1.18
ENV STREAM_STS_VERSION 0.1.1
ENV STS_VERSION 0.1.1
ENV FCRON_VERSION 3.2.1

RUN groupadd --system nginx \
  && adduser --system --home /var/cache/nginx --shell /sbin/nologin -g nginx nginx \
  && yum install epel-release -y \
  && yum install -y \
  		gcc \
  		glibc-devel \
  		make \
  		openssl-devel \
  		pcre-devel \
  		zlib-devel \
  		kernel-headers \
  		curl \
  		libxslt-devel \
  		gd-devel \
  		perl-devel \
  		perl-ExtUtils-Embed \
  		logrotate \
  		gettext \
  		pax-utils \
  		htop \
  		tzdata
RUN curl -fSL https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz \ 
  && curl -fSL https://github.com/vozlt/nginx-module-vts/archive/v$VTS_VERSION.tar.gz  -o nginx-modules-vts.tar.gz \
  && curl -fSL https://github.com/vozlt/nginx-module-stream-sts/archive/v$STREAM_STS_VERSION.tar.gz  -o nginx-modules-stream-sts.tar.gz \
  && curl -fSL https://github.com/vozlt/nginx-module-sts/archive/v$STS_VERSION.tar.gz  -o nginx-modules-sts.tar.gz \
  && mkdir -p /usr/src \
	&& tar -zxC /usr/src -f nginx.tar.gz \
	&& tar -zxC /usr/src -f nginx-modules-vts.tar.gz \
	&& tar -zxC /usr/src -f nginx-modules-sts.tar.gz \
	&& tar -zxC /usr/src -f nginx-modules-stream-sts.tar.gz \
	&& rm nginx.tar.gz nginx-modules-vts.tar.gz nginx-modules-sts.tar.gz nginx-modules-stream-sts.tar.gz \
  && cd /usr/src/nginx-$NGINX_VERSION \
  && ./configure --prefix=/etc/nginx \
      --sbin-path=/usr/sbin/nginx \
      --modules-path=/usr/lib/nginx/modules \
      --conf-path=/etc/nginx/nginx.conf \
      --error-log-path=/var/log/nginx/error.log \
      --http-log-path=/var/log/nginx/access.log \
      --pid-path=/var/run/nginx.pid \
      --lock-path=/var/run/nginx.lock \
      --user=nginx \
      --group=nginx \
      --with-http_ssl_module \
      --with-http_realip_module \
      --with-http_addition_module \
      --with-stream \
      --with-http_gunzip_module \
      --with-http_gzip_static_module \
      --with-stream_ssl_module \
      --with-stream_ssl_preread_module \
      --with-stream_realip_module \
      --with-http_slice_module \
      --with-http_perl_module \
      --with-compat \
      --with-http_v2_module \
      --add-module=/usr/src/nginx-module-vts-$VTS_VERSION \
      --add-module=/usr/src/nginx-module-sts-$STS_VERSION \
      --add-module=/usr/src/nginx-module-stream-sts-$STREAM_STS_VERSION \
      --with-ld-opt="-Wl,-E" \
  && make -j$(getconf _NPROCESSORS_ONLN) \
  && make install \
  && rm -rf /etc/nginx/html/ \
  && mkdir /etc/nginx/conf.d/ \
  && mkdir -p /usr/share/nginx/html/ \
  && install -m644 /usr/src/nginx-$NGINX_VERSION/html/index.html /usr/share/nginx/html/ \
  && install -m644 /usr/src/nginx-$NGINX_VERSION/html/50x.html /usr/share/nginx/html/ \
  && strip /usr/sbin/nginx* \
  && rm -rf /usr/src/nginx-$NGINX_VERSION \
  \
  && mv /usr/bin/envsubst /tmp/ \
  \
  && runDeps="$( \
  		scanelf --needed --nobanner --format '%n#p' /usr/sbin/nginx /tmp/envsubst \
  			| tr ',' '\n' \
  			| sort -u \
  			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
  )" \
  && mv /tmp/envsubst /usr/local/bin/ \
  \
  && ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log

RUN curl -fSL http://fcron.free.fr/archives/fcron-$FCRON_VERSION.src.tar.gz -o fcron.tar.gz \
  && mkdir -p /usr/src \
	&& tar -zxC /usr/src -f fcron.tar.gz \
	&& rm fcron.tar.gz \
  && cd /usr/src/fcron-$FCRON_VERSION \
  && ./configure \
    --prefix=/usr \
    --sysconfdir=/etc \
    --with-sendmail=no \
  && make -j$(getconf _NPROCESSORS_ONLN) \
  && make install \
  && rm -rf /usr/src/fcron-$FCRON_VERSION

RUN yum erase -y gcc \
      glibc-devel \
      make \
      openssl-devel \
      pcre-devel \
      zlib-devel \
      kernel-headers \
      libxslt-devel \
      gd-devel \
      perl-devel \
      gettext \
  && yum clean all \
  && rm -rf /var/cache/yum


COPY nginx.conf /etc/nginx/nginx.conf
COPY conf.d/vts.conf /etc/nginx/conf.d/vts.conf
COPY sudoers.d/reload /etc/sudoers.d/reload
COPY etc/logrotate.d/nginx /etc/logrotate.d/nginx

RUN fcron -b -l 5

EXPOSE 80 443

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]
