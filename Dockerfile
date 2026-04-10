# This recipe allows choosing specific versions of python, R, and NodeJS in one ubuntu based image

FROM ubuntu AS base

# Essentials for installing everything else
RUN set -x \
  && apt-get update -y \
  && apt-get install -y --no-install-recommends \
    curl tar bash ca-certificates sudo \
  && rm -rf /var/lib/apt/lists/*

# This entrypoint sources all entrypoints at /opt/*/entrypoint.sh
ADD entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
# This install.sh sources all installs at /opt/*/install.sh
ADD install.sh /install.sh
RUN chmod +x /install.sh
# This sources the entrypoint whenever bash runs (interactive or not)
USER ubuntu
WORKDIR /home/ubuntu
ENV BASH_ENV=/home/ubuntu/.bash_env
RUN set -x \
  && echo 'shopt -s expand_aliases' >> ~/.bash_env \
  && echo '. /entrypoint.sh' >> ~/.bash_env \
  && echo '. "/home/ubuntu/.bash_env"' >> ~/.bashrc \
  && touch /home/ubuntu/.sudo_as_admin_successful

SHELL ["/bin/bash", "-c"]
ENTRYPOINT [ "/bin/bash", "-c" ]
CMD [ "bash" ]

FROM base AS node_base
# The node base uses nvm to install the specific version of nodejs specified later
USER root
RUN mkdir -p /opt/node && touch /opt/node/entrypoint.sh
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | NVM_DIR=/opt/node PROFILE=/dev/null bash
RUN  echo "if [[ ! -z \"\$NODE_VERSION\" ]]; then" > /opt/node/install.sh \
  && echo "  echo \"export NVM_DIR=~/.nvm\" >> ~/.bash_env" >> /opt/node/install.sh \
  && echo "  echo \"export npm_config_cache=~/.npm\" >> ~/.bash_env" >> /opt/node/install.sh \
  && echo "  echo \". /opt/node/nvm.sh\" >> ~/.bash_env" >> /opt/node/install.sh \
  && echo "  . ~/.bash_env" >> /opt/node/install.sh \
  && echo "  nvm install \$NODE_VERSION" >> /opt/node/install.sh \
  && echo "  nvm use \$NODE_VERSION" >> /opt/node/install.sh \
  && echo "fi" >> /opt/node/install.sh

FROM base AS python_base
# The python base uses uv to install the specific version of python specified later
USER root
RUN mkdir -p /opt/python/bin
RUN curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/opt/python/bin sh
RUN set -x \
  && echo "export UV_INSTALL_DIR=/opt/python/bin" > /opt/python/entrypoint.sh \
  && echo "export PATH=\$PATH:\$UV_INSTALL_DIR" >> /opt/python/entrypoint.sh \
  && echo "if [[ ! -z \"\$PYTHON_VERSION\" ]]; then" > /opt/python/install.sh \
  && echo "  uv venv --python \$PYTHON_VERSION" >> /opt/python/install.sh \
  && echo "  echo \"[ -f ~/.venv/bin/activate ] && . ~/.venv/bin/activate\" >> ~/.bash_env" >> /opt/python/install.sh \
  && echo "  echo \"alias pip='uv pip'\" >> ~/.bash_env" >> /opt/python/install.sh \
  && echo "fi" >> /opt/python/install.sh

FROM base AS r_base
# The R base uses rig to install the specific version of R specified later
#  unfortunately rig doesn't support installing with unprivileged users,
#  so we make the install script run with root permissions using a sudoers rule.
USER root
RUN mkdir -p /opt/R
RUN curl -Ls https://github.com/r-lib/rig/releases/download/latest/rig-linux-$(arch)-latest.tar.gz | tar xz -C /opt/R
RUN set -x \
  && echo "ubuntu ALL=(root) NOPASSWD: /opt/R/install.sh" > /etc/sudoers.d/R \
  && echo "export PATH=\$PATH:/opt/R/bin" > /opt/R/entrypoint.sh \
  && echo "#!/bin/bash" > /opt/R/install.sh \
  && echo "if [[ \$EUID -ne 0 ]]; then" >> /opt/R/install.sh \
  && echo "  sudo /opt/R/install.sh \$R_VERSION" >> /opt/R/install.sh \
  && echo "else" >> /opt/R/install.sh \
  && echo "  export PATH=\$PATH:/opt/R/bin" >> /opt/R/install.sh \
  && echo "  export R_VERSION=\$1" >> /opt/R/install.sh \
  && echo "  if [[ ! -z \"\$R_VERSION\" ]]; then" >> /opt/R/install.sh \
  && echo "    rig install \$R_VERSION && rig default \$R_VERSION && rm -rf /var/lib/apt/lists/*" >> /opt/R/install.sh \
  && echo "  fi" >> /opt/R/install.sh \
  && echo "fi" >> /opt/R/install.sh \
  && chmod +x /opt/R/install.sh

FROM base AS pre_installed
# grab prepared directories
COPY --from=python_base /opt/python /opt/python
COPY --from=node_base /opt/node /opt/node
COPY --from=r_base /opt/R /opt/R
COPY --from=r_base /etc/sudoers.d/R /etc/sudoers.d/R

FROM pre_installed AS python
RUN PYTHON_VERSION=3.11 /install.sh
CMD ["python"]

FROM pre_installed AS basic
# specify versions of everything
RUN NODE_VERSION=20 PYTHON_VERSION=3.11 R_VERSION=4.5.3 /install.sh
