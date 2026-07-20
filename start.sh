#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${CONFIG_FILE:-/LanguageTool/config.properties}"
JAVA_XMS="${Java_Xms:-512m}"
JAVA_XMX="${Java_Xmx:-1g}"
PORT="${PORT:-8010}"
NGRAM_LANGS="${download_ngrams_langs:-none}"

if [[ -n "${langtool_fasttextModel:-}" || -n "${langtool_fasttextBinary:-}" ]]; then
  echo "fasttextModel and fasttextBinary are managed by the image; remove langtool_fasttextModel/langtool_fasttextBinary." >&2
  exit 1
fi

tmp_config="$(mktemp)"
cp "${CONFIG_FILE}" "${tmp_config}"

set_config_value() {
  local key="$1"
  local value="$2"
  local next_config

  next_config="$(mktemp)"
  awk -F= -v key="${key}" -v value="${value}" '
    BEGIN { updated = 0 }
    $1 == key {
      print key "=" value
      updated = 1
      next
    }
    { print }
    END {
      if (updated == 0) {
        print key "=" value
      }
    }
  ' "${tmp_config}" > "${next_config}"
  mv "${next_config}" "${tmp_config}"
}

ngram_url() {
  case "$1" in
    de) echo "https://languagetool.org/download/ngram-data/ngrams-de-20150819.zip" ;;
    en) echo "https://languagetool.org/download/ngram-data/ngrams-en-20150817.zip" ;;
    es) echo "https://languagetool.org/download/ngram-data/ngrams-es-20150915.zip" ;;
    fr) echo "https://languagetool.org/download/ngram-data/ngrams-fr-20150913.zip" ;;
    nl) echo "https://languagetool.org/download/ngram-data/ngrams-nl-20181229.zip" ;;
    *)
      echo "Unsupported n-gram language '$1'. Supported languages: de, en, es, fr, nl." >&2
      return 1
      ;;
  esac
}

download_ngram_model() {
  local lang="$1"
  local model_dir="$2"
  local url zip_path

  if [[ -d "${model_dir}/${lang}" ]]; then
    echo "Skipping ${lang} n-grams: ${model_dir}/${lang} already exists."
    return 0
  fi

  url="$(ngram_url "${lang}")"
  zip_path="${model_dir}/ngrams-${lang}.zip"

  echo "Downloading ${lang} n-grams from ${url}."
  curl -fL \
    --retry 10 \
    --retry-delay 30 \
    --connect-timeout 30 \
    --output "${zip_path}" \
    "${url}"

  echo "Extracting ${lang} n-grams to ${model_dir}."
  unzip -q "${zip_path}" -d "${model_dir}"
  rm -f "${zip_path}"
}

while IFS='=' read -r name value; do
  [[ "${name}" == langtool_* ]] || continue
  set_config_value "${name#langtool_}" "${value}"
done < <(env)

if [[ -n "${NGRAM_LANGS}" && "${NGRAM_LANGS}" != "none" ]]; then
  NGRAM_DIR="${langtool_languageModel:-/ngrams}"
  mkdir -p "${NGRAM_DIR}"

  IFS=',' read -ra langs <<< "${NGRAM_LANGS}"
  for lang in "${langs[@]}"; do
    lang="$(echo "${lang}" | tr '[:upper:]' '[:lower:]' | xargs)"
    [[ -n "${lang}" && "${lang}" != "none" ]] || continue
    download_ngram_model "${lang}" "${NGRAM_DIR}"
  done

  set_config_value "languageModel" "${NGRAM_DIR}"
fi

exec java \
  "-Xms${JAVA_XMS}" \
  "-Xmx${JAVA_XMX}" \
  -cp "/LanguageTool/languagetool-server.jar:/LanguageTool/libs/*" \
  org.languagetool.server.HTTPServer \
  --port "${PORT}" \
  --public \
  --config "${tmp_config}"
