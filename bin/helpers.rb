##!/usr/local/bin/ruby

require 'i18n'

I18n.available_locales = [:en]

def cleanup(string)
  if string
    string.gsub(/\s+/, " ").strip
  else
    nil
  end
end

def make_id(word)
  word = word.dup
  word.gsub!(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2'.freeze)
  word.gsub!(/([a-z\d])([A-Z])/, '\1_\2'.freeze)
  word.tr!("-".freeze, "_".freeze)
  word.tr!(" ".freeze, "_".freeze)
  word.tr!(".".freeze, "".freeze)
  word.downcase!
  I18n.transliterate(word)
end
