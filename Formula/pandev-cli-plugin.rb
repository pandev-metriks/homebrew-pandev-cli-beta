class PandevCliPlugin < Formula
  desc "Pandev CLI Plugin (Beta)"
  homepage "https://github.com/pandev-metriks/homebrew-pandev-cli-beta"
  version "2.1.4"

  depends_on "jq"
  depends_on "git"

  on_macos do
    if Hardware::CPU.intel?
      url "https://github.com/pandev-metriks/homebrew-pandev-cli-beta/releases/download/v#{version}/pandev-cli-plugin_#{version}_macOS_amd64.tar.gz"
      sha256 "ccd7a69bf0abaefef42587c8ea7079f88375dd1ab7181671fdfce3e83de76bc1"
    else
      url "https://github.com/pandev-metriks/homebrew-pandev-cli-beta/releases/download/v#{version}/pandev-cli-plugin_#{version}_macOS_arm64.tar.gz"
      sha256 "1aed02259d79e5a73ccaad6c7f3bc9f2300057ac816616665e06198949995fe2"
    end
  end

  on_linux do
    url "https://github.com/pandev-metriks/homebrew-pandev-cli-beta/releases/download/v#{version}/pandev-cli-plugin_#{version}_Linux_amd64.tar.gz"
    sha256 "22f6a5e99adab270c6cf4b02736aca499ca2b2d6ae854c92422b030d9162f7b6"
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