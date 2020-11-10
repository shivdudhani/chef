#
# Cookbook:: end_to_end
# Recipe:: tests
#
# Copyright:: Copyright (c) Chef Software Inc.
#

# nuke homebrew to force a new install
file "/usr/local/bin/brew" do
  action :delete
end

directory "/usr/local/Homebrew" do
  action :delete
  recursive true
end

# create the user we'll install homebrew as
user "homebrew_user"

homebrew_install "install homebrew" do
  user "homebrew_user"
end

homebrew_update

homebrew_package "vim"

homebrew_package "vim" do
  action :purge
end