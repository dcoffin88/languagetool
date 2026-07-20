# Dockerfile for LanguageTool 
This repository contains a Dockerfile to create a Docker image for [LanguageTool](https://github.com/languagetool-org/languagetool). 
 
> [LanguageTool](https://www.languagetool.org/) is an Open Source proofreading software for English, French, German, Polish, Russian, and [more than 20 other languages](https://languagetool.org/languages/). It finds many errors that a simple spell checker cannot detect.

* [LanguageTool Forum](https://forum.languagetool.org)

For more information, please see our homepage, at [`languagetool.org`](https://languagetool.org),
[this `README`](https://github.com/languagetool-org/languagetool/blob/master/languagetool-standalone/README.md),
and [`CHANGES`](https://github.com/languagetool-org/languagetool/blob/master/languagetool-standalone/CHANGES.md).

# Setup 
 
## Folder Structure
 
```sh 
/docker/languagetool/ngrams
/docker/languagetool/compose.yml
``` 

## Setup using the Docker Compose 
Create `compose.yml` next to the `ngrams` directory:
 
```yaml
services:
  languagetool:
    image: ghcr.io/dcoffin88/languagetool:latest
    container_name: languagetool
    user: 1026:100
    restart: unless-stopped
    ports:
      - "8010:8010"
    volumes:
      - ./ngrams:/ngrams
    environment:
      download_ngrams_langs: en,fr
      langtool_languageModel: /ngrams
      langtool_maxTextLength: 20000
      langtool_pipelinePrewarming: true
      Java_Xms: 512m
      Java_Xmx: 1g
    network_mode: bridge
    security_opt:
      - no-new-privileges:true
```

Start the container:

```sh
docker compose up -d
```

On first startup, the container downloads the requested n-gram datasets into `./ngrams`. The directory must be writable by the container user. To disable automatic n-gram downloads, remove `download_ngrams_langs`.

## UID and GID

If you bind mount `./ngrams`, run the container with a user ID and group ID that can write to that host directory. On Linux, run this in a terminal to get your current UID and GID:

```sh
id
```

Use the `uid` and `gid` values in Compose:

```yaml
services:
  languagetool:
    user: 1026:100
```

For example, if `id` shows `uid=1000` and `gid=1000`, use:

```yaml
user: 1000:1000
```
 
## Java heap size 
LanguageTool will be start with a default minimum heap size (`-Xms`) of `512m` and a maximum (`-Xmx`) of `1g`. You can overwrite these defaults by setting the environment variables `Java_Xms` and `Java_Xmx`.
 
```
environment:
  Java_Xms: 1g
  Java_Xmx: 2g
```
 
## FastText support 
FastText is installed in the image. During the image build, the `lid.176.bin` language detection model is downloaded to `/fastText/lid.176.bin`, and `config.properties` is updated with:

```properties
fasttextModel=/fastText/lid.176.bin
fasttextBinary=/usr/bin/fasttext
```

These values are managed by the image. Do not set `langtool_fasttextModel` or `langtool_fasttextBinary`; the container will exit if either variable is provided.

## Using n-gram datasets

LanguageTool can use n-gram datasets to improve detection of words that are commonly confused, such as `their` and `there`.

Set `download_ngrams_langs` to a comma-separated list of languages and mount `/ngrams` to persist the downloaded data:

```yml
services:
  languagetool:
    image: ghcr.io/dcoffin88/languagetool:latest
    volumes:
      - ./ngrams:/ngrams
    environment:
      download_ngrams_langs: en,fr
      langtool_languageModel: /ngrams
```

On startup, the container downloads any missing datasets into `/ngrams`, extracts them, removes the zip files, and skips languages that already exist. Supported values are `de`, `en`, `es`, `fr`, and `nl`.

The `/ngrams` mount must be writable by the container user during the first startup. After the datasets are downloaded, the same directory can be reused on later container starts.

## Maximum text length

`langtool_maxTextLength` controls the largest text payload LanguageTool will accept for a single check request. The value is passed to LanguageTool as `maxTextLength`.

```yaml
environment:
  langtool_maxTextLength: 20000
```

Increase this value if clients need to check longer documents. Larger values can increase CPU and memory use, so raise `Java_Xmx` if you allow significantly larger requests.

## Pipeline prewarming

`langtool_pipelinePrewarming` enables LanguageTool's `pipelinePrewarming` setting. When enabled, LanguageTool warms language-processing pipelines at startup so the first requests are less likely to pay the full initialization cost.

```yaml
environment:
  langtool_pipelinePrewarming: true
```

Prewarming can make startup slower and may use more memory during initialization, but it usually improves first-request latency after the container is ready.

Java heap settings are controlled separately:

```yaml
environment:
  Java_Xms: 512m
  Java_Xmx: 1g
```

## Usage

The container listens on port `8010`.

```sh
curl --data "language=en-US&text=a simple test" http://localhost:8010/v2/check
```

Docker run example:

```sh
docker run --rm -p 8010:8010 ghcr.io/dcoffin88/languagetool:latest
```
