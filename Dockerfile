ARG UBUNTU_VERSION=latest
FROM ubuntu:${UBUNTU_VERSION}

LABEL maintainer="Truong Thanh Tung <ttungbmt@gmail.com>"

# Set Environment Variables
ENV DEBIAN_FRONTEND noninteractive

# Start as root
USER root

###########################################################################
# Laradock non-root user:
###########################################################################

# Add a non-root user to prevent files being created with root permissions on host machine.
ARG PUID=1000
ENV PUID ${PUID}
ARG PGID=1000
ENV PGID ${PGID}

# always run apt update when start and after add new source list, then clean up at end.
RUN set -xe; \
    apt-get update -yqq && \
    groupadd --force -g ${PGID} laradock && \
    useradd -l -u ${PUID} -g ${PGID} -m laradock -s /bin/bash && \
    usermod -p "*" laradock -s /bin/bash && \
    apt-get install -yqq \
      apt-utils \
      #
      #--------------------------------------------------------------------------
      # Mandatory Software's Installation
      #--------------------------------------------------------------------------
      #
      # Mandatory Software's such as ("php-cli", "git", "vim", ....)
      apt-transport-https ca-certificates gnupg2  software-properties-common \
      sudo \
      libzip-dev zip unzip \
      net-tools iputils-ping telnet \
      git curl wget vim nano tree

###########################################################################
# Set Timezone
###########################################################################

ARG TZ=UTC
ENV TZ ${TZ}

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

###########################################################################
# Crontab
###########################################################################

USER root

COPY ./crontab /etc/cron.d

RUN chmod -R 644 /etc/cron.d

###########################################################################
# ssh:
###########################################################################

ARG INSTALL_WORKSPACE_SSH=true

COPY .ssh/insecure_id_rsa /tmp/id_rsa
COPY .ssh/insecure_id_rsa.pub /tmp/id_rsa.pub

RUN if [ ${INSTALL_WORKSPACE_SSH} = true ]; then \
    rm -f /etc/service/sshd/down && \
    mkdir -p /root/.ssh && \
    cat /tmp/id_rsa.pub >> /root/.ssh/authorized_keys \
        && cat /tmp/id_rsa.pub >> /root/.ssh/id_rsa.pub \
        && cat /tmp/id_rsa >> /root/.ssh/id_rsa \
        && rm -f /tmp/id_rsa* \
        && chmod 644 /root/.ssh/authorized_keys /root/.ssh/id_rsa.pub \
    && chmod 400 /root/.ssh/id_rsa \
    && cp -rf /root/.ssh /home/laradock \
    && chown -R laradock:laradock /home/laradock/.ssh \
;fi

# ###########################################################################
# # sshpass:
# ###########################################################################
ARG INSTALL_SSHPASS=true

RUN set -eux; \
  if [ ${INSTALL_SSHPASS} = true ]; then \
    apt-get -yqq install sshpass; \
  fi;

###########################################################################
# PYTHON3:
###########################################################################

ARG INSTALL_PYTHON3=true

RUN if [ ${INSTALL_PYTHON3} = true ]; then \
  add-apt-repository -y ppa:deadsnakes/ppa && \
  apt-get update -yqq && \
  apt-get -y install \
    python3 python3-all-dev python3-dev python3-pip python-is-python3 \
    python3-pip python3-pil python3-lxml python3-pylibmc \
    python-is-python3 \
;fi

###########################################################################
USER root

ARG INSTALL_DOCKER_CLIENT=true

RUN set -eux; \
  ###################################################################
  # Docker Client:
  ###########################################################################
  if [ ${INSTALL_DOCKER_CLIENT} = true ]; then \
    curl -sS https://download.docker.com/linux/static/stable/x86_64/docker-20.10.24.tgz -o /tmp/docker.tar.gz; \
    tar -xzf /tmp/docker.tar.gz -C /tmp/; \
    cp /tmp/docker/docker* /usr/local/bin; \
    chmod +x /usr/local/bin/docker*; \
    groupadd docker; \
    usermod -aG docker laradock; \
  fi

