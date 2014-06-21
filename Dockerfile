FROM       ubuntu:trusty
MAINTAINER Abe Voelker <abe@abevoelker.com>

ENV VERSION 1.0

# Ignore APT warnings about not having a TTY
ENV DEBIAN_FRONTEND noninteractive

# Ensure UTF-8 locale
ADD locale /etc/default/locale
RUN locale-gen en_US.UTF-8 &&\
  dpkg-reconfigure locales

# Update APT
RUN apt-get update

# Install build dependencies
RUN apt-get install -y \
  wget \
  python-software-properties \
  software-properties-common

# Add Oracle Java maintainers and Nginx stable PPAs and automatically select the Oracle License
RUN apt-add-repository ppa:webupd8team/java &&\
  apt-add-repository ppa:nginx/stable &&\
  echo "debconf shared/accepted-oracle-license-v1-1 select true" | debconf-set-selections

# Add Elasticsearch Public Signing Key
RUN wget -qO - http://packages.elasticsearch.org/GPG-KEY-elasticsearch | apt-key add - &&\
  echo "deb http://packages.elasticsearch.org/elasticsearch/$VERSION/debian stable main" > /etc/apt/sources.list.d/elasticsearch.list

# Install Java 7, nginx, Elasticsearch, supervisor
RUN apt-get update &&\
  apt-get install -y oracle-java7-installer nginx elasticsearch supervisor

# Add Elasticsearch reverse proxy nginx config
ADD nginx/sites-available/elasticsearch /etc/nginx/sites-available/

# Enable Elasticsearch reverse proxy and remove nginx default config
RUN cd /etc/nginx/sites-enabled &&\
  rm default &&\
  ln -s ../sites-available/elasticsearch

# Run nginx in foreground and set number of worker processes to auto-detect
RUN echo "daemon off;\n" >> /etc/nginx/nginx.conf &&\
  sed -i '/^worker_processes/s,[0-9]\+,'"auto"',' /etc/nginx/nginx.conf

# Add supervisor config files
ADD supervisor/nginx.conf         /etc/supervisor/conf.d/
ADD supervisor/elasticsearch.conf /etc/supervisor/conf.d/

# Add example htpasswd (users should overwrite this with a more secure username/password)
ADD data/htpasswd /data/

# Link default elasticsearch.yml to /data
RUN cd /data && ln -s /etc/elasticsearch/elasticsearch.yml

# Clean up APT and temporary files when done
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

VOLUME ["/data"]

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf", "-n"]

EXPOSE 80 9200 9300
