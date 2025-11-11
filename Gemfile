source "https://rubygems.org"

# Fastlane for automating iOS and Android deployment
gem "fastlane", "~> 2.228"

# Plugins for Fastlane (add as needed)
plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
