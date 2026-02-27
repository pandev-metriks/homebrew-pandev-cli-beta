class PandevCliPlugin < Formula
  desc "Pandev CLI Plugin (Beta)"
  homepage "https://github.com/pandev-metriks/homebrew-pandev-cli-beta"
  version "2.0.2-beta.6"

  depends_on "jq"
  depends_on "git"

  on_macos do
    if Hardware::CPU.intel?
      url "https://github.com/pandev-metriks/homebrew-pandev-cli-beta/releases/download/v#{version}/pandev-cli-plugin_#{version}_macOS_amd64.tar.gz"
      sha256 "bba232ad11fe1e787e3f96eb9d766639e4579f10ed2ebc99a7972a77b0c04e01"
    else
      url "https://github.com/pandev-metriks/homebrew-pandev-cli-beta/releases/download/v#{version}/pandev-cli-plugin_#{version}_macOS_arm64.tar.gz"
      sha256 "c1c6eec4d742b61db6ab007852ee6a4dbaea171aedac8dad7af60a5375f1096b"
    end
  end

  on_linux do
    url "https://github.com/pandev-metriks/homebrew-pandev-cli-beta/releases/download/v#{version}/pandev-cli-plugin_#{version}_Linux_amd64.tar.gz"
    sha256 "d28a07b7e0b7b69760f6a853d0bf7004dd2fbfe9b6130d0305b92792e9352379"
  end

  def install
    libexec.install Dir["*"]

    bin.install libexec/"bin/pandev"
    bin.install libexec/"bin/pandev-cli-plugin"
  end

  def post_install
    touch libexec/"UPDATE_AVAILABLE"
  end
end