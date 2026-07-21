class PandevCliPlugin < Formula
  desc "Pandev CLI Plugin (Beta)"
  homepage "https://github.com/pandev-metriks/homebrew-pandev-cli-beta"
  version "2.2.1"

  depends_on "jq"
  depends_on "git"

  on_macos do
    if Hardware::CPU.intel?
      url "https://github.com/pandev-metriks/homebrew-pandev-cli-beta/releases/download/v#{version}/pandev-cli-plugin_#{version}_macOS_amd64.tar.gz"
      sha256 "0b04418740c63a4c24b8572e92fd0e179897820b3c1256bd94badc483e63c42d"
    else
      url "https://github.com/pandev-metriks/homebrew-pandev-cli-beta/releases/download/v#{version}/pandev-cli-plugin_#{version}_macOS_arm64.tar.gz"
      sha256 "e82641fef98dc0c345d4006f8d5bb6e06da0de71281cb958ee10681f6237eed9"
    end
  end

  on_linux do
    url "https://github.com/pandev-metriks/homebrew-pandev-cli-beta/releases/download/v#{version}/pandev-cli-plugin_#{version}_Linux_amd64.tar.gz"
    sha256 "b457b1143cf3ab6127b6a299fde6e0d8050e6f223dad29d98b2f855b2eac57e4"
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