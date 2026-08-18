# Base image is the Barclays UBI8 Tyk Pump artefact (binary copied from vendor at image-build time).
# Do not FROM tykio/tyk-pump-docker-pub at runtime.
ARG TYK_PUMP_IMAGE=container-release.container-registry-non-prod.barcapint.com/barclays/barclays-api-gateway/tyk/tyk-pump/1.16.0:1.16.0.291
FROM ${TYK_PUMP_IMAGE}

USER root

ENV PIP_INDEX https://nexus-amazon-pdn.barclays.intranet/service/rest/repository/browse/barclays-read-pypi/pypi
ENV PIP_INDEX_URL https://nexus-amazon-pdn.barclays.intranet/repository/barclays-read-pypi/simple/
ENV PIP_TRUSTED_HOST nexus-amazon-pdn.barclays.intranet
ENV PIP_CERT /opt/barclays-certs/tls-ca-bundle.pem

RUN mkdir -p /opt/barclays-certs && \
    curl -L -o /opt/barclays-certs/tls-ca-bundle.pem \
    "https://nexus.barcapint.com/nexus/service/local/repositories/ib-cto-python/content/tls-ca-bundle.pem"

RUN yum install -y python3 python3-pip && yum clean all
RUN pip3 install --no-cache-dir boto3

WORKDIR /opt/tyk-pump

COPY pump/entrypoint.sh /entrypoint.sh
COPY app/fetch_ssm.py /app/fetch_ssm.py
RUN chmod +x /entrypoint.sh && \
    mkdir -p /app && \
    chown -R 1000:1000 /app /opt/tyk-pump

USER 1000

ENTRYPOINT ["/entrypoint.sh"]
