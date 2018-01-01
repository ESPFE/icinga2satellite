## Dockerfile for espfe/icinga2_satellite
## https://github.com/ESPFE/icinga2_satellite
## https://www.edv-peuker.de

#FROM debian:stretch
FROM phusion/baseimage

MAINTAINER André Sünnemann - EDV-Systeme Peuker GmbH & Co. KG <a.suennemann@edv-peuker.de>

LABEL version="0.1.11"

RUN apt-get update \
	&& apt-get dist-upgrade -y \
	&& apt-get install -y \
		curl \
		apt-transport-https \
		bash \
		gnupg \
		supervisor
		
RUN curl -s https://packages.icinga.com/icinga.key \
	| apt-key add -
RUN echo 'deb https://packages.icinga.com/debian icinga-stretch main' \
	> /etc/apt/sources.list.d/icinga.list

RUN apt-get update \
	&& apt-get install -y \
		icinga2 \
		monitoring-plugins \
		nagios-plugins \
		nagios-plugins-basic \
		nagios-plugins-common \
		nagios-plugins-contrib \
		nagios-plugins-standard
		
RUN apt-get clean


RUN rm -rf /etc/icinga2/conf.d/*

COPY config/ /


RUN echo '"include_recursive /opt/icinga2/conf.d"' >> /etc/icinga2/icinga2.conf


EXPOSE 5665

CMD ["/opt/start.sh"]
