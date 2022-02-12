FROM mcr.microsoft.com/powershell:latest
RUN apt-get update
RUN apt-get install git -y;
RUN apt-get install curl -y;

RUN pwsh -C 'invoke-webrequest "https://download.docker.com/linux/static/stable/x86_64/docker-18.03.1-ce.tgz" -outfile "docker-18.03.1-ce.tgz"'
RUN tar xzvf "docker-18.03.1-ce.tgz" --strip 1 -C /usr/local/bin docker/docker;
RUN rm "docker-18.03.1-ce.tgz";