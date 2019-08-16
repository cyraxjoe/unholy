FROM ubuntu:16.04
## base build arguments
ARG USER=unholy-user
# configure the base build user
ENV HOME /home/$USER
RUN useradd --comment "Unholy build user" \
            --home-dir $HOME \
            --create-home $USER \
            --shell /bin/bash

# install lsb-release so that the virtualenvs can obtain the system
# information and ca-certificate in case we try to fetch something
# from the network and is using https (like pip)
RUN apt-get update && apt-get install -y lsb-release ca-certificates

# added for debugging
#RUN apt-get update && apt-get install -y tree
#RUN apt-get update && apt-get install -y iputils-ping

# add python PPA before different versions
RUN apt-get update && apt-get install -y software-properties-common
RUN add-apt-repository ppa:deadsnakes/ppa
RUN apt-get update

# we use a direct string replacement (the @ placeholder)
# because otherwise docker has issues caching the layer even if we define
# the same dependencies on a file and then use it to install those
RUN apt-get update && \
    apt-get install -y @targetSystemBuildDependencies@
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh


COPY unholy-script.sh /unholy-script.sh
RUN chmod +x /unholy-script.sh

#COPY source/ $HOME/source
#RUN chown -R unholy-user:unholy-user $HOME/source/*


USER $USER
WORKDIR $HOME/
RUN mkdir @ARGS_DIR@
# CUSTOM_ARGS
@CUSTOM_ARGS@
#
#COPY requires/ $HOME/requires
# make this into unholy-script?
COPY build.sh $HOME/
ENV USER $USER
# envvars relevant for built.sh and entrypoint.sh
ENV OUTPUT_DIR $HOME/output
ENV RESULT_LINK $OUTPUT_DIR/result
ENV PYTHON_BIN "@systemPython@"
ENV OUTPUTS "@outputs@"
###
RUN /bin/bash $HOME/build.sh
CMD [ "" ]
ENTRYPOINT [ "/entrypoint.sh" ]
