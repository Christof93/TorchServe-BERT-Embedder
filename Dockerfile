## Docker image to produce a torchServe instance which returns BERT sentence embeddings
# adapted from https://luiscarlosduarte95.medium.com/creating-your-own-bert-embedding-service-with-torchserve-4b57b591987b

ARG BASE_IMAGE=python:3.8

FROM ${BASE_IMAGE} AS compile-image
ENV PYTHONUNBUFFERED TRUE

RUN apt-get update && apt-get install -y build-essential openjdk-11-jre-headless \
    && mount=type=cache,id=apt-dev,target=/var/cache/apt \
    && rm -rf /var/lib/apt/lists/* \
    && cd /tmp \
    && curl -O https://bootstrap.pypa.io/get-pip.py \
    && python3 get-pip.py

RUN python3 -m venv /home/venv && . /home/venv/bin/activate

RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1 \
    && update-alternatives --install /usr/local/bin/pip pip /usr/local/bin/pip3 1

RUN pip3 install torch torchvision --extra-index-url https://download.pytorch.org/whl/cpu

RUN pip3 install --no-cache-dir torchtext torchserve torch-model-archiver transformers

ENV PATH="/home/venv/bin:$PATH"
# Download BERT model 
RUN cd /home && wget https://s3.amazonaws.com/models.huggingface.co/bert/bert-base-uncased-config.json\
 && wget https://s3.amazonaws.com/models.huggingface.co/bert/bert-base-uncased-pytorch_model.bin\
 && wget https://s3.amazonaws.com/models.huggingface.co/bert/bert-base-uncased-vocab.txt

RUN mkdir -p /home/bert && \
  mv /home/bert-base-uncased-config.json /home/bert/config.json && \
  mv /home/bert-base-uncased-pytorch_model.bin /home/bert/pytorch_model.bin && \
  mv /home/bert-base-uncased-vocab.txt /home/bert/vocab.txt

RUN useradd -m model-server && mkdir -p /home/model-server/tmp

COPY dockerd-entrypoint.sh /usr/local/bin/dockerd-entrypoint.sh

RUN chmod +x /usr/local/bin/dockerd-entrypoint.sh && \
  chown -R model-server /home/model-server && \ 
  chown -R model-server /home/venv

COPY config.properties /home/model-server/config.properties
COPY BertHandler.py /home/model-server/BertHandler.py

# Archive BERT model
RUN torch-model-archiver --model-name "bert" \
    --serialized-file "/home/bert/pytorch_model.bin"\
    --extra-files "/home/bert"\ 
    --version "A-12"\ 
    --handler "/home/model-server/BertHandler.py"

RUN mkdir /home/model-server/model-store && chown -R model-server /home/model-server/model-store && \
  mv ./bert.mar /home/model-server/model-store/bert.mar

RUN rm -rf /home/bert

EXPOSE 8443 8444 8445

USER model-server
WORKDIR /home/model-server
ENV TEMP=/home/model-server/tmp

ENTRYPOINT ["/usr/local/bin/dockerd-entrypoint.sh"]
#torchserve --start --ncs --model-store model-store --models bert=bert.mar

CMD ["serve"]
