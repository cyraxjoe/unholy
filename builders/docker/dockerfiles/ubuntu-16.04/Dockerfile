FROM ubuntu:16.04
## base built arguments
ARG NIX=nix-2.2.1-x86_64-linux
ARG NIX_PKG=nix-2.2.1-x86_64-linux.tar.bz2
ARG NIX_SRC_URL=https://nixos.org/releases/nix/nix-2.2.1/nix-2.2.1-x86_64-linux.tar.bz2
ARG USER=unholy-user
# configure the base build user
ENV HOME /home/$USER
RUN useradd --comment "Unholy build user" \
            --home-dir $HOME \
            --create-home $USER \
            --shell /bin/bash
##########################
# nix installation
##########################
# disable the sandbox in the nix, otherwise it will fail
# on the clone syscall required for the nix sandbox to work
RUN mkdir -p /nix /etc/nix &&  echo 'sandbox = false' > /etc/nix/nix.conf
# we are going to make  a single user nix installation
RUN chown $USER /nix
# install curl for nix and to get the tarball
# bzip2 to extract the data
RUN apt-get update && apt-get install -y curl bzip2
USER $USER
WORKDIR $HOME
# make sure we have a profile
RUN touch .bash_profile
RUN curl  $NIX_SRC_URL -o $NIX_PKG
RUN tar xjf ./$NIX_PKG
WORKDIR $HOME/$NIX
RUN /bin/sh ./install --no-daemon
WORKDIR $HOME
RUN rm -rf ./$NIX*
#############################
# end of the nix installation
#############################
USER root
# we use a direct string replacement (the @ placeholder)
# because otherwise docker has issues caching the layer even if we define
# the same dependencies on a file and then use it to install those
RUN apt-get update && \
    apt-get install -y @targetSystemBuildDependencies@
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh
USER $USER
COPY unholy-expression $HOME/unholy-expression
COPY build.sh $HOME/
COPY unholy $HOME/unholy
# set the USER environment variable, otherwise the
# nix profile is not sourced
ENV USER $USER
# envvars relevant for built.sh and entrypoint.sh
ENV OUTPUT_DIR $HOME/output
ENV RESULT_LINK $OUTPUT_DIR/result
ENV UNHOLY_SRC $HOME/unholy
ENV UNHOLY_EXPRESSION $HOME/unholy-expression
# this value has to be defined to be able to use this Dockerfile,
# the effect is rather undesirable... we can't catch the nix build
# as a docker layer, still, having the main storage path available
# at build time inside the container allow is to pre-configure paths
# expected to be in the outside [like virtualenv ;)]
ARG STORE_PATH
ENV STORE_PATH $STORE_PATH
###
RUN /bin/bash ./build.sh
CMD [ "" ]
ENTRYPOINT [ "/entrypoint.sh" ]
