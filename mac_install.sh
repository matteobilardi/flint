git checkout mac_temp
brew update
brew upgrade
brew tap ethereum/ethereum
brew install wget solidity nodejs
brew cask install mono-mdk
brew install kylef/formulae/swiftenv
echo 'if which swiftenv > /dev/null; then eval "$(swiftenv init -)"; fi' >> ~/.bash_profile
swiftenv install 5.0.2
swiftenv install 4.2
swiftenv install 5.0
brew install swiftlint
npm install
npm install -g truffle@4
ln -sf /usr/local/Cellar/z3/4.8.5/bin ./z3/build
echo "export FLINTPATH=$(pwd)" >> ~/.bash_profile
source ~/.bash_profile
make -f MacMakefile
