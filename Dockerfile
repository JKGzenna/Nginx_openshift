FROM centos/s2i-core-centos7
MAINTAINER Juan Luis Goldaracena

ENV nginxversion="1.12.2-1" \
    os="centos" \
    osversion="7" \
    elversion="7_4"

ENV NGINX_CONFIGURATION_VHOST_PATH="/etc/nginx/conf.d" \
    NGINX_CONFIGURATION_PATH="/etc/nginx" \
    NGINX_DEFAULT_CONF_PATH="/etc/nginx.default.d" \
    NGINX_DEFAULT_CONF_LOG_PATH="/var/log/nginx" \
    NGINX_SSL_CERTS_PATH="/etc/nginx/ssl" \
    VAR_RUN_PATH="/var/run" \
    NGINX_VAR_CACHE_PATH="/var/cache/nginx"

RUN yum install -y wget openssl sed &&\
    yum -y autoremove &&\
    yum clean all &&\
    wget http://nginx.org/packages/$os/$osversion/x86_64/RPMS/nginx-$nginxversion.el$elversion.ngx.x86_64.rpm &&\
    rpm -iv nginx-$nginxversion.el$elversion.ngx.x86_64.rpm

# Copy app files and nginx configuration
RUN mkdir -p ${NGINX_SSL_CERTS_PATH}

#ADD ssl/* "${NGINX_SSL_CERTS_PATH}/"
ADD vhosts/*  "${NGINX_CONFIGURATION_VHOST_PATH}/"
ADD nginx.conf "${NGINX_CONFIGURATION_PATH}/"

# Fix permissions
RUN chmod g+rwx ${NGINX_VAR_CACHE_PATH} ${VAR_RUN_PATH} ${NGINX_DEFAULT_CONF_LOG_PATH} && \
    chmod 777 ${NGINX_DEFAULT_CONF_LOG_PATH} && \
    rm -rf /var/log/nginx/error.log && \
    rm -rf /var/log/nginx/access.log 

# Forward request and error logs to Openshift log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

#RUN addgroup nginx root

# Expose Port clientesapp
EXPOSE 8448

# User
USER 10001

WORKDIR ${NGINX_CONFIGURATION_PATH}

CMD ["nginx", "-g", "daemon off;"]
