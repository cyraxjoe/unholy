FROM ubuntu:16.04
## base build arguments
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
USER $USER
WORKDIR $HOME
# make sure we have a profile
RUN touch .bash_profile
COPY nix-binary-installer ./nix-binary-installer
WORKDIR $HOME/nix-binary-installer
RUN /bin/sh ./install --no-daemon
WORKDIR $HOME
#############################
# end of the nix installation
#############################
USER root
# remove the nix installer folder as root
RUN rm -rf $HOME/nix-binary-installer

# install lsb-release so that the virtualenvs can obtain the system
# information and ca-certificate in case we try to fetch something
# from the network and is using https (like pip)
RUN apt-get update && apt-get install -y lsb-release ca-certificates
# we use a direct string replacement (the @ placeholder)
# because otherwise docker has issues caching the layer even if we define
# the same dependencies on a file and then use it to install those
RUN apt-get update && \
    apt-get install -y @targetSystemBuildDependencies@
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh
USER $USER
RUN mkdir @ARGS_DIR@
# CUSTOM_ARGS
@CUSTOM_ARGS@
#
# TODO: make this conditional?
COPY source/ $HOME/source
COPY unholy-expression $HOME/unholy-expression
COPY build.sh $HOME/
# set the USER environment variable, otherwise the
# nix profile is not sourced
ENV USER $USER
# envvars relevant for built.sh and entrypoint.sh
ENV STORE_PATH @out@
ENV OUTPUT_DIR $HOME/output
ENV RESULT_LINK $OUTPUT_DIR/result
ENV UNHOLY_EXPRESSION $HOME/unholy-expression
ENV OUTPUTS "@outputs@"
###
RUN /bin/bash ./build.sh
CMD [ "" ]
ENTRYPOINT [ "/entrypoint.sh" ]
