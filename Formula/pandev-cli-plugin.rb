class PandevCliPlugin < Formula
  desc "Pandev CLI Plugin (Beta)"
  homepage "https://github.com/pandev-metriks/homebrew-pandev-cli-beta"
  version "2.4.1"

  depends_on "jq"
  depends_on "git"

  on_macos do
    if Hardware::CPU.intel?
      url "https://github.com/pandev-metriks/homebrew-pandev-cli-beta/releases/download/v#{version}/pandev-cli-plugin_#{version}_macOS_amd64.tar.gz"
      sha256 "1440f4470a4fe529185ea0f632ae1115bf41029bcbf2c2509a7d0c4ebd613c40"
    else
      url "https://github.com/pandev-metriks/homebrew-pandev-cli-beta/releases/download/v#{version}/pandev-cli-plugin_#{version}_macOS_arm64.tar.gz"
      sha256 "1d190f14443abb833a68df2e61f1bc3f98fac3a3ab6ef8970d9eb6a9a6c50da7"
    end
  end

  on_linux do
    url "https://github.com/pandev-metriks/homebrew-pandev-cli-beta/releases/download/v#{version}/pandev-cli-plugin_#{version}_Linux_amd64.tar.gz"
    sha256 "54373d7bbaf622c24d41e05591c9592f673d2dd9da2e7c5c3469b8294d7101d1"
  end

  def install
    libexec.install Dir["*"]
    bin.install_symlink libexec/"bin/pandev"
    bin.install_symlink libexec/"bin/pandev-cli-plugin"
  end

  def post_install
    touch libexec/"UPDATE_AVAILABLE"
  end
end