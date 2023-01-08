FROM --platform=linux/amd64 ubuntu

WORKDIR /home/clamav

RUN echo "Prepping ClamAV"

RUN apt update -y
RUN apt install curl sudo procps unzip -y

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip
RUN sudo ./aws/install

RUN curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash -
RUN apt install -y nodejs

RUN apt install -y clamav clamav-daemon

RUN mkdir /var/run/clamav && \
  chown clamav:clamav /var/run/clamav && \
  chmod 750 /var/run/clamav

RUN freshclam

COPY ./src/clamd.conf /etc/clamav/clamd.conf
COPY ./src/consumer.js ./consumer.js
COPY ./src/package.json ./package.json
COPY ./src/package-lock.json ./package-lock.json
RUN npm install
ADD ./src/run.sh ./run.sh

CMD ["bash", "./run.sh"]
