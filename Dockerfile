FROM alpine:3.6
MAINTAINER CrazyMax <crazy-max@users.noreply.github.com>

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

LABEL org.label-schema.build-date=$BUILD_DATE \
  org.label-schema.name="svn2git-mirror" \
  org.label-schema.description="Mirror SVN repositories to Git periodically" \
  org.label-schema.version=$VERSION \
  org.label-schema.url="https://github.com/crazy-max/docker-svn2git-mirror" \
  org.label-schema.vcs-ref=$VCS_REF \
  org.label-schema.vcs-url="https://github.com/crazy-max/docker-svn2git-mirror" \
  org.label-schema.vendor="CrazyMax" \
  org.label-schema.schema-version="1.0"

RUN apk --update --no-cache add dcron git git-perl git-svn jq openssh openssh-client perl-git-svn ruby subversion tzdata \
  && rm -rf /var/cache/apk/* \
  && gem install svn2git --no-ri --no-rdoc

ENV DATA_PATH="/data" \
  CRONTAB_PATH="/var/spool/cron/crontabs" \
  SCRIPTS_PATH="/usr/local/bin"

ADD entrypoint.sh /entrypoint.sh
ADD assets /data

RUN mkdir -p ${DATA_PATH} \
  && mkdir -m 0644 -p ${CRONTAB_PATH} \
  && cd ${DATA_PATH} \
  && for f in *.sh; do \
  scriptBasename=`echo $f | cut -d "." -f 1`; \
  mv $f ${SCRIPTS_PATH}/$scriptBasename; \
  chmod a+x ${SCRIPTS_PATH}/*; done \
  && chmod a+x /entrypoint.sh

VOLUME [ "${DATA_PATH}" ]

WORKDIR "${DATA_PATH}"
ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "cron" ]
