##!/usr/local/bin/ruby

require 'i18n'
require 'open-uri'
require 'yaml'
require 'json'

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

# https://github.com/arnau/ISO8601/blob/master/lib/iso8601/duration.rb#L233-L235
ISO8601_PERIOD_REGEX = /PT(?:(?<hours>\d+)H)?(?:(?<minutes>\d+)M)?(?:(?<seconds>\d+)S)?/

def extract_seconds(string)
  time = string.match(ISO8601_PERIOD_REGEX).named_captures
  time['minutes'].to_i * 60 + time['seconds'].to_i
  time['hours'].to_i * 60 * 60 + time['minutes'].to_i * 60 + time['seconds'].to_i
end

def update_duration(input_path)
  video_entities = YAML.load(File.read(input_path))
  video_ids = video_entities
    .select { |e| e['video_platform'] != 'vimeo' }
    .map { |e| e['video_id'] }

  uri = URI::HTTPS.build(
    host: 'www.googleapis.com',
    path: '/youtube/v3/videos/',
    query: URI.encode_www_form({
      id: video_ids.join(","),
      part: "snippet,contentDetails,statistics",
      maxResults: 50,
      key: ENV['YOUTUBE_API_KEY']
    })
  )

  new_entities =
    JSON.parse(uri.read)['items'].map do |item|
      entity = video_entities.find { |e| e['video_id'] == item['id'] }
      entity['video_view_count'] = item['statistics']['viewCount'].to_i
      entity['video_duration_seconds'] = extract_seconds(item['contentDetails']['duration'])

      entity
    end

  IO.write(input_path, new_entities.to_yaml)
end
