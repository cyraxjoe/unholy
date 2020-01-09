FROM ubuntu:16.04
## base build arguments
ARG USER=nixvoyager-user
# configure the base build user
ENV HOME /home/$USER
RUN useradd --comment "nix-voyager build user" \
            --home-dir $HOME \
            --create-home $USER \
            --shell /bin/bash

# install lsb-release so that the virtualenvs can obtain the system
# information and ca-certificate in case we try to fetch something
# from the network and is using https (like pip)
RUN apt-get update && apt-get install -y lsb-release ca-certificates

# add support for extra repos as needed
RUN apt-get update && apt-get install -y software-properties-common

# add key fingerprints that may be needed for different repos.
# for now this assumes they're on ubuntu's keyserver. we could instead copy public files
# (as nix source derivations) into the container, but some sites don't host their full public
# key
ENV REPO_KEYS=@targetSystemAptKeys@
RUN if [ ! -z "${REPO_KEYS}" ]; then apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 "${REPO_KEYS}"; fi

# only add specific PPAs and repos if they've been passed in by the caller
ENV REPOS=@targetSystemRepos@
RUN if [ ! -z "${REPOS}" ]; then add-apt-repository "${REPOS}"; fi
RUN apt-get update


# we use a direct string replacement (the @ placeholder)
# because otherwise docker has issues caching the layer even if we define
# the same dependencies on a file and then use it to install those
RUN apt-get update && \
    apt-get install -y @targetSystemBuildDependencies@
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh


COPY nixvoyager-script.sh /nixvoyager-script.sh
RUN chmod +x /nixvoyager-script.sh


USER $USER
WORKDIR $HOME/
RUN mkdir @ARGS_DIR@

# CUSTOM_ARGS
@CUSTOM_ARGS@

# additional environment variables that are passed through and not derived from nix inputs
#@ENV_ARGS@

COPY build.sh $HOME/
ENV USER $USER
# envvars relevant for built.sh and entrypoint.sh
ENV OUTPUT_DIR $HOME/output
ENV RESULT_LINK $OUTPUT_DIR/result

ENV OUTPUTS "@outputs@"
###
RUN /bin/bash $HOME/build.sh
CMD [ "" ]

ENTRYPOINT [ "/entrypoint.sh" ]
