FROM alpine:3.9

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

LABEL maintainer="CrazyMax" \
  org.label-schema.build-date=$BUILD_DATE \
  org.label-schema.name="svn2git-mirror" \
  org.label-schema.description="Mirror SVN repositories to Git periodically" \
  org.label-schema.version=$VERSION \
  org.label-schema.url="https://github.com/crazy-max/docker-svn2git-mirror" \
  org.label-schema.vcs-ref=$VCS_REF \
  org.label-schema.vcs-url="https://github.com/crazy-max/docker-svn2git-mirror" \
  org.label-schema.vendor="CrazyMax" \
  org.label-schema.schema-version="1.0"

RUN apk --update --no-cache add \
    git \
    git-perl \
    git-svn \
    jq \
    openssh \
    openssh-client \
    perl-git-svn \
    ruby \
    shadow \
    subversion \
    tzdata \
  && gem install svn2git --no-ri --no-rdoc \
  && rm -rf /var/cache/apk/* /tmp/*

ENV SVN2GIT_MIRROR_PATH="/etc/svn2git-mirror" \
  SVN2GIT_MIRROR_CONFIG="/etc/svn2git-mirror/config.json" \
  DATA_PATH="/data"

COPY entrypoint.sh /entrypoint.sh
COPY assets /

RUN mkdir -p ${SVN2GIT_MIRROR_PATH} ${DATA_PATH} \
  && addgroup -g 1000 svn2git \
  && adduser -u 1000 -G svn2git -h /home/svn2git -s /sbin/nologin -D svn2git \
  && chmod a+x /entrypoint.sh /usr/local/bin/*

WORKDIR ${DATA_PATH}
VOLUME [ "${DATA_PATH}" ]

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "busybox", "crond", "-f", "-L", "/dev/stdout" ]
