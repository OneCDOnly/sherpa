#!/usr/bin/env bash

. $HOME/scripts/nas/sherpa/support/environment.sourced || exit

git add "$docs_path" && git commit -m '[update] readme doc(s)' && git push
