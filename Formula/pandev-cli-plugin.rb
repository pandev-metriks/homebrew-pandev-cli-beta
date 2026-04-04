class PandevCliPlugin < Formula
  desc "Pandev CLI Plugin (Beta)"
  homepage "https://github.com/pandev-metriks/homebrew-pandev-cli-beta"
  version "2.0.4.10"

  depends_on "jq"
  depends_on "git"

  on_macos do
    if Hardware::CPU.intel?
      url "https://github.com/pandev-metriks/homebrew-pandev-cli-beta/releases/download/v#{version}/pandev-cli-plugin_#{version}_macOS_amd64.tar.gz"
      sha256 "4100b8cabd1bfa5c1d49fea6fa30da893a2145c1660f3f772eecbaa23bc52d7f"
    else
      url "https://github.com/pandev-metriks/homebrew-pandev-cli-beta/releases/download/v#{version}/pandev-cli-plugin_#{version}_macOS_arm64.tar.gz"
      sha256 "9805368ecf49ebc057c5b88b02b6efd7f3a2c1f7f492c8951882fd4ad1efb7a6"
    end
  end

  on_linux do
    url "https://github.com/pandev-metriks/homebrew-pandev-cli-beta/releases/download/v#{version}/pandev-cli-plugin_#{version}_Linux_amd64.tar.gz"
    sha256 "4100b8cabd1bfa5c1d49fea6fa30da893a2145c1660f3f772eecbaa23bc52d7f"
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