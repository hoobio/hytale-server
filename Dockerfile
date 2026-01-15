FROM eclipse-temurin:25

RUN apt-get update -qq && apt-get install -q -y wget unzip gosu jq curl && rm -rf /var/lib/apt/lists/*

RUN mkdir /data /scripts

VOLUME [ "/data"]

WORKDIR /scripts
ADD src /scripts
RUN chmod -R +x /scripts

ENTRYPOINT ["/bin/sh", "/scripts/entrypoint.sh"]