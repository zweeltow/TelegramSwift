#/bin/sh
set -x
set -e

export PATH="$PATH:$PWD/../deploy"
export PATH="$PATH:$HOME/.fastlane/bin"

tag="$1"
sh ./buildbox/cleanup-telegram-build-vms.sh
sh ./buildbox/build.sh $tag
sh deploy-$tag.sh ~/build-$tag $PWD Telegram.app ~/.credentials/dsa-$tag
rm -rf ~/build-$tag
