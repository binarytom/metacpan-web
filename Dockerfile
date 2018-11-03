FROM perl:5.26.2-slim

ENV PERL_MM_USE_DEFAULT=1 PERL_CARTON_PATH=/carton

RUN apt-get update \
 && apt-get install -y libgmp-dev rsync libssl-dev ca-certificates gcc zlib1g-dev \
 && cpanm -n Mozilla::CA IO::Socket::SSL App::cpm \
 && cpm install -g Carton \
 && rm -fr /root/.cpanm /root/.perl-cpm /var/cache/apt/lists/* /tmp/*

COPY cpanfile cpanfile.snapshot /metacpan-web/
WORKDIR /metacpan-web

RUN useradd -m metacpan-web -g users \
 && mkdir /carton \
 && apt-get update \
 && apt-get install -y libxml2-dev libexpat1-dev \
 && cpm install -L /carton \
 && rm -fr /root/.cpanm /root/.perl-cpm /tmp/*

RUN chown -R metacpan-web:users /metacpan-web /carton

VOLUME /carton

USER metacpan-web:users

EXPOSE 5001

CMD ["carton", "exec", "plackup", "-p", "5001", "-r"]
