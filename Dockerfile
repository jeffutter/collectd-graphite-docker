FROM      ubuntu
MAINTAINER Jeffery Utter "jeff@jeffutter.com"

RUN dpkg-divert --local --rename --add /sbin/initctl
RUN ln -s /bin/true /sbin/initctl

RUN echo "deb http://archive.ubuntu.com/ubuntu precise main universe" > /etc/apt/sources.list
RUN apt-get update
RUN apt-get install -y python-cairo collectd libgcrypt11 python-virtualenv build-essential python-dev supervisor sudo

RUN adduser --system --group --no-create-home collectd && adduser --system --home /opt/graphite graphite

RUN sudo -u graphite virtualenv --system-site-packages ~graphite/env

RUN echo "django >=1.3.7,<1.4 \n \
  python-memcached \n \
  django-tagging \n \
  twisted==11.1.0 \n \
  gunicorn \n \
  whisper==0.9.12 \n \
  carbon==0.9.12 \n \
  graphite-web==0.9.12" > /tmp/graphite_reqs.txt

RUN sudo -u graphite HOME=/opt/graphite /bin/sh -c ". ~/env/bin/activate && pip install -r /tmp/graphite_reqs.txt"

ADD collectd/collectd.conf /etc/collectd/
ADD supervisor/ /etc/supervisor/conf.d/
ADD graphite/local_settings.py /opt/graphite/webapp/graphite/
ADD graphite/wsgi.py /opt/graphite/webapp/graphite/
ADD graphite/mkadmin.py /opt/graphite/webapp/graphite/
ADD graphite/carbon.conf /opt/graphite/conf/
ADD graphite/storage-schemas.conf /opt/graphite/conf/

RUN cp /opt/graphite/conf/storage-aggregation.conf.example /opt/graphite/conf/storage-aggregation.conf

RUN sed -i "s#^\(SECRET_KEY = \).*#\1\"`python -c 'import os; import base64; print(base64.b64encode(os.urandom(40)))'`\"#" /opt/graphite/webapp/graphite/app_settings.py
RUN sudo -u graphite HOME=/opt/graphite PYTHONPATH=/opt/graphite/lib/ /bin/sh -c "cd ~/webapp/graphite && ~/env/bin/python manage.py syncdb --noinput"
RUN sudo -u graphite HOME=/opt/graphite PYTHONPATH=/opt/graphite/lib/ /bin/sh -c "cd ~/webapp/graphite && ~/env/bin/python mkadmin.py"

CMD exec supervisord -n
