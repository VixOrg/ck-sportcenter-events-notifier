FROM python:3.8-slim-buster

ARG WEB_CREDS
ARG ICAL_TMPL
ARG GCAL_CLI_CACHE
ARG GCAL_CLI_OAUTH
ARG TELEGRAM_BOT_TOKEN
ARG TELEGRAM_CHAT_ID
ARG DEBUG
ARG CLUB_MANAGER_TELEGRAM_NICK
ARG NO_SPAM

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

RUN apt-get update && \
    apt-get install -y curl jq locales && \
    sed -i -e "s/# $LANG.*/$LANG UTF-8/" /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=$LANG

RUN --mount=type=secret,id=config,target=/app/.config mkdir -p /app/.auth/.gcalcli && "mount - ok"; \
    cp /app/.config/ical.tmpl /app/ical.tmpl && echo "ical.tmpl - ok"; \
    cp -r /app/.config/auth/* /app/.auth/ && echo ".auth - ok"; \
    cp -r /app/.config/gcalcli/* /app/.auth/.gcalcli/ & echo ".gcalcli - ok"

COPY ./requirements.txt /app
RUN pip install -r /app/requirements.txt

COPY . /app

RUN /app/badminton.sh 
