#!/usr/bin/env ruby

require 'json'
require 'net/http'

api_key = ENV['NOTION_API_KEY']
database_id = ENV['NOTION_BOOKMARKS_DATABASE_ID']

if api_key.nil? || api_key.empty?
  puts JSON.generate({
    'items' => [{
      'title' => 'No API token configured',
      'valid' => false
    }]
  })

  return
end

uri = URI("https://api.notion.com/v1/databases/#{database_id}/query")
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
headers = {
  'Notion-Version' => '2022-06-28',
  'Authorization' => "Bearer #{api_key}",
  'Content-Type' => 'application/json'
}

query = ARGV[0].strip.downcase
keywords = query.split(' ')
body = {
  'sorts' => [
    {
      'property' => 'Name',
      'direction' => 'ascending'
    }
  ],
  'filter' => {
    'and' => keywords.map do |keyword|
      {
        'or' => [
          {
            'property' => 'Tags',
            'multi_select' => {
              'contains' => keyword.strip.downcase
            }
          },
          {
            'property' => 'Name',
            'rich_text' => {
              'contains' => keyword.strip.downcase
            }
          },
          {
            'property' => 'Url',
            'rich_text' => {
              'contains' => keyword.strip.downcase
            }
          }
        ]
      }
    end
  },
  'page_size' => 25
}

request = Net::HTTP::Post.new(uri.path, headers)
request.body = body.to_json
response = http.request(request)
results = JSON.parse(response.body)

if !results.key?('results') || results['results'].empty?
  puts JSON.generate({
    'items' => [{
      'title' => 'Not found…',
      'valid' => false
    }]
  })

  return
end

items = []
results['results'].each do |result|
  url = result.dig('properties', 'Url', 'url') || ''
  title = result.dig('properties', 'Name', 'title', 0, 'plain_text') || ''
  tags = result.dig('properties', 'Tags', 'multi_select')&.map { |item| item['name'] } || []
  subtitle = ''
  tags.each do |element|
    if !subtitle.empty?
      subtitle += ', '
    end
    subtitle += element
  end
  subtitle += " — #{url}"

  if !title.empty? && !url.empty?
    items << {
      'title' => title,
      'subtitle' => subtitle,
      'arg' => url,
      'icon' => {
        'type' => 'png',
        'path' => 'icon.png'
      }
    }
  end
end

puts JSON.generate({'items' => items}, :pretty_generate => true)