###########################################################################
# Oh My ZSH!
###########################################################################

USER root

ARG SHELL_OH_MY_ZSH=true
RUN if [ ${SHELL_OH_MY_ZSH} = true ]; then \
    apt install -y zsh \
;fi

ARG SHELL_OH_MY_ZSH_AUTOSUGESTIONS=true
ARG SHELL_OH_MY_ZSH_ALIASES=true

USER laradock
RUN if [ ${SHELL_OH_MY_ZSH} = true ]; then \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh) --keep-zshrc" && \
    sed -i -r 's/^plugins=\(.*?\)$/plugins=(laravel composer)/' /home/laradock/.zshrc && \
    echo '\n\
bindkey "^[OB" down-line-or-search\n\
bindkey "^[OC" forward-char\n\
bindkey "^[OD" backward-char\n\
bindkey "^[OF" end-of-line\n\
bindkey "^[OH" beginning-of-line\n\
bindkey "^[[1~" beginning-of-line\n\
bindkey "^[[3~" delete-char\n\
bindkey "^[[4~" end-of-line\n\
bindkey "^[[5~" up-line-or-history\n\
bindkey "^[[6~" down-line-or-history\n\
bindkey "^?" backward-delete-char\n' >> /home/laradock/.zshrc && \
  if [ ${SHELL_OH_MY_ZSH_AUTOSUGESTIONS} = true ]; then \
    sh -c "git clone https://github.com/zsh-users/zsh-autosuggestions /home/laradock/.oh-my-zsh/custom/plugins/zsh-autosuggestions" && \
    sed -i 's~plugins=(~plugins=(zsh-autosuggestions ~g' /home/laradock/.zshrc && \
    sed -i '1iZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20' /home/laradock/.zshrc && \
    sed -i '1iZSH_AUTOSUGGEST_STRATEGY=(history completion)' /home/laradock/.zshrc && \
    sed -i '1iZSH_AUTOSUGGEST_USE_ASYNC=1' /home/laradock/.zshrc && \
    sed -i '1iTERM=xterm-256color' /home/laradock/.zshrc \
  ;fi && \
  if [ ${SHELL_OH_MY_ZSH_ALIASES} = true ]; then \
    echo "" >> /home/laradock/.zshrc && \
    echo "# Load Custom Aliases" >> /home/laradock/.zshrc && \
    echo "source /home/laradock/aliases.sh" >> /home/laradock/.zshrc && \
    echo "" >> /home/laradock/.zshrc \
  ;fi \
;fi

RUN if [ ${SHELL_OH_MY_ZSH} = true ]; then \
    bash -c "$(curl --fail --show-error --silent --location https://raw.githubusercontent.com/zdharma-continuum/zinit/HEAD/scripts/install.sh)" \
;fi

USER root

###########################################################################
# ZSH User Aliases
###########################################################################

USER root

COPY ./aliases.sh /root/aliases.sh
COPY ./aliases.sh /home/laradock/aliases.sh

RUN if [ ${SHELL_OH_MY_ZSH} = true ]; then \
    sed -i 's/\r//' /root/aliases.sh && \
    sed -i 's/\r//' /home/laradock/aliases.sh && \
    chown laradock:laradock /home/laradock/aliases.sh && \
    echo "" >> ~/.zshrc && \
    echo "# Load Custom Aliases" >> ~/.zshrc && \
    echo "source ~/aliases.sh" >> ~/.zshrc && \
	  echo "" >> ~/.zshrc \
;fi

USER laradock

RUN if [ ${SHELL_OH_MY_ZSH} = true ]; then \
    echo "" >> ~/.zshrc && \
    echo "# Load Custom Aliases" >> ~/.zshrc && \
    echo "source ~/aliases.sh" >> ~/.zshrc && \
	  echo "" >> ~/.zshrc \
;fi

USER root

###########################################################################
# Node / NVM:
###########################################################################
USER laradock

# Check if NVM needs to be installed
ARG INSTALL_NODE=true
ARG NVM_VERSION=0.39.3
ARG NODE_VERSION=lts/*
ENV NODE_VERSION ${NODE_VERSION}
ARG INSTALL_NPM_GULP=true
ARG INSTALL_NPM_BOWER=true
ARG INSTALL_NPM_VUE_CLI=true
ARG INSTALL_NPM_ANGULAR_CLI=true
ARG INSTALL_NPM_IONIC_CLI=false
ARG NPM_REGISTRY
ENV NPM_REGISTRY ${NPM_REGISTRY}
ARG NPM_FETCH_RETRIES
ENV NPM_FETCH_RETRIES ${NPM_FETCH_RETRIES}
ARG NPM_FETCH_RETRY_FACTOR
ENV NPM_FETCH_RETRY_FACTOR ${NPM_FETCH_RETRY_FACTOR}
ARG NPM_FETCH_RETRY_MINTIMEOUT
ENV NPM_FETCH_RETRY_MINTIMEOUT ${NPM_FETCH_RETRY_MINTIMEOUT}
ARG NPM_FETCH_RETRY_MAXTIMEOUT
ENV NPM_FETCH_RETRY_MAXTIMEOUT ${NPM_FETCH_RETRY_MAXTIMEOUT}
ENV NVM_DIR /home/laradock/.nvm
ARG NVM_NODEJS_ORG_MIRROR
ENV NVM_NODEJS_ORG_MIRROR ${NVM_NODEJS_ORG_MIRROR}

RUN if [ ${INSTALL_NODE} = true ]; then \
    # Install nvm (A Node Version Manager)
    mkdir -p $NVM_DIR && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh | bash \
        && . $NVM_DIR/nvm.sh \
        && nvm install ${NODE_VERSION} \
        && nvm use ${NODE_VERSION} \
        && nvm alias ${NODE_VERSION} \
        && npm cache clear --force \
        && npm config set fetch-retries ${NPM_FETCH_RETRIES} \
        && npm config set fetch-retry-factor ${NPM_FETCH_RETRY_FACTOR} \
        && npm config set fetch-retry-mintimeout ${NPM_FETCH_RETRY_MINTIMEOUT} \
        && npm config set fetch-retry-maxtimeout ${NPM_FETCH_RETRY_MAXTIMEOUT} \
        && if [ ${NPM_REGISTRY} ]; then \
        npm config set registry ${NPM_REGISTRY} \
        ;fi \
        && if [ ${INSTALL_NPM_GULP} = true ]; then \
        npm install -g gulp \
        ;fi \
        && if [ ${INSTALL_NPM_BOWER} = true ]; then \
        npm install -g bower \
        ;fi \
        && if [ ${INSTALL_NPM_VUE_CLI} = true ]; then \
        npm install -g @vue/cli \
        ;fi \
        && if [ ${INSTALL_NPM_ANGULAR_CLI} = true ]; then \
        npm install -g @angular/cli \
        ;fi \
        && if [ ${INSTALL_NPM_ANGULAR_CLI} = true ]; then \
        npm install -g @ionic/cli \
        ;fi \
;fi

# # Wouldn't execute when added to the RUN statement in the above block
# # Source NVM when loading bash since ~/.profile isn't loaded on non-login shell
# RUN if [ ${INSTALL_NODE} = true ]; then \
#     echo "" >> ~/.bashrc && \
#     echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc && \
#     echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm' >> ~/.bashrc \
# ;fi

# # Add NVM binaries to root's .bashrc
# USER root

# RUN if [ ${INSTALL_NODE} = true ]; then \
#     echo "" >> ~/.bashrc && \
#     echo 'export NVM_DIR="/home/laradock/.nvm"' >> ~/.bashrc && \
#     echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm' >> ~/.bashrc \
# ;fi

# # Make it so the node modules can be executed with 'docker-compose exec'
# # We'll create symbolic links into '/usr/local/bin'.
# RUN if [ ${INSTALL_NODE} = true ]; then \
#     find $NVM_DIR -type f -name node -exec ln -s {} /usr/local/bin/node \; && \
#     NODE_MODS_DIR="$NVM_DIR/versions/node/$(node -v)/lib/node_modules" && \
#     ln -s $NODE_MODS_DIR/bower/bin/bower /usr/local/bin/bower && \
#     ln -s $NODE_MODS_DIR/gulp/bin/gulp.js /usr/local/bin/gulp && \
#     ln -s $NODE_MODS_DIR/npm/bin/npm-cli.js /usr/local/bin/npm && \
#     ln -s $NODE_MODS_DIR/npm/bin/npx-cli.js /usr/local/bin/npx && \
#     ln -s $NODE_MODS_DIR/vue-cli/bin/vue /usr/local/bin/vue && \
#     ln -s $NODE_MODS_DIR/vue-cli/bin/vue-init /usr/local/bin/vue-init && \
#     ln -s $NODE_MODS_DIR/vue-cli/bin/vue-list /usr/local/bin/vue-list \
# ;fi

RUN if [ ${NPM_REGISTRY} ]; then \
    . ~/.bashrc && npm config set registry ${NPM_REGISTRY} \
;fi

# Mount .npmrc into home folder
COPY ./.npmrc /root/.npmrc
COPY ./.npmrc /home/laradock/.npmrc

# ###########################################################################
# # PNPM:
# ###########################################################################

# USER root

# ARG INSTALL_PNPM=true
# ENV PNPM_HOME="/home/laradock/.local/share/pnpm"
# ENV PATH $PATH:/home/laradock/.local/share/pnpm

# RUN if [ ${INSTALL_PNPM} = true ]; then \
#     echo "" >> ~/.bashrc && \
#     echo 'export PNPM_HOME="/home/laradock/.local/share/pnpm"' >> ~/.bashrc && \
#     echo 'export PATH="$PNPM_HOME:$PATH"' >> ~/.bashrc && \
#     npx pnpm add -g pnpm \
# ;fi

# ###########################################################################
# # YARN:
# ###########################################################################

# USER laradock

# ARG INSTALL_YARN=true
# ARG YARN_VERSION=latest
# ENV YARN_VERSION ${YARN_VERSION}

# RUN if [ ${INSTALL_YARN} = true ]; then \
#     [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && \
#     if [ ${YARN_VERSION} = "latest" ]; then \
#         curl -o- -L https://yarnpkg.com/install.sh | bash; \
#     else \
#         curl -o- -L https://yarnpkg.com/install.sh | bash -s -- --version ${YARN_VERSION}; \
#     fi && \
#     echo "" >> ~/.bashrc && \
#     echo 'export PATH="$HOME/.yarn/bin:$PATH"' >> ~/.bashrc \
# ;fi

# # Add YARN binaries to root's .bashrc
# USER root

# RUN if [ ${INSTALL_YARN} = true ]; then \
#     echo "" >> ~/.bashrc && \
#     echo 'export YARN_DIR="/home/laradock/.yarn"' >> ~/.bashrc && \
#     echo 'export PATH="$YARN_DIR/bin:$PATH"' >> ~/.bashrc \
# ;fi

# # Add PATH for YARN
# ENV PATH $PATH:/home/laradock/.yarn/bin

#
#--------------------------------------------------------------------------
# Final Touch
#--------------------------------------------------------------------------
#

USER root

# # Clean up
# RUN apt-get clean && \
#     rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
#     rm /var/log/lastlog /var/log/faillog

# Set default work directory
WORKDIR /var/www