FROM mcr.microsoft.com/powershell:lts-ubuntu-18.04
RUN apt-get update

# install common tooling
RUN apt-get install git -y;
RUN apt-get install curl -y;
RUN apt-get install iproute2 -y;

# install docker cli client
RUN pwsh -C 'invoke-webrequest "https://download.docker.com/linux/static/stable/x86_64/docker-18.03.1-ce.tgz" -outfile "docker-18.03.1-ce.tgz"'
RUN tar xzvf "docker-18.03.1-ce.tgz" --strip 1 -C /usr/local/bin docker/docker;
RUN rm "docker-18.03.1-ce.tgz";

# install kubectl
RUN pwsh -c 'invoke-webrequest "https://dl.k8s.io/release/v1.23.3/bin/linux/amd64/kubectl" -outfile kubectl'
RUN install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
RUN rm kubectl

# install kind
RUN curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.10.0/kind-linux-amd64
RUN chmod +x ./kind
RUN mv ./kind /usr/local/bin/kind

# install powershell modules as necessary
RUN pwsh -c 'install-module powershell-yaml -force'

# install NPM
RUN curl -sL https://deb.nodesource.com/setup_17.x -o nodesource_setup.sh
RUN bash nodesource_setup.sh
RUN apt install nodejs -y