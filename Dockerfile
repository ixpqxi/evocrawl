FROM node:14-bullseye

ARG KAFKA_VERSION=2.8.1
ARG SCALA_VERSION=2.13

ENV DEBIAN_FRONTEND=noninteractive
ENV NODE_OPTIONS=--max-old-space-size=5120
ENV TESTCAFE_BROWSER="chrome --headless --no-sandbox --disable-dev-shm-usage"
ENV PATH="/opt/evocrawl/node_modules/.bin:${PATH}"

WORKDIR /opt/evocrawl

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        chromium \
        curl \
        docker.io \
        fonts-liberation \
        libasound2 \
        libatk-bridge2.0-0 \
        libgbm1 \
        libgtk-3-0 \
        libnss3 \
        libxss1 \
        openjdk-11-jre-headless \
        procps \
        python3 \
        python3-pip \
        screen \
        tini \
    && ln -sf /usr/bin/chromium /usr/bin/google-chrome \
    && rm -rf /var/lib/apt/lists/*

COPY package.json testcafe-current.tgz ./
RUN npm install --production \
    && npm cache clean --force

RUN curl -fsSL "https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz" -o /tmp/kafka.tgz \
    && tar -xzf /tmp/kafka.tgz -C /opt/evocrawl \
    && rm -f /tmp/kafka.tgz \
    && mkdir -p "/opt/evocrawl/kafka_${SCALA_VERSION}-${KAFKA_VERSION}/logs"

COPY . .

RUN cp utils-evo/login_information.json utils-evo/login_information.defaults.json \
    && chmod +x docker/entrypoint.sh start_process.sh start_kafka crawl/*.sh replay/*.sh inputs_detection/*.sh

ENTRYPOINT ["tini", "--", "/opt/evocrawl/docker/entrypoint.sh"]
