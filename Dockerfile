FROM alpine:3.20

RUN apk add --no-cache v4l-utils curl tzdata jq

COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]
