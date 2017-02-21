FROM httpd:2.2-alpine

# "source" : https://github.com/docker-library/php/blob/e573f8f7fda5d7378bae9c6a936a298b850c4076/5.6/apache/Dockerfile
RUN apk update
RUN apk add 'autoconf<2.70' \
            'file<5.28' \
            'g++<5.4.0' \
            'make<4.2' \
            're2c<1.25.0' \
            'ca-certificates<20161201' \
            'curl<7.53.0' \
            'libedit<20150325.4.0' \
            'sqlite-libs<3.14.0' \
            'libxml2<2.10.0' \
            'xz<5.3.0'
