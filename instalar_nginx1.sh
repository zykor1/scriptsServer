#bash -e install_nginx.sh | tee install_nginx.log

# Set environment variables
APPNAME=nginx_ct2       # Name of the uWSGI Custom Application
APPPORT=8000              # Assigned port for the uWSGI Custom Application
PYTHON=python2.7           # Django python version
DJANGOPROJECT=ct2    # Django project name

mkdir -p /home/nginx/$APPNAME/{bin,nginx,src,tmp}

###########################################################
# nginx 1.2.3
# original: http://nginx.org/download/nginx-1.2.3.tar.gz
###########################################################
cd /home/nginx/$APPNAME/src
wget 'http://nginx.org/download/nginx-1.5.5.tar.gz'
tar -xzf nginx-1.5.5.tar.gz
cd nginx-1.5.5
./configure \
  --prefix=/home/nginx/$APPNAME/nginx \
  --sbin-path=/home/nginx/$APPNAME/nginx/sbin/nginx \
  --conf-path=/home/nginx/$APPNAME/nginx/nginx.conf \
  --error-log-path=/home/nginx/$APPNAME/nginx/log/nginx/error.log \
  --pid-path=/home/nginx/$APPNAME/nginx/run/nginx/nginx.pid  \
  --lock-path=/home/nginx/$APPNAME/nginx/lock/nginx.lock \
  --with-http_flv_module \
  --with-http_gzip_static_module \
  --http-log-path=/home/nginx/$APPNAME/nginx/log/nginx/access.log \
  --http-client-body-temp-path=/home/nginx/$APPNAME/nginx/tmp/nginx/client/ \
  --http-proxy-temp-path=/home/nginx/$APPNAME/nginx/tmp/nginx/proxy/ \
  --http-fastcgi-temp-path=/home/nginx/$APPNAME/nginx/tmp/nginx/fcgi/
make && make install

###########################################################
# uwsgi 1.2
# original: http://projects.unbit.it/downloads/uwsgi-1.2.tar.gz
###########################################################
cd /home/nginx/$APPNAME/src
wget 'http://projects.unbit.it/downloads/uwsgi-1.9.17.tar.gz'
tar -xzf uwsgi-1.9.17.tar.gz
cd uwsgi-1.9.17
$PYTHON uwsgiconfig.py --build
mv ./uwsgi /home/nginx/$APPNAME/bin
ln -s /home/nginx/$APPNAME/nginx/sbin/nginx /home/nginx/$APPNAME/bin

mkdir -p /home/nginx/$APPNAME/nginx/tmp/nginx/client

cat << EOF > /home/nginx/$APPNAME/nginx/nginx.conf
worker_processes  1;

events {
    worker_connections  1024;
}

http {
    access_log  /home/logs/${APPNAME}/access_${APPNAME}.log combined;
    error_log   /home/logs/${APPNAME}/error_${APPNAME}.log  crit;

    include mime.types;
    sendfile on;

    server {
        listen 198.199.120.36:${APPPORT};

        location / {
            include uwsgi_params;
            uwsgi_pass unix://home/nginx/${APPNAME}/uwsgi.sock;
        }
    }
}
EOF

cat << EOF > /home/nginx/$APPNAME/wsgi.py
import sys, os

sys.path = ['/home/django/${DJANGOPROJECT}/configuracion',
            '/home/django/${DJANGOPROJECT}',
            '/home/django/lib/${PYTHON}',
           ] + sys.path

os.environ['DJANGO_SETTINGS_MODULE'] = 'configuracion.settings'

import django.core.handlers.wsgi

application = django.core.handlers.wsgi.WSGIHandler()
EOF

# make the start, stop, and restart scripts
cat << EOF > /home/nginx/$APPNAME/bin/start
#!/bin/bash

APPNAME=${APPNAME}

# Start uwsgi
/home/nginx/\${APPNAME}/bin/uwsgi \\
  --uwsgi-socket "/home/nginx/\${APPNAME}/uwsgi.sock" \\
  --master \\
  --workers 1 \\
  --max-requests 10000 \\
  --harakiri 60 \\
  --daemonize /home/nginx/\${APPNAME}/uwsgi.log \\
  --pidfile /home/nginx/\${APPNAME}/uwsgi.pid \\
  --vacuum \\
  --python-path /home/nginx/\${APPNAME} \\
  --wsgi wsgi

# Start nginx
/home/nginx/\${APPNAME}/bin/nginx
EOF

cat << EOF > /home/nginx/$APPNAME/bin/stop
#!/bin/bash

APPNAME=${APPNAME}

# stop uwsgi
/home/nginx/\${APPNAME}/bin/uwsgi --stop /home/nginx/\${APPNAME}/uwsgi.pid

# stop nginx
kill \$(cat /home/nginx/\${APPNAME}/nginx/run/nginx/nginx.pid)
EOF

cat << EOF > /home/nginx/$APPNAME/bin/restart
#!/bin/bash

APPNAME=${APPNAME}

/home/nginx/\${APPNAME}/bin/stop
sleep 5
/home/nginx/\${APPNAME}/bin/start
EOF

chmod 755 /home/nginx/$APPNAME/bin/{start,stop,restart}