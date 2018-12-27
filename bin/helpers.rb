##!/usr/local/bin/ruby

require 'i18n'
require 'open-uri'
require 'yaml'
require 'json'
require 'pry'

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
  entries = YAML.load(File.read(input_path))
  updated_entries = []

  video_ids = entries
    .select { |e| e['video_platform'] != 'vimeo' }
    .map { |e| e['video_id'] }
    .each_slice(50)

  video_ids.each_with_index do |slice, index|
    uri = URI::HTTPS.build(
      host: 'www.googleapis.com',
      path: '/youtube/v3/videos/',
      query: URI.encode_www_form({
        id: slice.join(","),
        part: "snippet,contentDetails,statistics",
        maxResults: 50,
        key: ENV['YOUTUBE_API_KEY']
      })
    )

    updated_entries +=
      JSON.parse(uri.read)['items'].map do |item|
        entity = entries.find { |e| e['video_id'] == item['id'] }
        entity['video_view_count'] = item['statistics']['viewCount'].to_i
        entity['video_duration_seconds'] = extract_seconds(item['contentDetails']['duration'])

        entity
      end

    puts "#{input_path} - #{index + 1}"
  end

  IO.write(input_path, updated_entries.to_yaml(options: {line_width: -1}))
end

def get_channel_videos(uploads_playlist_id)
  results = []
  next_page_token = {}
  i = 1

  while true do
    puts i += 1

    uri = URI::HTTPS.build(
      host: 'www.googleapis.com',
      path: '/youtube/v3/playlistItems',
      query: URI.encode_www_form({
        playlistId: uploads_playlist_id,
        part: "snippet,contentDetails",
        maxResults: 50,
        key: ENV['YOUTUBE_API_KEY']
      }.merge(next_page_token))
    )

    result = JSON.parse(uri.read)
    results += result['items']

    if result['items'].size < 50
      break
    else
      next_page_token = {pageToken: result['nextPageToken']}
    end
  end

  IO.write("#{uploads_playlist_id}.json", JSON.pretty_generate(results))
end

def talk_traits(raw_talk)
  entry = {}

  if raw_talk['talk_title'].downcase.include?('keynote')
    entry = entry.merge('keynote' => true)
  end

  if raw_talk['talk_title'].downcase.include?('lightning')
    entry = entry.merge('lightning' => true)
  end

  entry
end

@speakers = YAML.load(File.read('_data/speakers.yaml'))
@conferences = YAML.load(File.read("_data/conferences.yaml"))
@new_speakers = []

def speaker_ids(string)
  raw_speaker = cleanup(string)
  found_speaker = @speakers.find { |x| x['full_name'] == raw_speaker } # TODO: this can use Jaro distance or smth

  if found_speaker
    found_speaker['id']
  else
    new_speaker = {
      'id' => make_id(raw_speaker),
      'full_name' => raw_speaker,
      'twitter' => nil,
      'github' => nil,
      'elixirforum' => nil
    }

    @new_speakers << new_speaker

    new_speaker['id']
  end
end

def all_videos
  (Dir["_data/*.yaml"] - ["_data/conferences.yaml", "_data/speakers.yaml"]).reduce([]) { |all, path| all += YAML.load(File.read(path)).map { |x| x['video_id'] } } .flatten
end
