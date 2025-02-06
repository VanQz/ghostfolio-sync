#Deriving the latest base image
FROM python:3.9.16-alpine3.17

RUN apk add git

WORKDIR /usr/app/src
COPY requirements.txt .
RUN pip3 install -r requirements.txt
RUN apk add dumb-init
COPY ./entrypoint.sh /root/entrypoint.sh
COPY ./run.sh /root/run.sh
RUN chmod 777 /root/entrypoint.sh /root/run.sh
COPY main.py .
COPY SyncIBKR.py .
COPY pretty_print.py .
COPY mapping.yaml .
ENTRYPOINT ["dumb-init", "--"]
CMD /root/entrypoint.sh | while IFS= read -r line; do printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"; done;
