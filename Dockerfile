# This recipe allows choosing specific versions of python, R, and NodeJS in one ubuntu based image

FROM ubuntu AS base

# Essentials for installing everything else
RUN set -x \
  && apt-get update -y \
  && apt-get install -y --no-install-recommends \
    curl tar bash ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# This entrypoint sources all entrypoints at /root/*/entrypoint.sh
ADD entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
# This install.sh sources all installs at /root/*/install.sh
ADD install.sh /install.sh
RUN chmod +x /install.sh
# This sources the entrypoint whenever bash runs (interactive or not)
ENV BASH_ENV=/entrypoint.sh
RUN echo '. "${BASH_ENV}"' >> ~/.bashrc
ENTRYPOINT [ "/bin/bash", "-c" ]
CMD [ "bash" ]

FROM base AS node_base
# The node base uses nvm to install the specific version of nodejs specified later
ENV NVM_DIR=/root/node
RUN mkdir -p $NVM_DIR && touch /root/node/entrypoint.sh
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | PROFILE="/root/node/entrypoint.sh" bash
RUN  echo "if [[ ! -z \"\$NODE_VERSION\" ]]; then" > /root/node/install.sh \
  && echo "  rig install \$NODE_VERSION && rig default \$NODE_VERSION && rm -rf /var/lib/apt/lists/*" >> /root/node/install.sh \
  && echo "fi" >> /root/node/install.sh

FROM base AS python_base
# The python base uses uv to install the specific version of python specified later
ENV UV_INSTALL_DIR=/root/python/bin
RUN mkdir -p $UV_INSTALL_DIR
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
RUN set -x \
  && echo "export UV_INSTALL_DIR=$UV_INSTALL_DIR" > /root/python/entrypoint.sh \
  && echo "export PATH=\$PATH:\$UV_INSTALL_DIR" >> /root/python/entrypoint.sh \
  && echo "if [[ ! -z \"\$PYTHON_VERSION\" ]]; then" > /root/python/install.sh \
  && echo "  cd /root/python && uv venv --python \$PYTHON_VERSION" >> /root/python/install.sh \
  && echo "  echo \"source /root/python/.venv/bin/activate\" >> /root/python/entrypoint.sh" >> /root/python/install.sh \
  && echo "  echo \"alias pip='uv pip'\" >> /root/python/entrypoint.sh" >> /root/python/install.sh \
  && echo "fi" >> /root/python/install.sh

FROM base AS r_base
# The R base uses rig to install the specific version of R specified later
ENV R_INSTALL_DIR=/root/R
RUN mkdir -p $R_INSTALL_DIR
RUN curl -Ls https://github.com/r-lib/rig/releases/download/latest/rig-linux-$(arch)-latest.tar.gz | tar xz -C $R_INSTALL_DIR
RUN set -x \
  && echo "export PATH=\$PATH:$R_INSTALL_DIR/bin" > /root/R/entrypoint.sh \
  && echo "if [[ ! -z \"\$R_VERSION\" ]]; then" > /root/R/install.sh \
  && echo "  rig install \$R_VERSION && rig default \$R_VERSION && rm -rf /var/lib/apt/lists/*" >> /root/R/install.sh \
  && echo "fi" >> /root/R/install.sh

FROM base AS pre_installed
# grab prepared directories
COPY --from=python_base /root/python /root/python
COPY --from=r_base /root/R /root/R
COPY --from=node_base /root/node /root/node

FROM pre_installed AS python
RUN PYTHON_VERSION=3.11 /install.sh
CMD ["python"]

FROM pre_installed AS basic
# specify versions of everything
RUN NODE_VERSION=20 PYTHON_VERSION=3.11 R_VERSION=4.5.3 /install.sh
