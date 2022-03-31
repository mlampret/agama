# BUILD
# docker build -t ssdata .
#
# RUN
# docker run --rm -p 3000:3000 -p 3006:3306 -v "$(pwd):/opt/self-serve-data" ssdata
#
# Note: mysql port on your mac will be 3006 instead of 3306

FROM --platform=linux/x86_64 mysql:5.7

WORKDIR /opt/agama

EXPOSE 3000
EXPOSE 3306

# to avoid warnings
RUN mkdir -p /home/mysql

RUN apt update && apt install -y cpanminus make libssl-dev build-essential procps

# some perl modules that don't need to be of specific verison
# bacause apt is faster than cpanm
RUN apt install -y \
    libnet-ssleay-perl libio-socket-ssl-perl libdbd-mysql-perl \
    libcpanel-json-xs-perl libjson-perl libmouse-perl \
    libclass-singleton-perl libtext-csv-perl 

ADD installdeps/cpanfile /tmp
RUN cpanm --installdeps /tmp

RUN service mysql start && echo "\
    CREATE DATABASE agama DEFAULT CHARACTER SET utf8mb4 DEFAULT COLLATE utf8mb4_unicode_ci; \
    CREATE USER 'agama'@'%' IDENTIFIED BY 'password'; \
    GRANT ALL ON agama.* TO 'agama'@'%'; \
    FLUSH PRIVILEGES; \
    " | mysql

ENTRYPOINT \
    service mysql start &&\
    for f in migrations/*.sql ; do mysql agama < "$f"; done &&\
    echo "Migrations applied" &&\
    morbo script/agama
